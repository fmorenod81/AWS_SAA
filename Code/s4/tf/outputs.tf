output "web_ip" {
  value = aws_eip.web-eip.public_ip
}
output "private_ip" {
  value = aws_instance.private-1.private_ip
}