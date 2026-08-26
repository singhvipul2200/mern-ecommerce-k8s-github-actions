# ------------------------------------------------------------------------------------
# main.tf
# Creates:
#   1. IAM role + policies for the EKS control plane
#   2. The EKS cluster itself, placed in the public subnets from terraform_vpc
#   3. IAM role + policies for the worker nodes
#   4. A managed Node Group (the actual EC2 worker nodes)
#
# NOTE: Using public subnets for worker nodes is fine for learning/dev, but for
# production workloads AWS recommends running worker nodes in PRIVATE subnets
# and only exposing load balancers publicly. Since you said "public subnets only",
# this deploys everything (control plane + nodes) into the public subnets.
# ------------------------------------------------------------------------------------

# ---------- 1. EKS CONTROL PLANE IAM ROLE ----------
# The EKS service itself needs permission to manage AWS resources on your behalf
# (ENIs, load balancers, etc). This role is what the cluster assumes.
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attaches AWS's managed policy that grants the permissions EKS needs to operate
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# ---------- 2. THE EKS CLUSTER ----------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids # manually supplied via variables.tf / tfvars
    endpoint_public_access   = true          # allow kubectl access from the internet
    endpoint_private_access  = false
  }

  # Cluster must wait for the IAM policy to be attached before it can be created
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = var.cluster_name
  }
}

# ---------- 3. WORKER NODE IAM ROLE ----------
# EC2 worker nodes need their own role to join the cluster and pull images, etc.
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Lets the node join the EKS cluster
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

# Lets the node manage networking (CNI plugin - pod IP addressing)
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

# Lets the node pull container images from ECR
resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# ---------- 4. MANAGED NODE GROUP (the actual worker EC2 instances) ----------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids # same 2 public subnets, manually supplied

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Node group must wait for these IAM policies to be attached first
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}
