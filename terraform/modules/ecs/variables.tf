# Defines the specific version or location of your application code
variable "container_image" {
  # Describes what this variable does for other developers or for documentation
  description = "The Docker image URI from ECR"
  # Restricts the input to text format (e.g., '://123456789.dkr.ecr.us-east-1.amazonaws.com')
  type        = string
}

# Defines the network gateway for your container
variable "app_port" {
  # Explains that this is the port your Node.js server (Express/Fastify) is programmed to use
  description = "The port the application listens on"
  # Restricts the input to whole numbers (e.g., 3000 or 8080)
  type        = number
}

# Determines the physical location of your running containers
variable "private_subnet_ids" {
  # Explains these are 'private' because Fargate tasks usually shouldn't have public IPs
  description = "Subnets where Fargate tasks will run"
  # Expects a list of multiple strings (e.g., ["subnet-123", "subnet-456"]) for high availability
  type        = list(string)
}

# The firewall settings for your containers
variable "ecs_tasks_sg_id" {
  # Explains this controls what traffic (like from the Load Balancer) can reach the task
  description = "Security group for the ECS tasks"
  # Expects a single string representing the Security Group ID
  type        = string
}

# The "Destination" for the Load Balancer
variable "target_group_arn" {
  # Explains where the Load Balancer should send traffic once it reaches the listener
  description = "The ALB Target Group ARN"
  # Expects the Amazon Resource Name (ARN) string for the target group
  type        = string
}

# Regional setting for CloudWatch and API calls
variable "aws_region" {
  # Ensures logs are sent to the correct geographic location (e.g., 'us-east-1')
  description = "AWS region for logging"
  # Restricts the input to text
  type        = string
}

# Dependency management for the Application Load Balancer
variable "alb_listener_arn" {
  # Explains that we use this to ensure the "entry door" (Listener) is ready before the "room" (Service) opens
  description = "The ARN of the ALB Listener to ensure it's ready before the service starts"
  # Expects a single string representing the Listener ARN
  type        = string
}

variable "cpu_architecture" {
  type        = string
  description = "The CPU architecture for the ECS task. Use 'X86_64' for Intel or 'ARM64' for Apple Silicon/Graviton."
}

