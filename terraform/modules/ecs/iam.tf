# -----------------------------------------------------------------------------
# ECS TASK EXECUTION ROLE
# Provides ECS Fargate tasks the permissions to pull images from ECR and send logs to CloudWatch.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Attach AWS managed policy for standard ECS execution permissions.
resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# ECS TASK ROLE
# Provides the application-level permissions for the Node.js container.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Attach CloudWatch permissions to allow the application to push metrics and logs.
resource "aws_iam_role_policy_attachment" "ecs_task_cw_metrics" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach AWS X-Ray permissions for tracing from the OTEL sidecar.
resource "aws_iam_role_policy_attachment" "otel_xray_write" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}



