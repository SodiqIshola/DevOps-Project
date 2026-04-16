
# ---  FETCH THE IMAGE DIGEST ---
data "aws_ecr_image" "app_image" {
  repository_name = "sunky24/node-task-app"
  image_tag       = "latest"
}


# --- NETWORKING MODULE ---
# This calls your folder /modules/networking/ and runs main.tf, security.tf, etc.
module "networking" {
  source        = "../../../modules/networking"
  vpc_cidr      = var.vpc_cidr

  public_subnet_tags = {
    Environment = "production"
    Team        = "platform"
    Project     = "fargate-app"
  }

  private_subnet_tags = {
    Environment = "production"
    Team        = "platform"
    Project     = "fargate-app"
    Access      = "internal-only"
  }

}


# --- ALB MODULE ---
# This block tells Terraform to look into your custom 'alb' folder to build the Load Balancer
module "alb" {
  source            = "../../modules/alb"
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  app_port          = var.container_port
  
}


# --- ECS MODULE ---
# This block tells Terraform to execute the logic inside your 'ecs' module folder
module "ecs" {
  source                = "../../modules/ecs"
  container_image       = data.aws_ecr_image.app_image.image_uri
  app_port              = var.container_port
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_tasks_sg_id       = module.alb.ecs_tasks_sg_id
  target_group_arn      = module.alb.target_group_arn
  aws_region            = var.aws_region
  alb_listener_arn      = module.alb.listener_arn
  cpu_architecture      = var.cpu_architecture
  node_env              = var.node_env
  container_command     = var.container_command

}




