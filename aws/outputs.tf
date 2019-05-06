output "URL" {
  value = "${aws_elb.ruuvi_elb.dns_name}"
}
output "IP" {
  value = "${aws_instance.ruuvi_instance.public_ip}"
}
