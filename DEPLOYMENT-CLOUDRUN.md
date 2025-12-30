# UnoPim Deployment Guide: Google Cloud Run with AWS S3 & CloudFront

**Created by Arun Kumar Singh**

This guide will help you deploy UnoPim on Google Cloud Run with AWS S3 for image storage and CloudFront for CDN delivery.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS S3 & CloudFront Setup](#aws-s3--cloudfront-setup)
3. [Google Cloud Setup](#google-cloud-setup)
4. [Database Setup](#database-setup)
5. [Environment Configuration](#environment-configuration)
6. [Building and Deploying](#building-and-deploying)
7. [Post-Deployment](#post-deployment)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts & Tools

- **Google Cloud Platform** account with billing enabled
- **AWS** account with S3 and CloudFront access
- **gcloud CLI** installed and configured
- **Docker** installed locally
- **Database** (MySQL 8.0.32+ or PostgreSQL 14+)
  - Option 1: Google Cloud SQL
  - Option 2: External managed database
  - Option 3: Self-hosted database

### Install gcloud CLI

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Windows
# Download from: https://cloud.google.com/sdk/docs/install
```

### Authenticate gcloud

```bash
gcloud auth login
gcloud auth configure-docker
```

---

## AWS S3 & CloudFront Setup

### Step 1: Create S3 Bucket

1. Go to AWS S3 Console
2. Click **Create bucket**
3. Configure:
   - **Bucket name**: `unopim-media` (or your preferred name)
   - **Region**: Choose Mumbai region (`ap-south-1`)
   - **Block Public Access**: Uncheck "Block all public access" (we'll use CloudFront)
   - **Versioning**: Enable if needed
   - **Encryption**: Enable server-side encryption

4. Click **Create bucket**

### Step 2: Configure S3 Bucket Policy

1. Go to your bucket → **Permissions** → **Bucket Policy**
2. Add the following policy (replace `YOUR_BUCKET_NAME` and `YOUR_CLOUDFRONT_OAI_ID`):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity YOUR_CLOUDFRONT_OAI_ID"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
        }
    ]
}
```

### Step 3: Create CloudFront Distribution

1. Go to AWS CloudFront Console
2. Click **Create Distribution**
3. Configure:
   - **Origin Domain**: Select your S3 bucket
   - **Origin Access**: Select "Origin Access Control (OAC)" or "Origin Access Identity (OAI)"
   - **Viewer Protocol Policy**: Redirect HTTP to HTTPS
   - **Allowed HTTP Methods**: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
   - **Cache Policy**: Choose "CachingOptimized" or create custom
   - **Price Class**: Choose based on your needs
   - **Alternate Domain Names (CNAMEs)**: Optional - add your custom domain
   - **SSL Certificate**: Use default or upload custom certificate

4. Click **Create Distribution**
5. Wait for deployment (5-15 minutes)
6. Note your **CloudFront Distribution Domain Name** (e.g., `d1234abcd.cloudfront.net`)

### Step 4: Create IAM User for S3 Access

1. Go to AWS IAM Console
2. Click **Users** → **Create user**
3. User name: `unopim-s3-user`
4. Select **Programmatic access**
5. Attach policy: Create custom policy with:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET_NAME",
                "arn:aws:s3:::YOUR_BUCKET_NAME/*"
            ]
        }
    ]
}
```

6. Save the **Access Key ID** and **Secret Access Key** (you'll need these later)

---

## Google Cloud Setup

### Step 1: Create GCP Project

```bash
# Set your project ID
export PROJECT_ID="your-unopim-project"

# Create project (or use existing)
gcloud projects create ${PROJECT_ID} --name="UnoPim Production"

# Set as current project
gcloud config set project ${PROJECT_ID}

# Enable billing (required for Cloud Run)
# Do this via GCP Console: https://console.cloud.google.com/billing
```

### Step 2: Enable Required APIs

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable sqladmin.googleapis.com  # If using Cloud SQL
```

### Step 3: Set Up Cloud SQL (Optional but Recommended)

If using Cloud SQL for database:

```bash
# Create Cloud SQL instance (MySQL)
gcloud sql instances create unopim-db \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=asia-south1 \
    --root-password=YOUR_ROOT_PASSWORD

# Create database
gcloud sql databases create unopim --instance=unopim-db

# Create user
gcloud sql users create unopim-user \
    --instance=unopim-db \
    --password=YOUR_USER_PASSWORD
```

**Note**: For production, use a higher tier instance (e.g., `db-n1-standard-1` or higher).

---

## Database Setup

### Option 1: Google Cloud SQL

Use the Cloud SQL instance created above. Connection details:
- **Host**: Use Cloud SQL Proxy or Public IP
- **Port**: 3306
- **Database**: `unopim`
- **Username**: `unopim-user`
- **Password**: Your user password

### Option 2: External Database

Use any managed MySQL/PostgreSQL service:
- **AWS RDS**
- **DigitalOcean Managed Database**
- **PlanetScale**
- **Self-hosted database**

---

## Environment Configuration

### Step 1: Create Environment File

Copy the example environment file:

```bash
cp env.cloudrun.example .env.cloudrun
```

### Step 2: Configure Environment Variables

Edit `.env.cloudrun` with your actual values:

```bash
# Application
APP_NAME=UnoPim
APP_ENV=production
APP_KEY=base64:YOUR_GENERATED_KEY
APP_URL=https://unopim-xxxxx.run.app
APP_TIMEZONE=UTC
APP_LOCALE=en_US
APP_CURRENCY=USD

# Database
DB_CONNECTION=mysql
DB_HOST=YOUR_DB_HOST
DB_PORT=3306
DB_DATABASE=unopim
DB_USERNAME=your_db_user
DB_PASSWORD=your_db_password

# AWS S3 & CloudFront
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_DEFAULT_REGION=ap-south-1
AWS_BUCKET=unopim-media
CLOUDFRONT_URL=https://d1234abcd.cloudfront.net
FILESYSTEM_DISK=s3

# Redis (Optional - for caching)
REDIS_HOST=your_redis_host
REDIS_PASSWORD=your_redis_password
REDIS_PORT=6379

# Queue
QUEUE_CONNECTION=database
SESSION_DRIVER=database
CACHE_DRIVER=file

# Mail
MAIL_MAILER=smtp
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=your_sendgrid_api_key
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="UnoPim"
```

### Step 3: Generate Application Key

```bash
# Generate APP_KEY
php artisan key:generate --show
# Copy the output and add to APP_KEY in .env.cloudrun
```

---

## Building and Deploying

### Method 1: Using Deployment Script

```bash
# Make script executable
chmod +x deploy-cloudrun.sh

# Set environment variables
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="asia-south1"
export SERVICE_NAME="unopim"

# Run deployment
./deploy-cloudrun.sh
```

### Method 2: Manual Deployment

#### Step 1: Build Docker Image

```bash
docker build -f Dockerfile.cloudrun -t gcr.io/${PROJECT_ID}/unopim:latest .
```

#### Step 2: Push to Container Registry

```bash
docker push gcr.io/${PROJECT_ID}/unopim:latest
```

#### Step 3: Deploy to Cloud Run

```bash
gcloud run deploy unopim \
    --image gcr.io/${PROJECT_ID}/unopim:latest \
    --platform managed \
    --region asia-south1 \
    --allow-unauthenticated \
    --port 8080 \
    --memory 2Gi \
    --cpu 2 \
    --min-instances 0 \
    --max-instances 10 \
    --set-env-vars "$(cat .env.cloudrun | grep -v '^#' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')" \
    --timeout 300 \
    --concurrency 80
```

### Method 3: Using Cloud Build

```bash
# Submit build
gcloud builds submit --config cloudbuild.yaml

# Or trigger from Cloud Build Console
```

---

## Post-Deployment

### Step 1: Run Initial Setup

Access your Cloud Run service URL and complete the installation wizard, or run via CLI:

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe unopim --region asia-south1 --format 'value(status.url)')

# Run installation (if not done via installer)
gcloud run jobs create unopim-install \
    --image gcr.io/${PROJECT_ID}/unopim:latest \
    --region asia-south1 \
    --set-env-vars "$(cat .env.cloudrun | grep -v '^#' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')" \
    --command php \
    --args artisan,unopim:install,-n

# Execute job
gcloud run jobs execute unopim-install --region asia-south1
```

### Step 2: Set Up Queue Worker (Optional)

For background jobs, deploy a separate Cloud Run service for queue processing:

```bash
# Create queue worker Dockerfile
cat > Dockerfile.queue <<EOF
FROM gcr.io/${PROJECT_ID}/unopim:latest
ENTRYPOINT ["php", "artisan", "queue:work", "--queue=system,default", "--tries=3"]
EOF

# Build and deploy
docker build -f Dockerfile.queue -t gcr.io/${PROJECT_ID}/unopim-queue:latest .
docker push gcr.io/${PROJECT_ID}/unopim-queue:latest

gcloud run deploy unopim-queue \
    --image gcr.io/${PROJECT_ID}/unopim-queue:latest \
    --platform managed \
    --region asia-south1 \
    --no-allow-unauthenticated \
    --memory 1Gi \
    --cpu 1 \
    --min-instances 1 \
    --max-instances 5 \
    --set-env-vars "$(cat .env.cloudrun | grep -v '^#' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')"
```

### Step 3: Verify S3 Integration

1. Log in to UnoPim admin panel
2. Upload a product image
3. Check S3 bucket - image should be stored there
4. Check CloudFront URL - image should be accessible via CDN

### Step 4: Set Up Custom Domain (Optional)

```bash
# Map custom domain
gcloud run domain-mappings create \
    --service unopim \
    --domain yourdomain.com \
    --region asia-south1

# Follow DNS verification instructions
```

---

## Troubleshooting

### Issue: Images not uploading to S3

**Solution:**
- Verify AWS credentials are correct
- Check S3 bucket permissions
- Ensure `FILESYSTEM_DISK=s3` is set
- Check Cloud Run logs: `gcloud logging read "resource.type=cloud_run_revision" --limit 50`

### Issue: Images not accessible via CloudFront

**Solution:**
- Verify CloudFront distribution is deployed
- Check CloudFront origin access settings
- Verify `CLOUDFRONT_URL` environment variable
- Check S3 bucket policy allows CloudFront access

### Issue: Database connection errors

**Solution:**
- Verify database credentials
- For Cloud SQL, ensure Cloud SQL Proxy is configured or IP is whitelisted
- Check network connectivity from Cloud Run to database
- Review database logs

### Issue: High cold start times

**Solution:**
- Set `--min-instances=1` to keep at least one instance warm
- Optimize Docker image size
- Use Cloud CDN for static assets

### Issue: Memory or CPU limits exceeded

**Solution:**
- Increase memory: `--memory 4Gi`
- Increase CPU: `--cpu 4`
- Optimize application code
- Review Cloud Run metrics in GCP Console

---

## Cost Optimization Tips

1. **Use Cloud CDN** for static assets
2. **Set appropriate min/max instances** based on traffic
3. **Use Cloud SQL with appropriate tier** for your workload
4. **Enable Cloud Run request-based pricing** for low traffic
5. **Use S3 Intelligent-Tiering** for image storage
6. **Set up CloudFront caching** to reduce S3 requests

---

## Security Best Practices

1. **Use Secret Manager** for sensitive environment variables:
   ```bash
   # Create secret
   echo -n "your-secret" | gcloud secrets create db-password --data-file=-
   
   # Use in Cloud Run
   gcloud run services update unopim \
       --update-secrets DB_PASSWORD=db-password:latest
   ```

2. **Enable Cloud Armor** for DDoS protection
3. **Use IAM roles** instead of service account keys
4. **Enable VPC connector** for private database access
5. **Regularly rotate** AWS access keys
6. **Enable CloudFront WAF** for additional protection

---

## Monitoring & Logging

### View Logs

```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Real-time logs
gcloud logging tail "resource.type=cloud_run_revision"
```

### Set Up Alerts

1. Go to GCP Console → Monitoring → Alerting
2. Create alert policies for:
   - High error rate
   - High latency
   - Memory/CPU usage
   - Request count

---

## Additional Resources

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [UnoPim Documentation](https://unopim.com/docs)

---

**Created by Arun Kumar Singh**

For issues or questions, please refer to the UnoPim GitHub repository or contact support.

