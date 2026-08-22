#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Install AWS Load Balancer Controller on an EKS cluster
# ============================================================
# Prerequisites:
#   - AWS CLI configured with administrator (or equivalent) access
#   - kubectl pointed at the target cluster
#     (aws eks update-kubeconfig --name <cluster> --region <region>)
#   - eksctl and helm installed
#
# EDIT THESE TWO VALUES BEFORE RUNNING:
CLUSTER_NAME="your-eks-cluster-name"
AWS_REGION="your-region"          # e.g. us-east-1

NAMESPACE="kube-system"
SA_NAME="aws-load-balancer-controller"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
POLICY_FILE="/tmp/iam_policy.json"
TRUST_POLICY_FILE="/tmp/trust-policy.json"

echo "=============================================="
echo "Step 0: Basic info"
echo "=============================================="
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo "Cluster: $CLUSTER_NAME | Region: $AWS_REGION"

# ------------------------------------------------------------
# 1. Get this cluster's REAL OIDC issuer directly (not assumed)
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 1: Get this cluster's OIDC issuer"
echo "=============================================="
OIDC_ISSUER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID="${OIDC_ISSUER##*/}"
echo "This cluster's OIDC issuer: $OIDC_ISSUER"
echo "OIDC ID: $OIDC_ID"

EXISTING_OIDC=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_ID')].Arn" --output text)

if [ -z "$EXISTING_OIDC" ]; then
  echo "No OIDC provider registered for THIS cluster - creating one via eksctl..."
  eksctl utils associate-iam-oidc-provider --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --approve
else
  echo "OIDC provider already registered for this cluster: $EXISTING_OIDC"
fi

OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"
echo "Using OIDC provider ARN: $OIDC_PROVIDER_ARN"

# ------------------------------------------------------------
# 2. IAM policy - create if missing, UPDATE if outdated
# ------------------------------------------------------------
# GOTCHA: if a policy with this name already exists from a
# DIFFERENT/older project, it may be missing newer required
# actions (e.g. elasticloadbalancing:DescribeListenerAttributes).
# This step always refreshes it to the latest official version
# rather than blindly skipping if it already exists.
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 2: Create or refresh IAM policy"
echo "=============================================="
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

curl -fsSL -o "$POLICY_FILE" \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  echo "Policy already exists: $POLICY_ARN"
  echo "Refreshing it to the latest official version..."

  VERSION_COUNT=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
    --query "length(Versions)" --output text)

  if [ "$VERSION_COUNT" -ge 5 ]; then
    echo "Policy already has 5 versions (the AWS limit) - deleting the oldest non-default one first."
    OLDEST_VERSION=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
      --query "Versions[?IsDefaultVersion==\`false\`] | sort_by(@, &CreateDate)[0].VersionId" --output text)
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$OLDEST_VERSION"
    echo "Deleted old version $OLDEST_VERSION."
  fi

  aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default
  echo "Policy refreshed to the latest version."
else
  echo "Policy not found - creating it..."
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://${POLICY_FILE}"
  echo "Created policy: $POLICY_ARN"
fi

# ------------------------------------------------------------
# 3. IAM role - create if missing, FIX trust policy if it points
#    to a different (stale) cluster's OIDC provider
# ------------------------------------------------------------
# GOTCHA: if a role with this name already exists from a
# DIFFERENT project/cluster, its trust policy will reference
# THAT cluster's OIDC ID, not this one. Using it as-is would
# cause a silent "AccessDenied: AssumeRoleWithWebIdentity" error
# that looks like a permissions problem but is actually just a
# stale trust relationship. This step always rewrites the trust
# policy to match THIS cluster, whether the role is new or not.
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 3: Create or fix IAM role trust policy"
echo "=============================================="

cat > "$TRUST_POLICY_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:${NAMESPACE}:${SA_NAME}",
          "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Role $ROLE_NAME already exists."
  CURRENT_TRUST=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.AssumeRolePolicyDocument" --output json)
  if echo "$CURRENT_TRUST" | grep -q "$OIDC_ID"; then
    echo "Trust policy already points to THIS cluster's OIDC provider - no change needed."
  else
    echo "Trust policy points to a DIFFERENT (stale) OIDC provider - updating it now."
    aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://${TRUST_POLICY_FILE}"
    echo "Trust policy updated to match this cluster."
  fi
else
  echo "Role does not exist - creating it..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${TRUST_POLICY_FILE}"
fi

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text)
echo "Role ARN: $ROLE_ARN"

# ------------------------------------------------------------
# 4. Attach policy to role (safe to re-run, idempotent)
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 4: Attach policy to role"
echo "=============================================="
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --output table

# ------------------------------------------------------------
# 5. Kubernetes ServiceAccount
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 5: Create/annotate ServiceAccount"
echo "=============================================="
if kubectl get serviceaccount "$SA_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "ServiceAccount already exists."
else
  kubectl create serviceaccount "$SA_NAME" -n "$NAMESPACE"
fi

kubectl annotate serviceaccount "$SA_NAME" -n "$NAMESPACE" \
  eks.amazonaws.com/role-arn="$ROLE_ARN" --overwrite

kubectl describe serviceaccount "$SA_NAME" -n "$NAMESPACE"

# ------------------------------------------------------------
# 6. Helm install/upgrade
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 6: Install/upgrade the controller via Helm"
echo "=============================================="
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update eks

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "Using VPC ID: $VPC_ID"

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SA_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID"

# ------------------------------------------------------------
# 7. Restart to guarantee fresh IRSA tokens, then verify
# ------------------------------------------------------------
echo ""
echo "=============================================="
echo "Step 7: Restart controller and verify"
echo "=============================================="
kubectl rollout restart deployment aws-load-balancer-controller -n "$NAMESPACE"
kubectl rollout status deployment aws-load-balancer-controller -n "$NAMESPACE" --timeout=120s

kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl get deployment -n "$NAMESPACE" aws-load-balancer-controller \
  -o jsonpath='{.spec.template.spec.serviceAccountName}'
echo ""

echo ""
echo "=============================================="
echo "DONE. If pods above are Running and the ServiceAccount"
echo "matches $SA_NAME, the controller is installed and"
echo "correctly wired to THIS cluster's IAM identity."
echo "=============================================="
