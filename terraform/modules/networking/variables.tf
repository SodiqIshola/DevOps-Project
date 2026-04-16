# --- VPC CONFIGURATION ---
variable "vpc_cidr" {
  type        = string
  description = "The IP range for the Virtual Private Cloud"
}


data "aws_availability_zones" "available" {}


variable "public_subnet_tags" {
  type    = map(string)
  default = {}
}

variable "private_subnet_tags" {
  type    = map(any)
  default = {}
}


