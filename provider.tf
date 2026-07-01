provider "aws" {
  region  = "eu-west-1"
  # profile = "pet-adoption"
}
 
terraform {
  backend "s3" {
    bucket       = "seyi-my-project-bucket-2026"
    use_lockfile = true
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    # profile      = "pet-adoption"
  }
}
 

 