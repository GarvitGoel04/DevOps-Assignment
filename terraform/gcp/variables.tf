variable "gcp_project_id" {
  type    = string
  default = "my-gcp-project-id" # Placeholder
}
variable "gcp_region" {
  type    = string
  default = "us-central1"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "backend_image" {
  type    = string
  default = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder
}
variable "frontend_image" {
  type    = string
  default = "us-docker.pkg.dev/cloudrun/container/hello" # Placeholder
}
variable "frontend_min_instances" {
  type    = number
  default = 0
}
variable "frontend_max_instances" {
  type    = number
  default = 5
}
variable "backend_min_instances" {
  type    = number
  default = 0
}
variable "backend_max_instances" {
  type    = number
  default = 5
}
