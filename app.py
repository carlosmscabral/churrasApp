from flask import Flask, render_template, request
from dotenv import load_dotenv
import os
import datetime
from google.cloud import storage
import google.auth
from google.auth.transport import requests

load_dotenv()
app = Flask(__name__)

@app.route('/')
def index():
    image_name = 'a_churrasco_image.png'
    
    if os.getenv('K_SERVICE'):
        # Production environment (Cloud Run)
        credentials, project = google.auth.default()
        storage_client = storage.Client(credentials=credentials)

        gcs_bucket_name = os.getenv('GCS_BUCKET_NAME')
        service_account_email = os.getenv('SERVICE_ACCOUNT_EMAIL')

        # Explicitly refresh the credentials to get an access token.
        # This is the key step to solving the signing issue.
        auth_req = requests.Request()
        credentials.refresh(auth_req)

        bucket = storage_client.bucket(gcs_bucket_name)
        blob = bucket.blob(image_name)
        
        # Generate a signed URL, explicitly passing the refreshed access token.
        image_url = blob.generate_signed_url(
            version="v4",
            expiration=datetime.timedelta(minutes=15),
            method="GET",
            service_account_email=service_account_email,
            access_token=credentials.token,
        )
    else:
        # Local environment
        image_url = f'/static/images/{image_name}'
        
    return render_template('index.html', image_url=image_url)

if __name__ == '__main__':
    app.run(debug=True)
