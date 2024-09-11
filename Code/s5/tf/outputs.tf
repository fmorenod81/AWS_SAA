output "instance_ips" {
  value = aws_eip.web-eip.public_ip
}