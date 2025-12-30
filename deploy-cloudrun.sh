#!/bin/bash
# Deployment script for Google Cloud Run
# Created by Arun Kumar Singh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-"your-project-id"}
REGION=${GCP_REGION:-"asia-south1"}
SERVICE_NAME=${SERVICE_NAME:-"unopim"}
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo -e "${GREEN}Starting deployment to Google Cloud Run...${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install it first.${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting GCP project to ${PROJECT_ID}...${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "${YELLOW}Enabling required Google Cloud APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f Dockerfile.cloudrun -t ${IMAGE_NAME}:latest .

# Push the image to Google Container Registry
echo -e "${YELLOW}Pushing image to Google Container Registry...${NC}"
docker push ${IMAGE_NAME}:latest

# Deploy to Cloud Run
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME}:latest \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --port 8080 \
    --memory 2Gi \
    --cpu 2 \
    --min-instances 0 \
    --max-instances 10 \
    --set-env-vars "$(cat .env.cloudrun | grep -v '^#' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')" \
    --timeout 300 \
    --concurrency 80

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Service URL: $(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)')${NC}"

