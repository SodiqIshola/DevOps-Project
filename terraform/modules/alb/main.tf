# --- THE LOAD BALANCER ---
resource "aws_lb" "main" {
  name               = "node-app-alb"
  internal           = false           # Set to false so it is accessible from the internet
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]          # Uses the SG we made in networking
  subnets            = var.public_subnet_ids    # ALB must be in Public Subnets

  tags = { Name = "node-app-alb" }
}

# --- THE TARGET GROUP ---
# This defines WHERE the traffic goes (Port 3000 on our Tasks)
resource "aws_lb_target_group" "app" {
  name        = "node-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # IMPORTANT: Fargate 'awsvpc' mode requires target_type 'ip'

  # Health Check: The ALB will ping this path to see if the Node.js app is alive
  health_check {
    enabled             = true
    path                = "/" # Your Node.js app must respond to this path
    port                = "traffic-port"
    healthy_threshold   = 3   # Consider healthy after 3 successful pings
    unhealthy_threshold = 3   # Consider dead after 3 failed pings
    timeout             = 5
    interval            = 30
    matcher             = "200" # Expect a '200 OK' response
  }
}

# --- THE LISTENER ---
# This defines WHAT the ALB listens for (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # By default, forward all traffic to our Target Group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}








