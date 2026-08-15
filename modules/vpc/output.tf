output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.nat_gw.id
}

output "public_subnet1_id" {
  description = "Public Subnet 1 ID"
  value       = aws_subnet.pub_subnet1.id
}

output "public_subnet2_id" {
  description = "Public Subnet 2 ID"
  value       = aws_subnet.pub_subnet2.id
}

output "private_subnet1_id" {
  description = "Private Subnet 1 ID"
  value       = aws_subnet.priv_subnet1.id
}

output "private_subnet2_id" {
  description = "Private Subnet 2 ID"
  value       = aws_subnet.priv_subnet2.id
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.pub_rt.id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.priv_rt.id
}

output "key_pair_name" {
  description = "AWS Key Pair Name"
  value       = aws_key_pair.key_pair.key_name
}

output "key_pair_id" {
  description = "AWS Key Pair ID"
  value       = aws_key_pair.key_pair.id
}

output "private_key" {
  description = "Generated private SSH key"
  value       = tls_private_key.key_pair.private_key_pem
  sensitive   = true
}