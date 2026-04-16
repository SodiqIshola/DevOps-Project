# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# Centralized location for application and sidecar logs with 7-day retention.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/fargate-node-app"
  retention_in_days = 7
  tags              = { Name = "fargate-app-logs" }
}

# -----------------------------------------------------------------------------
# ECS CLUSTER
# Logical boundary for Fargate tasks and associated services.
# Container Insights enabled for telemetry and operational visibility.
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "nodejs-fargate-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# -----------------------------------------------------------------------------
# ECS TASK DEFINITION
# Blueprint for application and sidecar containers, volumes, and resource allocations.
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "node-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture       = var.cpu_architecture
  }

  volume {
    name = "log_volume"
  }

  container_definitions = jsonencode([
    {
      name      = "node-app-container"
      image     = var.container_image
      essential = true
      command   = var.container_command

      environment = [
        { name = "NODE_ENV", value = "var.node_env" },
        { name = "AWS_EMF_ENVIRONMENT", value = "ECS" },
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4318/v1/traces" },
        { name = "OTEL_SERVICE_NAME", value = "node-task-app" }
      ]

      mountPoints = [{
        sourceVolume  = "log_volume"
        containerPath = "/app/logs"
      }]

      portMappings = [{
        containerPort = var.app_port
        hostPort      = var.app_port
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "container-system-messages"
        }
      }
    },

    {
      # AWS OTEL Collector: Uses the built-in ECS default configuration to collect 
      # application traces (AWS X-Ray) and OTLP metrics without needing a custom file.
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = true
      command   = ["--config=/etc/ecs/ecs-default-config.yaml"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "otel"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# ECS SERVICE
# Maintains desired task count, handles rolling updates, integrates with ALB.
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "main" {
  name            = "node-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "node-app-container"
    container_port   = var.app_port
  }

  depends_on = [var.alb_listener_arn]
}


