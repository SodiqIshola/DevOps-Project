# --- LOAD BALANCER SECURITY GROUP ---

# Security Group for the Load Balancer (Handles public internet requests)
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group" # The name identifier for the SG in the AWS console
  vpc_id      = aws_vpc.main.id      # Attaches this security group to your specific VPC

  # Ingress: Defines rules for incoming traffic
  ingress {
    from_port   = 80            # The starting port for HTTP traffic
    to_port     = 80            # The ending port for HTTP traffic
    protocol    = "tcp"         # The standard networking protocol for web traffic
    cidr_blocks = ["0.0.0.0/0"] # Allows anyone on the internet to access the Load Balancer
  }

  # Egress: Defines rules for outgoing traffic
  egress {
    from_port   = 0             # The starting range for all possible ports
    to_port     = 0             # The ending range for all possible ports
    protocol    = "-1"          # "-1" is a shorthand code representing ALL protocols
    cidr_blocks = ["0.0.0.0/0"] # Allows the ALB to send traffic anywhere (e.g., to your tasks)
  }
}

# --- FARGATE TASKS SECURITY GROUP ---

# Security Group for Fargate Tasks (Protects the private application layer)
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "ecs-tasks-security-group" # The name identifier for the application SG
  vpc_id      = aws_vpc.main.id           # Attaches this security group to your specific VPC

  # Ingress: Defines rules for incoming traffic to your Node.js app
  ingress {
    from_port       = var.container_port             # The port your app listens on (e.g., 3000)
    to_port         = var.container_port             # Must match the from_port for single-port access
    protocol        = "tcp"                          # Standard TCP protocol for application traffic
    # CRITICAL: This restricts access so ONLY the Load Balancer can talk to the tasks
    security_groups = [aws_security_group.alb_sg.id] 
  }

  # Egress: Defines rules for outgoing traffic from your app
  egress {
    from_port   = 0             # The starting range for all possible ports
    to_port     = 0             # The ending range for all possible ports
    protocol    = "-1"          # Allows all protocols
    # Essential for tasks to reach the Internet (via NAT) to pull Docker images or call APIs
    cidr_blocks = ["0.0.0.0/0"] 
  }
}