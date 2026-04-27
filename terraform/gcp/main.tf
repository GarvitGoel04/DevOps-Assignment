terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Enable required APIs
resource "google_project_service" "run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# ==========================================
# Cloud Run: Backend
# ==========================================
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.environment}-backend-srv"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }
    containers {
      image = var.backend_image
      ports {
        container_port = 8000
      }
    }
  }

  depends_on = [google_project_service.run_api]
}

# Allow unauthenticated access to the backend (since frontend needs to talk to it, or limit to internal)
resource "google_cloud_run_v2_service_iam_member" "backend_invoker" {
  project  = google_cloud_run_v2_service.backend.project
  location = google_cloud_run_v2_service.backend.location
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ==========================================
# Cloud Run: Frontend
# ==========================================
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.environment}-frontend-srv"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = var.frontend_min_instances
      max_instance_count = var.frontend_max_instances
    }
    containers {
      image = var.frontend_image
      env {
        name  = "BACKEND_URL"
        value = replace(google_cloud_run_v2_service.backend.uri, "https://", "")
      }
      ports {
        container_port = 3000
      }
    }
  }

  depends_on = [google_project_service.run_api]
}

resource "google_cloud_run_v2_service_iam_member" "frontend_invoker" {
  project  = google_cloud_run_v2_service.frontend.project
  location = google_cloud_run_v2_service.frontend.location
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
