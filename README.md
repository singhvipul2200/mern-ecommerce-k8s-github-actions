# AWS EKS Infrastructure with Terraform

Provisions a VPC and EKS cluster on AWS using Terraform, including core
EKS add-ons and the AWS Load Balancer Controller configured via IRSA.

---

## Terraform Commands (init → apply)

Run `terraform_vpc` first, then `terraform_eks` (EKS needs the VPC's
`vpc_id` / `subnet_ids`, copied manually into `terraform_eks/terraform.tfvars`).

### terraform_vpc/

```bash
cd terraform_vpc
```

```bash
terraform init
```
Downloads the AWS provider and sets up the local backend/state file. Run once
per folder (and again if providers change).

```bash
terraform fmt
```
Auto-formats `.tf` files for consistent style. Optional.

```bash
terraform validate
```
Checks the code is syntactically valid and internally consistent. Doesn't
talk to AWS.

```bash
terraform plan
```
Shows exactly what will be created (VPC, IGW, 2 subnets, route table,
associations) without creating anything yet. Always review before applying.

```bash
terraform apply
```
Creates the resources in AWS. Prompts for `yes` confirmation
(add `-auto-approve` to skip it).

```bash
terraform output
```
Prints output values — you need `vpc_id` and `public_subnet_ids` from here
for the terraform_eks folder.

### terraform_eks/

```bash
cd ../terraform_eks
```

```bash
cp terraform.tfvars.example terraform.tfvars
```
Copy the example vars file, then edit it and paste in the `vpc_id` and
`subnet_ids` from the VPC output above.

```bash
terraform init
```
Downloads all providers this folder needs: aws, tls, http, helm.

```bash
terraform validate
```
Same syntax/consistency check as before.

```bash
terraform plan
```
Shows everything that will be created: EKS cluster, node group (2 nodes,
min 2/max 4), IAM roles, OIDC provider, 4 add-ons (vpc-cni, coredns,
kube-proxy, ebs-csi-driver), and the Load Balancer Controller Helm release.

```bash
terraform apply
```
Creates everything. EKS cluster creation alone typically takes 10-15
minutes, then the node group, add-ons, and Helm release run after.

```bash
terraform output
```
Shows cluster endpoint, OIDC provider ARN, and the two IRSA role ARNs.

### Tearing everything down (reverse order)

```bash
cd terraform_eks
terraform destroy
```

```bash
cd ../terraform_vpc
terraform destroy
```
EKS must be destroyed **first** since it depends on the VPC's subnets —
destroying the VPC while EKS still exists in it will fail or leave orphaned
resources.

### State locking

Terraform locks the state file during `apply`/`plan` to prevent two runs
from touching it at once. With the local backend used here, a
`.terraform.tfstate.lock.info` file appears next to `terraform.tfstate`
during an operation and disappears when it finishes. If Terraform crashes
mid-run and the lock doesn't clear:
```bash
terraform force-unlock <LOCK_ID>
```
(the LOCK_ID is shown in the error message)

---

# AWS CLI Setup & Verification Guide

This guide covers installing/configuring the AWS CLI, confirming your credentials
are set correctly, and verifying (via CLI, from Git Bash) that the resources
created by `terraform_vpc` and `terraform_eks` actually exist in your AWS account.

---

## 1. Install AWS CLI

**Windows (Git Bash uses the Windows install):**
1. Download the installer: https://awscli.amazonaws.com/AWSCLIV2.msi
2. Run it (next, next, finish).
3. Verify install by opening Git Bash and running:
   ```bash
   aws --version
   ```
   You should see something like `aws-cli/2.x.x Python/3.x.x Windows/...`

**Mac:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

---

## 2. Configure AWS CLI with your credentials

You need an **Access Key ID** and **Secret Access Key** from IAM
(IAM console → Users → your user → Security credentials → Create access key).

Run:
```bash
aws configure
```

It will prompt for 4 things:
```
AWS Access Key ID [None]: <paste your access key>
AWS Secret Access Key [None]: <paste your secret key>
Default region name [None]: us-east-1
Default output format [None]: json
```

