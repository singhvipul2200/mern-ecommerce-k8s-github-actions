# ------------------------------------------------------------------------------------
# versions.tf
# Defines the Terraform version and provider requirements for this module.
# Pinning versions here prevents "it worked yesterday" issues caused by provider drift.
# ------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # NOTE: For real/production use, configure a remote backend (S3 + DynamoDB lock table)
  # instead of local state. Left as local state here for simplicity so the
  # terraform_eks folder can read it via terraform_remote_state.
  backend "local" {
    path = "terraform.tfstate"
  }
}

# AWS Provider configuration - region comes from variables.tf (defaults to us-east-1 / N. Virginia)
provider "aws" {
  region = var.aws_region
}
