# ------------------------------------------------------------------------------------
# variables.tf
# All configurable inputs for the VPC module live here so nothing is hardcoded
# in main.tf. Change values via terraform.tfvars or -var flags, not by editing main.tf.
# ------------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into. North Virginia = us-east-1"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "AZs (within us-east-1) that each public subnet will be placed in - must be different AZs"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "project_name" {
  description = "Name prefix used to tag all resources created by this module"
  type        = string
  default     = "myapp"
}

# EKS needs to know which cluster will use these subnets so it can tag them
# correctly (kubernetes.io/cluster/<cluster-name> = shared). Set this to the
# SAME name you plan to give your EKS cluster in the terraform_eks folder.
variable "eks_cluster_name" {
  description = "Name of the EKS cluster that will use this VPC/subnets (used for required EKS tags)"
  type        = string
  default     = "my-eks-cluster"
}
