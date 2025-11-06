# Mandatory Tool Usage

THIS IS MANDATORY

- **Code Generation, Debug:** Prior to ANY code generation or debugging acctions, you MUST use your tools `get-library-docs` and `resolve-library-id` in conjunction to define and get up-to-date library documentation and code snippets. You must use these lessons learned from the tool output to generate new code.

# Technical Context

## Technology Stack

The project should be architected as a monolithic web application using the Flask framework in Python. This simplifies the deployment and security model, especially for running on Google Cloud Run.

- **Framework:** **Flask** is a lightweight Python web framework that serves both the HTML pages and the backend API endpoints.
- **Language (Backend):** **Python** is used for all server-side logic, including handling requests, interacting with the database, and generating dynamic content.
- **Language (Frontend):** **HTML, CSS (Tailwind), and Vanilla JavaScript** are used for the client-side presentation and interactivity. The highly interactive functionality (such as camera, if necessary) is handled by a dedicated JavaScript file.
- **Database:** **Google Cloud Firestore** is used for persisting data (if needed)
- **Storage:** **Google Cloud Storage** should be the standard for storing static data
- **Authentication:** The application uses the server-side Google Cloud Python libraries (`google-cloud-firestore`, `google-cloud-storage`) which leverage Application Default Credentials (ADC) for secure, keyless authentication when running on Google Cloud Run.
- **Containerization:** **Docker** is used to containerize the Flask application, making it portable and easy to deploy on Google Cloud Run.

## Development Conventions

- **Monolithic Architecture:** The application is a single Flask service. This contrasts with the SPA + Mock API architecture.
- **Environment-Aware Logic:** The application should detect its environment (local vs. production) using environment variables (e.g., `K_SERVICE` on Cloud Run). This allows it to adapt its behavior, such as switching between local static file URLs and GCS URLs.
- **Configuration Management:**
  - Project-specific configuration (like Project ID, bucket name, etc.) is managed through a `.env` file, loaded by the `python-dotenv` library.
  - A `.env.example` file should always be created and committed to version control to serve as a template for required environment variables.
  - The `.env` file itself should be included in `.gitignore` and never committed.
- **Dependency Management:** Python dependencies are managed with `pip` and a `requirements.txt` file.
- **Virtual Environment:** All Python development must be done within a virtual environment to isolate dependencies. Use `python3 -m venv venv` to create it and `source venv/bin/activate` to activate it.

## UX and Design Standards

- **Styling:** Use **Tailwind CSS** for a utility-first CSS approach.
- **Aesthetic:** Adhere to a clean, modern, "Google-like" design.
- **Branding Element:** Incorporate a 4-color horizontal bar (Blue, Red, Yellow, Green) as a signature visual element in UI cards or headers.
- **Interactivity:** Enhance user experience with real-time feedback on forms using vanilla JavaScript. Avoid heavy dependencies for simple tasks.
- **Localization:** All user-facing text must be translated into the target language (e.g., Portuguese).

## Security

- **GCS Object Access:** All objects in Google Cloud Storage must be kept private. Public access should be strictly avoided.
- **Signed URLs:** To provide secure and temporary access to private GCS objects, the backend must generate **Signed URLs**. These URLs grant short-lived permissions to clients (like a web browser) to view a specific object.
- **IAM for Signed URLs:** The Cloud Run service account requires two specific IAM roles to generate signed URLs:
  1.  `roles/iam.serviceAccountTokenCreator`: Allows the service account to create the necessary authentication token.
  2.  `roles/storage.objectViewer`: Allows the service account to read the GCS objects it needs to create URLs for.

# Deployment Strategy

- **GCP-first deployment:** The code / project will be run in GCP, using Google Cloud Run. All your deployment, port exposure selection, should consider that. Use your tools for fetching the latest GCP docs.
- **Automated Deployment Script:** A `deploy.sh` script should be the standard way to deploy the application. This script should:
  1.  Source variables from the `.env` file.
  2.  Check for the existence of necessary cloud resources (like GCS buckets) and create them if they are missing.
  3.  Synchronize static assets (like images) with the GCS bucket.
  4.  Deploy the application to Cloud Run using `gcloud run deploy`.
  5.  Automatically configure necessary IAM permissions after the first deployment.
