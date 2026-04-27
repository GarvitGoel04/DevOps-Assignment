terraform {
  # For production, we use S3 for remote state and DynamoDB for state locking.
  # This ensures state is isolated and locked during concurrent operations.
  # Note: The bucket and table must be created before running terraform init.
  # 
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "aws/${var.environment}/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}
