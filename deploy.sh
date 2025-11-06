#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
SERVICE_NAME="churrasco-app"

# --- Helper Functions ---
check_env_var() {
    local var_name="$1"
    local var_value="$2"
    local placeholder="$3"

    if [ -z "$var_value" ] || [ "$var_value" == "$placeholder" ]; then
        echo "⚠️ Error: $var_name is not set or is still the placeholder value in the .env file."
        echo "⚠️ Please set $var_name in your .env file before deploying."
        exit 1
    fi
}

# --- Pre-flight Checks ---
echo "🚀 Starting deployment script..."

if [ ! -f .env ]; then
    echo "⚠️ Error: .env file not found."
    exit 1
fi

set -a
source .env
set +a

check_env_var "GCS_BUCKET_NAME" "$GCS_BUCKET_NAME" "your-bucket-name-here"
check_env_var "PROJECT_ID" "$PROJECT_ID" "your-gcp-project-id"

# --- Stage 1: Enable Necessary Google Cloud APIs ---
echo "\n☁️ --- Stage 1: Enabling Google Cloud APIs ---"
gcloud services enable run.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable iamcredentials.googleapis.com
echo "✅ APIs enabled."

# --- Stage 2: GCS Bucket and Image Upload ---
echo "\n Storage --- Stage 2: Syncing GCS Bucket and Images ---"

if ! gcloud storage buckets describe gs://$GCS_BUCKET_NAME --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "🪣 Bucket $GCS_BUCKET_NAME does not exist. Creating it..."
    gcloud storage buckets create gs://$GCS_BUCKET_NAME --location=us-central1 --project=$PROJECT_ID
    echo "✅ Bucket created."
else
    echo "✅ Bucket $GCS_BUCKET_NAME already exists."
fi

echo "⬆️ Uploading images to GCS bucket..."
gcloud storage cp -r static/images/* gs://$GCS_BUCKET_NAME/ --project=$PROJECT_ID
echo "✅ Image upload complete."

# --- Stage 2: Cloud Run Deployment ---
echo "
☁️🏃 --- Stage 2: Deploying to Cloud Run ---"

gcloud run deploy $SERVICE_NAME \
    --source . \
    --project=$PROJECT_ID \
    --region=us-central1 \
    --allow-unauthenticated \
    --set-env-vars="GCS_BUCKET_NAME=$GCS_BUCKET_NAME,SERVICE_ACCOUNT_EMAIL=$SERVICE_ACCOUNT_EMAIL"

echo "✅ Service deployed successfully."

# --- Stage 3: IAM Permission Configuration ---
echo "
🔒 --- Stage 3: Configuring IAM Permissions ---"

# If SERVICE_ACCOUNT_EMAIL is not set in .env, try to fetch it from the deployed service.
if [ -z "$SERVICE_ACCOUNT_EMAIL" ]; then
    echo "🔍 SERVICE_ACCOUNT_EMAIL not found in .env, fetching from deployed service..."
    SERVICE_ACCOUNT_EMAIL=$(gcloud run services describe $SERVICE_NAME --project=$PROJECT_ID --region=us-central1 --format='value(spec.template.spec.serviceAccountName)')
    
    if [ -z "$SERVICE_ACCOUNT_EMAIL" ]; then
        echo "⚠️ Error: Could not automatically fetch the service account email. Please deploy once, then find it in the Cloud Console and add it to your .env file."
        exit 1
    fi
    echo "✅ Found service account: $SERVICE_ACCOUNT_EMAIL"
fi

# Grant the Service Account permission to create signed URLs.
echo "🔑 Granting Service Account Token Creator role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --condition=None >/dev/null # Suppress verbose output

# Grant the Service Account permission to view objects in the bucket.
echo "👁️ Granting Storage Object Viewer role..."
gcloud storage buckets add-iam-policy-binding gs://$GCS_BUCKET_NAME \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.objectViewer" >/dev/null

# Ensure the bucket is not public.
echo "🔒 Making bucket private..."
gcloud storage buckets remove-iam-policy-binding gs://$GCS_BUCKET_NAME \
    --member=allUsers \
    --role=roles/storage.objectViewer >/dev/null 2>&1 || echo "✅ (Bucket was already private)"

echo "✅ IAM permissions configured successfully."

echo "⏰ Waiting 60 seconds for IAM permissions to propagate..."
sleep 60

# --- Done ---
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --project=$PROJECT_ID --region=us-central1 --format='value(status.url)')
echo "
🎉 Deployment complete!"
echo "🔗 Your service is available at: $SERVICE_URL"