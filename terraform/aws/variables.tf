variable "aws_region" {
  type    = string
  default = "us-west-2"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "backend_image" {
  type    = string
  default = "nginxdemos/hello" # Placeholder
}
variable "frontend_image" {
  type    = string
  default = "nginxdemos/hello" # Placeholder
}
variable "frontend_desired_count" {
  type    = number
  default = 1
}
variable "backend_desired_count" {
  type    = number
  default = 1
}
