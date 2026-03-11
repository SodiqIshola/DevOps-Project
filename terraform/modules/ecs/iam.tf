# --- 1. THE EXECUTION ROLE (Infrastructure Level) ---

# This role is for the Fargate Agent (the "worker") that manages your container.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-execution-role" # The name assigned to the role in the IAM Console

  # The "Assume Role Policy" defines WHO is allowed to use this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"         # The standard IAM policy language version
    Statement = [{
      Action    = "sts:AssumeRole" # Grants permission to switch into this role
      Effect    = "Allow"          # Explicitly allows the action
      Principal = { 
        Service = "ecs-tasks.amazonaws.com" # Specifically allows the ECS service to use it
      }
    }]
  })
}

# --- 2. ATTACH MANAGED POLICY ---

# We attach a pre-made AWS policy so you don't have to write low-level permissions.
resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_task_execution_role.name # Links the attachment to the Execution Role
  # This specific [AmazonECSTaskExecutionRolePolicy](https://docs.aws.amazon.com) 
  # provides the necessary permissions to pull images from [Amazon ECR](https://aws.amazon.com) 
  # and send container logs to [Amazon CloudWatch](https://aws.amazon.com).
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



# --- 3. THE TASK ROLE (Application Level) ---

# This role is for your internal Node.js logic (e.g., calling S3, DynamoDB, or SES).
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role" # Distinct name for the application-level role
  
  # Just like the execution role, the ECS service must be allowed to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"         # Standard policy versioning
    Statement = [{
      Action    = "sts:AssumeRole" # Permission to assume the role
      Effect    = "Allow"          # Allows the request
      Principal = { 
        Service = "ecs-tasks.amazonaws.com" # Allows ECS to pass these permissions to your code
      }
    }]
  })
}



# --- ATTACH CLOUDWATCH PERMISSIONS ---
# This specific attachment is what allows your "Brain" to push metrics and logs.
resource "aws_iam_role_policy_attachment" "ecs_task_cw_metrics" {
  role       = aws_iam_role.ecs_task_role.name
  # This managed policy contains the permissions for CloudWatch Metrics & Logs.
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# This connects a specific "Permission Slip" (Policy) to your "Service Identity" (Role).
resource "aws_iam_role_policy_attachment" "otel_xray_write" {
  # This points to your ECS Task Role (the identity your app uses while it is running).
  # It ensures the "identity" matches the name you gave your IAM Role in Terraform.
  role       = aws_iam_role.ecs_task_role.name
  # This is the official AWS "ID Card" that gives permission to save Traces.
  # Without this exact link, the OTel sidecar will get "Access Denied" errors.
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}







