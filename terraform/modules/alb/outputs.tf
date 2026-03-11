# The DNS Name is what you actually type into your browser to see the app
output "alb_dns_name" {
  description = "The public URL of the Load Balancer"
  value       = aws_lb.main.dns_name
}

# The Target Group ARN is the most important output for the ECS Service
# It tells ECS: "Send my container traffic to this specific group"
output "target_group_arn" {
  description = "The ARN of the Target Group to be used by the ECS Service"
  value       = aws_lb_target_group.app.arn
}

# Useful for debugging or adding advanced Listener Rules later
output "alb_arn" {
  description = "The Amazon Resource Name of the Load Balancer"
  value       = aws_lb.main.arn
}


output "listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

# The Zone ID is needed if you want to point a custom domain (Route53) to this ALB
output "alb_zone_id" {
  description = "The Canonical Hosted Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}