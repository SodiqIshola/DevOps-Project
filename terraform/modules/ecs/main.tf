# --- 1. CLOUDWATCH LOG GROUP (The Black Box Recorder) ---
# Create a dedicated log group in CloudWatch for your application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/fargate-node-app" # The path where logs will be found in the console
  retention_in_days = 7                       # Automatically deletes logs after 7 days to save money
  tags              = { Name = "fargate-app-logs" }
}

# --- 2. THE ECS CLUSTER (The Logical Home) ---
# This acts as the administrative boundary for your services and tasks.
resource "aws_ecs_cluster" "main" {
  # Sets the physical name of the cluster as it will appear in the AWS Management Console
  name = "nodejs-fargate-cluster"

  # Begins a configuration block to customize specific cluster-level behaviors
  setting {
    # Identifies the specific feature to be toggled, in this case, 
    # CloudWatch Container Insights
    name  = "containerInsights"
    # Switches the feature on to gather high-resolution telemetry 
    # (CPU, RAM, Network) for your containers
    value = "enabled"
  }
}

# --- 3. THE TASK DEFINITION (The Blueprint) ---
# Defines the blueprint for how your containers should be launched and linked together
resource "aws_ecs_task_definition" "app" {
  # A unique identifier for this specific application task template
  family                   = "node-app-task"
  # Mandatory for Fargate; gives each task its own Private IP within your VPC
  network_mode             = "awsvpc"
  # Tells AWS to run this on the serverless engine rather than managing EC2 servers
  requires_compatibilities = ["FARGATE"]
  # Hard limit on processing power (256 units = 0.25 CPU cores)
  cpu                      = "256"
  # Hard limit on memory; if the app exceeds 512MB, AWS will kill the container
  memory                   = "512"
  # The "Infrastructure Role": Allows ECS to pull images from ECR and send logs to CloudWatch
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # The "Application Role": Gives the Node.js code itself permission to access AWS services
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture       = var.cpu_architecture 
  }

  # --- SHARED VOLUME ---
  # Creates a logical storage space that exists inside the task's lifecycle
  volume {
    # The internal name used to link this storage to specific containers below
    name = "log_volume"
  }

  # The actual container setup, converted to the JSON format AWS expects
  container_definitions = jsonencode([
    # --- MAIN NODE.JS CONTAINER ---
    {
      # Name of the primary application container
      name      = "node-app-container"
      # The location of your application code in your container registry
      image     = var.container_image
      # If this container crashes, the entire task (including the sidecar) is restarted
      essential = true

      environment = [
        # Keep existing EMF metrics (Log-based for ECS)
        { name = "AWS_EMF_ENVIRONMENT", value = "ECS" },
        # Explicitly tells your tracer.js where the sidecar is
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4318/v1/traces" },
        # Names your service for the CloudWatch Trace Map
        { name = "OTEL_SERVICE_NAME", value = "node-task-app" }
      ]

      # Connects the shared "log_volume" to a folder inside this container
      mountPoints = [{
        # Matches the name defined in the 'volume' block above
        sourceVolume  = "log_volume"
        # The exact folder path inside your Linux container where the app writes its .log files
        containerPath = "/app/logs"
      }]

      portMappings = [{
        containerPort = var.app_port
        hostPort      = var.app_port
      }]


      # Health Check: Helps the ALB know if the container is internally frozen
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60 # Gives Node.js time to boot up before checking
      }


      # SYSTEM LOGS: Captures console.log and crash reports (STDOUT/STDERR)
      # Your Node.js app should now use a library aws-embedded-metrics
      # to print JSON to STDOUT. CloudWatch will parse this into metrics automatically.
      logConfiguration = {
        # Standard AWS driver that sends console output directly to CloudWatch
        logDriver = "awslogs"
        options = {
          # The CloudWatch group where logs will be stored
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          # The AWS region where your logs are hosted
          "awslogs-region"        = var.aws_region
          # A prefix to help identify which task instance sent the log
          "awslogs-stream-prefix" = "container-system-messages"
        }
      }
    },

    # --- 2. ADOT COLLECTOR SIDECAR (NEW: FOR TRACING) ---
    {
      # Names the sidecar container (this name is used for internal ECS tracking).
      name      = "aws-otel-collector"
      # Uses the official AWS-maintained image that contains the OTel Collector.
      # This image is pre-built to talk to X-Ray and CloudWatch.
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      # 'true' means if the collector crashes, the entire ECS Task (and your app) restarts.
      essential = true
      # Tells the collector to use a built-in AWS config file.
      # '/etc/otel-instance-config.yaml' is a default file inside the image 
      # that automatically sets up OTLP receivers and the X-Ray exporter.
      command   = ["--config=/etc/otel-instance-config.yaml"]      
      # Configures where the collector's own internal health/error logs are sent.
      logConfiguration = {
        # Uses the standard AWS driver to ship the collector's console output to CloudWatch.
        logDriver = "awslogs"
        options = {
          # Groups these logs with your app's logs so you can see everything in one place.
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          # Ensures the logs go to the correct AWS data center.
          "awslogs-region"        = var.aws_region
          # Adds "otel" to the start of the log stream name to keep them organized.
          "awslogs-stream-prefix" = "otel"
        }
      }
    },


    # --- LOG ROUTER SIDECAR (Fluent Bit) ---
    # Captures file-based logs (/app/logs/app.log) and ships them to CloudWatch
    {
      # Name of the secondary container responsible for shipping file-based logs
      name      = "log-router"
      # Amazon's pre-built image optimized for routing logs from Fargate
      image     = "amazon/aws-for-fluent-bit:latest"
      # Ensures that if the log forwarder dies, the task is considered failed
      essential = true

      # Plugs the sidecar into the SAME shared volume as the Node.js app
      mountPoints = [{
        sourceVolume  = "log_volume"
        # The path where the sidecar will look to find the Node.js log files
        containerPath = "/mnt/logs"
      }]

      # Command to tail the specific file and output it to CloudWatch
      command = [
        "/fluent-bit/bin/fluent-bit",
        "-i", "tail",
        "-p", "path=/mnt/logs/app.log",
        "-o", "cloudwatch_logs",
        "-p", "region=${var.aws_region}",
        "-p", "log_group_name=${aws_cloudwatch_log_group.app_logs.name}",
        "-p", "log_stream_prefix=app-file-logs-"
      ]
    }
  ])
}

