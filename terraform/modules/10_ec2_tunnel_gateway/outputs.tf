# Outputs exposed by the reusable Ec2 Tunnel Gateway module.

output "instance_id" {
  value = aws_instance.gateway.id
}
output "public_ip" {
  value = aws_eip.gateway.public_ip
}
output "private_ip" {
  value = aws_instance.gateway.private_ip
}
output "ami_id" {
  value = data.aws_ami.al2023.id
}
