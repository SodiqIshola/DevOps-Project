variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "container_port" {
  description = "The port the Node.js app listens on"
  default     = 3000
}

# --- AWS REGION ---
variable "aws_region" {
  type        = string
  default     = "ca-central-1" 
  description = "The AWS region where all infrastructure will be deployed"
}

variable "cpu_architecture" {
  type        = string
  description = "The CPU architecture for the ECS task. Use 'X86_64' for Intel or 'ARM64' for Apple Silicon/Graviton."
  default     = "X86_64" 
}

variable "node_env" {
  type        = string
  default     = "development"
  description = "The application runtime environment. Allowed values: development or production."
}

# Use a list of strings to override the default container command.
# Set to null to use the command defined in the Docker image.
variable "container_command" {
  description = "The entrypoint command to run inside the container (e.g., ['npm', 'run', 'dev']). Set to null to use the image defaults."
  type        = list(string)
  default     = ["npm", "run", "dev"] 
}


