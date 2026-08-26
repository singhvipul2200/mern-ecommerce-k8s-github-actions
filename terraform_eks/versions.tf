# ------------------------------------------------------------------------------------
# versions.tf
# Terraform + provider version pinning for the EKS module.
# ------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Needed by addons.tf to fetch the OIDC issuer's TLS certificate
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Needed to download the official AWS Load Balancer Controller IAM policy JSON
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    # Needed to install the AWS Load Balancer Controller via its Helm chart
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

# Used by the helm provider below to authenticate to the cluster
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# Lets Terraform talk to the cluster's Kubernetes API to install the
# Load Balancer Controller's Helm chart.
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
