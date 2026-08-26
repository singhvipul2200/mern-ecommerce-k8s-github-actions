# ------------------------------------------------------------------------------------
# outputs.tf
# These values are printed after `terraform apply` and are also what the
# terraform_eks folder reads (via terraform_remote_state) to build the
# EKS cluster inside this exact VPC/subnets.
# ------------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the created VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets (pass these to EKS)"
  value       = aws_subnet.public[*].id
}

output "availability_zones" {
  description = "AZs used by the public subnets"
  value       = aws_subnet.public[*].availability_zone
}
