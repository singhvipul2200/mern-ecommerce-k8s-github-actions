# ------------------------------------------------------------------------------------
# lb-controller.tf
# AWS Load Balancer Controller - REQUIRED if you want to use Kubernetes
# Ingress (ALB) or Service type=LoadBalancer (NLB) objects to expose apps.
# Without this, Ingress resources just sit there doing nothing - EKS does
# NOT include this controller by default.
#
# Steps:
#   1. Download the official IAM policy JSON straight from the controller's
#      GitHub repo (kept in sync with the actual permissions it needs - safer
#      than hand-copying a large policy that changes between versions).
#   2. Create an IAM policy from that JSON.
#   3. Create an IRSA role trusted only by the controller's own service account.
#   4. Install the controller into the cluster via its official Helm chart.
# ------------------------------------------------------------------------------------

# 1. Fetch the official IAM policy JSON for a specific, pinned controller version
data "http" "lb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.lb_controller_chart_app_version}/docs/install/iam_policy.json"
}

# 2. Create the IAM policy from that JSON
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.lb_controller_iam_policy.response_body
}

# 3. Trust policy: only the controller's own service account can assume this role
data "aws_iam_policy_document" "lb_controller_assume_role" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.cluster_name}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# 4. Install the controller itself via the official eks-charts Helm chart.
# serviceAccount.create = true + the eks.amazonaws.com/role-arn annotation
# is what wires the pod up to the IAM role above (IRSA).
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.lb_controller_helm_chart_version

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller.arn
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.lb_controller,
  ]
}
