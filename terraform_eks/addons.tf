# ------------------------------------------------------------------------------------
# addons.tf
# Sets up:
#   1. The OIDC provider for the cluster - REQUIRED before installing add-ons
#      that use IRSA (IAM Roles for Service Accounts), and best practice even
#      for the core add-ons below.
#   2. The core EKS add-ons: vpc-cni, coredns, kube-proxy.
#      These are NOT installed automatically by aws_eks_cluster - they must be
#      requested explicitly, otherwise you get a cluster with no pod networking,
#      no DNS, and no kube-proxy until you install them manually via the console/CLI.
# ------------------------------------------------------------------------------------

# Fetches the TLS certificate for the cluster's OIDC issuer URL - needed to
# register the identity provider with IAM in the next resource.
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Registers the cluster's OIDC provider with IAM so IRSA (fine-grained,
# pod-level IAM permissions) can be used later by add-ons like the EBS CSI
# driver or the AWS Load Balancer Controller.
resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

# ---------- VPC CNI add-on ----------
# Gives pods real VPC IP addresses (pod networking). Without this, pods can't
# get IPs and nothing can schedule successfully.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # depends_on the node group so the addon activates after nodes exist
  depends_on = [aws_eks_node_group.main]
}

# ---------- CoreDNS add-on ----------
# Cluster-internal DNS - lets pods/services resolve each other by name
# (e.g. my-service.my-namespace.svc.cluster.local).
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  # CoreDNS pods need somewhere to run, so wait for worker nodes to exist first
  depends_on = [aws_eks_node_group.main]
}

# ---------- kube-proxy add-on ----------
# Maintains network rules on each node so Kubernetes Services route traffic
# correctly to the right pods.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_node_group.main]
}