# --- 4. THE ECS SERVICE (The Manager) ---
# The Service manages the lifecycle and desired count of your tasks
resource "aws_ecs_service" "main" {
  name            = "node-app-service"              # Unique name for this specific service
  cluster         = aws_ecs_cluster.main.id         # Tells the service which cluster to run in
  task_definition = aws_ecs_task_definition.app.arn # Uses the Task Definition created earlier
  desired_count   = 2                               # Keeps 2 copies running for high availability
  launch_type     = "FARGATE"                       # Specifies serverless execution

  # --- DEPLOYMENT STRATEGY ---
  # Defines how AWS handles updates when you change your Docker image.
  deployment_controller {
    # "ECS" is the standard rolling update. 
    type = "ECS"
  }

  # --- ROLLING UPDATE CONFIGURATION ---
  # Logic: Always keep 100% available, allow up to 200% during transition.
  # Ensures at least one task is always running during the update
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Network Configuration: Required for the 'awsvpc' network mode
  network_configuration {
    # Places the tasks in the private subnets for security
    subnets         = var.private_subnet_ids
    # Uses the security group that ONLY allows traffic from the ALB
    security_groups = [var.ecs_tasks_sg_id]
    # Set to false because tasks use the NAT Gateway to reach the internet
    assign_public_ip = false
  }

  # Load Balancer Integration: Connects the tasks to the ALB Target Group
  load_balancer {
    target_group_arn = var.target_group_arn # The ARN from your ALB module
    container_name   = "node-app-container" # MUST match the name in your task definition
    container_port   = var.app_port         # The port your Node.js app listens on (e.g., 3000)
  }

  # --- DEPENDENCY MANAGEMENT ---
  # Ensures the Load Balancer and its Listeners are fully active BEFORE ECS tries to register tasks.
  depends_on = [var.alb_listener_arn]
}
