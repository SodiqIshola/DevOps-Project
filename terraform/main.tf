
# --- 1. FETCH THE IMAGE DIGEST ---
# This looks up the specific SHA-256 hash currently assigned to the 'latest' tag. 
# By using this digest, AWS will trigger a rebuild and rollout if there is a new 
# 'latest' image, as the unique SHA hash changes even if the tag name stays the same.
data "aws_ecr_image" "app_image" {
  repository_name = "sunky24/node-task-app"
  image_tag       = "latest"
}



# --- NETWORKING MODULE ---
# This calls your folder /modules/networking/ and runs main.tf, security.tf, etc.
module "networking" {
  source         = "./modules/networking"
  vpc_cidr       = var.vpc_cidr
  container_port = var.container_port
}


# --- ALB MODULE ---
# This block tells Terraform to look into your custom 'alb' folder to build the Load Balancer
module "alb" {
  # Tells Terraform where the ALB logic (main.tf, variables.tf) is located
  source = "./modules/alb"
  # Links the ALB to the network we just built by passing the VPC ID output
  vpc_id = module.networking.vpc_id
  # Passes the 2 Public Subnet IDs so the ALB knows where to sit and listen for internet traffic
  public_subnet_ids = module.networking.public_subnet_ids
  # Attaches the 'Port 80' security group we created in the networking module to the ALB
  alb_sg_id = module.networking.alb_sg_id
  # Defines the destination port (3000) for the Target Group so the ALB knows where the Node.js app is listening
  app_port = var.container_port
  
}


# --- ECS MODULE ---
# This block tells Terraform to execute the logic inside your 'ecs' module folder
module "ecs" {
  # Specifies the local file path where the ECS task, service, and IAM roles are defined
  source = "./modules/ecs"

  # COMBINE URL AND DIGEST:
  # Format: [URL]:[TAG]@[DIGEST]
  # Example: ://123456789012.dkr.ecr.us-east-1.amazonaws.com...
  container_image = data.aws_ecr_image.app_image.image_uri


  # The internal port your Node.js application listens on (3000); used for Task and ALB mapping
  app_port = var.container_port
  # Passes the list of Private Subnet IDs from the networking module; this is where the tasks physically run
  private_subnet_ids = module.networking.private_subnet_ids
  # Passes the Security Group ID that only allows inbound traffic on port 3000 from the Load Balancer
  ecs_tasks_sg_id = module.networking.ecs_tasks_sg_id
  # Connects the ECS Service to the ALB Target Group so the balancer knows where to send incoming web traffic
  target_group_arn = module.alb.target_group_arn
  # Tells the CloudWatch log driver which region to send your container's stdout and file-based logs to
  aws_region = var.aws_region
  # Links the Service deployment to the ALB Listener to ensure the network path is ready before the app starts
  alb_listener_arn = module.alb.listener_arn
  cpu_architecture = var.cpu_architecture

}


