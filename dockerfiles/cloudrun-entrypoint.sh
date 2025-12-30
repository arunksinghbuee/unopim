#!/bin/bash
# Entrypoint script for Google Cloud Run
# Created by Arun Kumar Singh

set -e

# Run migrations if requested
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    php artisan migrate --force
fi

# Optimize Laravel for production
echo "Optimizing Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Start Apache
exec apache2-foreground

