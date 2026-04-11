variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "container_port" {
  description = "The port the Node.js app listens on"
  default     = 3000
}

# --- AWS REGION ---
variable "aws_region" {
  # Setting a default for Canada ensures your data stays local unless overridden
  type        = string
  default     = "ca-central-1" # AWS Region code for Canada (Central)
  description = "The AWS region where all infrastructure will be deployed"
}

variable "cpu_architecture" {
  type        = string
  description = "The CPU architecture for the ECS task. Use 'X86_64' for Intel or 'ARM64' for Apple Silicon/Graviton."
  default     = "X86_64" # Defaulting to Intel
}


variable "node_env" {
  type        = string
  default     = "production"
  description = "The application runtime environment. Allowed values: development or production."
}


variable "container_command" {
  description = "Using the default image command."
  type        = list(string)
  default     = null
}


