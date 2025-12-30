# Quick Start: Deploy UnoPim to Google Cloud Run

**Created by Arun Kumar Singh**

This is a condensed guide for deploying UnoPim to Google Cloud Run with AWS S3 and CloudFront.

## Prerequisites Checklist

- [ ] Google Cloud account with billing enabled
- [ ] AWS account
- [ ] gcloud CLI installed (`gcloud --version`)
- [ ] Docker installed (`docker --version`)
- [ ] AWS CLI installed (`aws --version`) - optional but helpful

## Quick Setup Steps

### 1. AWS S3 & CloudFront (5 minutes)

```bash
# Create S3 bucket
aws s3 mb s3://unopim-media --region ap-south-1

# Create CloudFront distribution (use AWS Console or script)
./setup-cloudfront.sh

# Create IAM user for S3 access
# - Go to AWS IAM Console
# - Create user with S3 read/write permissions
# - Save Access Key ID and Secret Access Key
```

### 2. Google Cloud Setup (5 minutes)

```bash
# Set project
export PROJECT_ID="your-project-id"
gcloud config set project ${PROJECT_ID}

# Enable APIs
gcloud services enable cloudbuild.googleapis.com run.googleapis.com containerregistry.googleapis.com

# Create Cloud SQL (optional - or use external DB)
gcloud sql instances create unopim-db \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=asia-south1 \
    --root-password=YOUR_PASSWORD
```

### 3. Configure Environment (2 minutes)

```bash
# Copy environment template
cp env.cloudrun.example .env.cloudrun

# Edit .env.cloudrun with your values:
# - Database credentials
# - AWS S3 credentials
# - CloudFront URL
# - APP_KEY (generate with: php artisan key:generate --show)
```

### 4. Deploy (10 minutes)

```bash
# Make scripts executable
chmod +x deploy-cloudrun.sh
chmod +x setup-cloudfront.sh

# Deploy
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="asia-south1"
./deploy-cloudrun.sh
```

### 5. Post-Deployment

```bash
# Get service URL
gcloud run services describe unopim --region asia-south1 --format 'value(status.url)'

# Access the URL and complete installation wizard
# Or run installation via CLI (see full guide)
```

## Environment Variables Summary

Key variables you need to set in `.env.cloudrun`:

```bash
# Database
DB_CONNECTION=mysql
DB_HOST=your-db-host
DB_DATABASE=unopim
DB_USERNAME=your-user
DB_PASSWORD=your-password

# AWS S3
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_DEFAULT_REGION=ap-south-1
AWS_BUCKET=unopim-media

# CloudFront
CLOUDFRONT_URL=https://d1234abcd.cloudfront.net
FILESYSTEM_DISK=s3
```

## Troubleshooting

**Images not uploading?**
- Check `FILESYSTEM_DISK=s3` is set
- Verify AWS credentials
- Check S3 bucket permissions

**Can't access CloudFront?**
- Wait 5-15 minutes for distribution deployment
- Verify `CLOUDFRONT_URL` is correct
- Check S3 bucket policy allows CloudFront

**Database connection failed?**
- Verify credentials
- For Cloud SQL: Check IP whitelist or use Cloud SQL Proxy
- Test connection: `gcloud sql connect unopim-db --user=root`

## Next Steps

- Read full guide: `DEPLOYMENT-CLOUDRUN.md`
- Set up queue worker (see full guide)
- Configure custom domain
- Set up monitoring and alerts

---

**For detailed instructions, see DEPLOYMENT-CLOUDRUN.md**

