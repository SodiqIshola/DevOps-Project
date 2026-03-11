# --- VPC CONFIGURATION ---
variable "vpc_cidr" {
  # The CIDR block for the VPC (e.g., 10.0.0.0/16)
  type        = string
  description = "The IP range for the Virtual Private Cloud"
}

# --- APPLICATION PORT ---
variable "container_port" {
  type        = number
  description = "The internal port the Node.js application listens on (e.g., 3000)"
}

data "aws_availability_zones" "available" {}
