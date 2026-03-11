variable "vpc_id" {
  description = "The ID of the VPC where the Target Group will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "The list of public subnets where the ALB will live"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "The Security Group ID for the Load Balancer"
  type        = string
}

variable "app_port" {
  description = "The port the application container is listening on (e.g., 3000)"
  type        = number
  default     = 3000 # Defaulted to 3000 for your Node.js app
}