This writes two files (on Windows, under `C:\Users\<you>\.aws\`, visible from Git
Bash at `~/.aws/`):
- `~/.aws/credentials` → stores the access key + secret key
- `~/.aws/config` → stores region + output format

---

## 3. Verify your Access Key / Secret Key are actually set

**Check what's currently configured (masks the secret key partially):**
```bash
aws configure list
```
Expected output shows `access_key` and `secret_key` columns with a value
source of `config-file` (not `<not set>`).

**Confirm the credentials are valid and working (recommended - talks to AWS):**
```bash
aws sts get-caller-identity
```
Expected output (real values will differ):
```json
{
    "UserId": "AIDAEXAMPLE123456",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```
If this returns an error like `Unable to locate credentials`, `aws configure` either
wasn't run or was saved under a different profile.

**If using named profiles instead of default:**
```bash
aws configure list --profile myprofile
aws sts get-caller-identity --profile myprofile
```

---

## 4. Verify infrastructure in AWS Console (via CLI from Git Bash)

Run these after `terraform apply` completes in each folder, to confirm what
Terraform created actually exists in AWS.

### VPC
```bash
aws ec2 describe-vpcs --filters "Name=cidr,Values=10.0.0.0/16" --region us-east-1
```
Confirms the VPC exists with the expected CIDR block.

### Subnets
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<your-vpc-id>" --region us-east-1
```
Lists both public subnets, their CIDRs, and their Availability Zones — check
they're in two different AZs (e.g. `us-east-1a` and `us-east-1b`).

**Check the EKS tags landed on the subnets correctly:**
```bash
aws ec2 describe-subnets --subnet-ids <subnet-id-1> <subnet-id-2> \
  --query "Subnets[*].Tags" --region us-east-1
```
Look for `kubernetes.io/cluster/<cluster-name>=shared` and
`kubernetes.io/role/elb=1` in the output.

### Internet Gateway & Route Table
```bash
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=<your-vpc-id>" --region us-east-1
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<your-vpc-id>" --region us-east-1
```

### EKS Cluster (name, status, endpoint)
```bash
aws eks list-clusters --region us-east-1
aws eks describe-cluster --name <cluster-name> --region us-east-1
```
Check `"status": "ACTIVE"` and confirm it's using the correct `vpcId` and
`subnetIds` under `resourcesVpcConfig`.

### Node Group (should show desired=2, min=2, max=4)
```bash
aws eks list-nodegroups --cluster-name <cluster-name> --region us-east-1
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <node-group-name> --region us-east-1
```
Check `"scalingConfig"` matches `{"minSize": 2, "maxSize": 4, "desiredSize": 2}`
and `"instanceTypes": ["t3.medium"]`.

### OIDC Provider
```bash
aws eks describe-cluster --name <cluster-name> --region us-east-1 \
  --query "cluster.identity.oidc.issuer"

aws iam list-open-id-connect-providers
```
The issuer URL from the first command (minus `https://`) should match one of
the ARNs listed by the second command.

### EKS Add-ons (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver)
```bash
aws eks list-addons --cluster-name <cluster-name> --region us-east-1
aws eks describe-addon --cluster-name <cluster-name> --addon-name vpc-cni --region us-east-1
aws eks describe-addon --cluster-name <cluster-name> --addon-name coredns --region us-east-1
aws eks describe-addon --cluster-name <cluster-name> --addon-name kube-proxy --region us-east-1
aws eks describe-addon --cluster-name <cluster-name> --addon-name aws-ebs-csi-driver --region us-east-1
```
Check each shows `"status": "ACTIVE"`.

### IAM Roles (cluster role, node role, EBS CSI role, LB Controller role)
```bash
aws iam get-role --role-name <cluster-name>-cluster-role
aws iam get-role --role-name <cluster-name>-node-role
aws iam get-role --role-name <cluster-name>-ebs-csi-driver-role
aws iam get-role --role-name <cluster-name>-lb-controller-role
```

### AWS Load Balancer Controller (verify it's running - requires kubectl)
```bash
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```
`update-kubeconfig` points `kubectl` at your new cluster; the following two
commands confirm the controller deployment/pods are `Running`.

---

## Quick reference: everything in one pass

```bash
aws sts get-caller-identity
aws ec2 describe-vpcs --region us-east-1
aws ec2 describe-subnets --region us-east-1
aws eks list-clusters --region us-east-1
aws eks list-nodegroups --cluster-name <cluster-name> --region us-east-1
aws eks list-addons --cluster-name <cluster-name> --region us-east-1
aws iam list-open-id-connect-providers
```
