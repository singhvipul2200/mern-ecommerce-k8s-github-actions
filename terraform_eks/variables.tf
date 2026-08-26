# ------------------------------------------------------------------------------------
# variables.tf
# ------------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into. North Virginia = us-east-1"
  type        = string
  default     = "us-east-1"
}

# IMPORTANT: this must match the eks_cluster_name value used in terraform_vpc,
# otherwise the subnet tags (kubernetes.io/cluster/<name>) won't match this cluster.
variable "cluster_name" {
  description = "Name of the EKS cluster - must match eks_cluster_name in terraform_vpc"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance type(s) for the worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

# --- Manually supplied network info ---
# After you run `terraform apply` in terraform_vpc, copy the vpc_id and
# public_subnet_ids values from its output and paste them here (or pass
# via -var / terraform.tfvars). Nothing is auto-fetched from that folder.

variable "vpc_id" {
  description = "VPC ID (copy this from terraform_vpc output: vpc_id)"
  type        = string
  # example: "vpc-0123456789abcdef0"
}

variable "subnet_ids" {
  description = "List of the two public subnet IDs (copy from terraform_vpc output: public_subnet_ids)"
  type        = list(string)
  # example: ["subnet-0123abc", "subnet-0456def"]
}

# --- AWS Load Balancer Controller settings ---

variable "lb_controller_chart_app_version" {
  description = "Git tag of the aws-load-balancer-controller repo to pull the IAM policy JSON from (must match the app version inside the Helm chart)"
  type        = string
  default     = "v2.9.0"
}

variable "lb_controller_helm_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart to install"
  type        = string
  default     = "1.9.0"
}
