provider "aws" {
  region     = "${var.region}"
  version    = "~> 2.8"
}

resource "aws_vpc" "ruuvi_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.project_name}"
  }
}

resource "aws_internet_gateway" "ruuvi_gw" {
  vpc_id = "${aws_vpc.ruuvi_vpc.id}"

  tags = {
    Name = "${var.project_name}"
  }
}

resource "aws_route" "ruuvi_internet_access" {
  route_table_id         = "${aws_vpc.ruuvi_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ruuvi_gw.id}"
}

resource "aws_subnet" "ruuvi_subnet" {
  vpc_id            = "${aws_vpc.ruuvi_vpc.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}"
  }
}

resource "aws_security_group" "elb" {
  name        = "ruuvi_elb_secgroup"
  vpc_id      = "${aws_vpc.ruuvi_vpc.id}"

  # HTTP access to Grafana
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access to Influxdb
  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "ruuvi_default_secgroup"
  vpc_id      = "${aws_vpc.ruuvi_vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_acm_certificate" "ruuvi_cert" {
  domain_name       = "*.fredde.dev"
  validation_method = "DNS"

  tags = {
    Name = "${var.project_name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "ruuvi_elb" {
  name = "ruuvi-elb"

  subnets         = ["${aws_subnet.ruuvi_subnet.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.ruuvi_instance.id}"]

  listener {
    instance_port      = 22
    instance_protocol  = "tcp"
    lb_port            = 22
    lb_protocol        = "tcp"
  }

  listener {
    instance_port      = 3000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${aws_acm_certificate.ruuvi_cert.id}"
  }

  listener {
    instance_port     = 8086
    instance_protocol = "http"
    lb_port           = 8086
    lb_protocol       = "https"
    ssl_certificate_id = "${aws_acm_certificate.ruuvi_cert.id}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8086/ping?verbose=true"
    interval            = 30
  }
}

resource "aws_key_pair" "bostrom" {
  key_name   = "bostrom-key-pair-euwest1"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "ruuvi_instance" {
  # Amazon Linux 2 AMI (HVM), SSD Volume Type
  ami           = "ami-09def150731bdbcc2"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.bostrom.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.ruuvi_subnet.id}"

  # credit_specification {
  #   cpu_credits = "unlimited"
  # }

  tags = {
    Name = "${var.project_name}"
  }

  # We run a remote provisioner on the instance after creating it.
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file(var.private_key_path)}"
    }

    source      = "provisioning/install-influxdb.sh"
    destination = "/tmp/install-influxdb.sh"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file(var.private_key_path)}"
    }

    inline = [
      "chmod +x /tmp/install-influxdb.sh",
      "/tmp/install-influxdb.sh ${var.influx_admin_pw} ${var.influx_user_pw} ${var.grafana_admin_pw}",
    ]
  }
}
