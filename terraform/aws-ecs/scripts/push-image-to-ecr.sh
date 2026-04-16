
#!/bin/bash

# --- SET YOUR VARIABLES ---
PROFILE="tf-project"
REGION="ca-central-1"
SOURCE_IMAGE="sunky24/node-task-app:latest"  # The Docker Hub image
REPO_NAME="sunky24/node-task-app"            # The ECR repository name

# 1. Automatically get Account ID from the profile
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Targeting ECR: $ECR_URL/$REPO_NAME"

# 2. Create the ECR Repository 
aws ecr create-repository --repository-name $REPO_NAME --region $REGION --profile $PROFILE || true

# 3. Login to ECR using your AWS Profile credentials
aws ecr get-login-password --region $REGION --profile $PROFILE | docker login --username AWS --password-stdin $ECR_URL

# 4. Pull from Docker Hub
docker pull $SOURCE_IMAGE

# 5. Tag for ECR (keeping the name and tag identical)
docker tag $SOURCE_IMAGE ${ECR_URL}/${REPO_NAME}:latest

# 6. Push to ECR
docker push ${ECR_URL}/${REPO_NAME}:latest
