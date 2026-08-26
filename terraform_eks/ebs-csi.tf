# ------------------------------------------------------------------------------------
# ebs-csi.tf
# EBS CSI driver - REQUIRED if any pod uses a PersistentVolumeClaim backed by
# EBS (StorageClass "gp2"/"gp3" etc). Without this add-on, PVCs will stay
# stuck in "Pending" forever because nothing can provision the volumes.
#
# Uses IRSA (IAM Roles for Service Accounts) so the driver has ONLY the EBS
# permissions it needs, scoped to its own service account - not the whole
# node's IAM role. Requires the OIDC provider created in addons.tf.
# ------------------------------------------------------------------------------------

# Trust policy: only the "ebs-csi-controller-sa" service account (in the
# kube-system namespace) is allowed to assume this role - nothing else.
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

# AWS-managed policy that grants exactly the EBS permissions the CSI driver needs
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# The actual EKS add-on. service_account_role_arn wires it up to the IRSA
# role above so it doesn't fall back to (overly broad) node IAM permissions.
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [aws_eks_node_group.main]
}
