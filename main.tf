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

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
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
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["10.0.0.0/16"]
  # }

  # outbound internet access
  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}

resource "aws_elb" "web" {
  name = "ruuvi-elb"

  subnets         = ["${aws_subnet.ruuvi_subnet.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.ruuvi_instance.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_key_pair" "bostrom" {
  key_name   = "bostrom-key-pair-euwest1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCYAjAwB++tzKXTcfxoYuyIbG5gTrmJQbQ1pUCcTksgqXHiK9wiI6pkEeT2dkgVe7NRgKIlHk0epgN5hNm76KFWglt5ST1O2BzwG0GQnwQ2R+TSlfxuJNN+AjTTN2L2duuA1ODSB7/5aHen0AIOJbfP5lVfrKA11DuLPDYBLa/i68UDZ4Zu9sgp/mG7EJq8YKFPfB4pWkSSvyJumTNW2Atjd5F/7P0vnU6M8qgCabZqb7VI7c7YhUl5fXj5/dDmznYHiqJ3xYtNW0IclvnStQpTuX6hLzZ4J8Y7xJfQz/FJBuoXzyc1xBUojXWx41w2C8fRTiFpk3WX1999JUWZ9owf"
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
}
