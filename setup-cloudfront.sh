#!/bin/bash
# Script to help set up CloudFront for UnoPim S3 bucket
# Created by Arun Kumar Singh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}CloudFront Setup Helper for UnoPim${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}AWS CLI is not installed. Please install it first.${NC}"
    echo "Install: https://aws.amazon.com/cli/"
    exit 1
fi

# Get inputs
read -p "Enter your S3 bucket name: " BUCKET_NAME
read -p "Enter AWS region (default: ap-south-1 for Mumbai): " AWS_REGION
AWS_REGION=${AWS_REGION:-ap-south-1}
read -p "Enter CloudFront distribution comment (optional): " DIST_COMMENT

DIST_COMMENT=${DIST_COMMENT:-"UnoPim Media CDN"}

echo ""
echo -e "${YELLOW}Creating CloudFront distribution...${NC}"

# Create CloudFront distribution
DIST_OUTPUT=$(aws cloudfront create-distribution \
    --origin-domain-name "${BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com" \
    --comment "${DIST_COMMENT}" \
    --default-root-object "index.html" \
    --enabled \
    --viewer-protocol-policy "redirect-to-https" \
    --query 'Distribution.{Id:Id,DomainName:DomainName,Status:Status}' \
    --output json)

DIST_ID=$(echo $DIST_OUTPUT | jq -r '.Id')
DIST_DOMAIN=$(echo $DIST_OUTPUT | jq -r '.DomainName')

echo ""
echo -e "${GREEN}CloudFront distribution created!${NC}"
echo "Distribution ID: ${DIST_ID}"
echo "Domain Name: ${DIST_DOMAIN}"
echo ""
echo -e "${YELLOW}Note: It may take 5-15 minutes for the distribution to deploy.${NC}"
echo ""
echo "Update your .env.cloudrun file with:"
echo "CLOUDFRONT_URL=https://${DIST_DOMAIN}"
echo ""

