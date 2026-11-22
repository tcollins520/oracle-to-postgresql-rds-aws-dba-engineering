# Outputs exposed by the reusable Networking module.

output "vpc_id" {
  value = aws_vpc.this.id
}
output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}
output "public_subnet_ids" {
  value = { for key, subnet in aws_subnet.public : key => subnet.id }
}
output "private_subnet_ids" {
  value = { for key, subnet in aws_subnet.private : key => subnet.id }
}
output "nat_gateway_ids" {
  value = { for key, nat in aws_nat_gateway.this : key => nat.id }
}
output "nat_gateway_public_ips" {
  value = { for key, eip in aws_eip.nat : key => eip.public_ip }
}
