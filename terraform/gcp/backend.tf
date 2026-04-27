terraform {
  # For production, we use GCS for remote state which supports native locking.
  # 
  # backend "gcs" {
  #   bucket  = "my-terraform-state-bucket"
  #   prefix  = "terraform/state/gcp/${var.environment}"
  # }
}
