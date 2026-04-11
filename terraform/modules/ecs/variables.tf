# Defines the specific version or location of your application code
variable "container_image" {
  description = "The Docker image URI from ECR"
  type        = string
}

# Defines the network gateway for your container
variable "app_port" {
  description = "The port the application listens on"
  type        = number
}

# Determines the physical location of your running containers
variable "private_subnet_ids" {
  description = "Subnets where Fargate tasks will run"
  type        = list(string)
}

# The firewall settings for your containers
variable "ecs_tasks_sg_id" {
  description = "Security group for the ECS tasks"
  type        = string
}

# The "Destination" for the Load Balancer
variable "target_group_arn" {
  description = "The ALB Target Group ARN"
  type        = string
}

# Regional setting for CloudWatch and API calls
variable "aws_region" {
  description = "AWS region for logging"
  type        = string
}

# Dependency management for the Application Load Balancer
variable "alb_listener_arn" {
  description = "The ARN of the ALB Listener to ensure it's ready before the service starts"
  type        = string
}

variable "cpu_architecture" {
  type        = string
  description = "The CPU architecture for the ECS task. Use 'X86_64' for Intel or 'ARM64' for Apple Silicon/Graviton."
}

variable "node_env" {
  type        = string
  description = "The application runtime environment. Allowed values: development or production."
}

# The command to execute when the container starts. 
# Providing this will override the image's default executable.
variable "container_command" {
  description = "The entrypoint command to run inside the container; overrides the default CMD or ENTRYPOINT."
  type        = list(string)
}


