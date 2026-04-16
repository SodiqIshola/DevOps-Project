# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# Internet-facing ALB routing external traffic to ECS tasks.
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "node-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = { Name = "node-app-alb" }
}

# -----------------------------------------------------------------------------
# TARGET GROUP
# Directs traffic to ECS tasks in 'awsvpc' mode.
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "app" {
  name        = "node-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# -----------------------------------------------------------------------------
# LISTENER
# Listens on port 80 and forwards traffic to the target group.
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}



