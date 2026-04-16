
# The VPC ID is required for the ALB Target Group
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}


# The Public Subnet IDs are where the ALB will 'sit'
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}


# The Private Subnet IDs are where the Node.js Tasks will 'sit'
output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}


