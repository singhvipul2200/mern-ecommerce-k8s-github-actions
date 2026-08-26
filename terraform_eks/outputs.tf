# ------------------------------------------------------------------------------------
# outputs.tf
# ------------------------------------------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data for cluster auth"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "node_group_status" {
  description = "Current status of the managed node group"
  value       = aws_eks_node_group.main.status
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider - needed later for IRSA roles (e.g. Load Balancer Controller, EBS CSI driver)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "ebs_csi_driver_role_arn" {
  description = "IRSA role ARN used by the EBS CSI driver add-on"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "lb_controller_role_arn" {
  description = "IRSA role ARN used by the AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}
