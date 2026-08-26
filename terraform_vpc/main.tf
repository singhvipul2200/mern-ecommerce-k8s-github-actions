# ------------------------------------------------------------------------------------
# main.tf
# Creates:
#   1. A VPC (10.0.0.0/16)
#   2. An Internet Gateway (so public subnets can reach the internet)
#   3. Two PUBLIC subnets in two DIFFERENT Availability Zones
#   4. A public route table (routes 0.0.0.0/0 -> Internet Gateway)
#   5. Route table associations so both subnets use that public route table
#
# Tags on the subnets/VPC follow AWS's required EKS tagging convention so this
# network can be reused directly by the EKS cluster built in terraform_eks/.
# ------------------------------------------------------------------------------------

# 1. THE VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # required so EKS/pods can resolve DNS
  enable_dns_hostnames = true # required for EKS worker nodes to get proper hostnames

  tags = {
    Name = "${var.project_name}-vpc"

    # EKS requirement: the VPC (and subnets) used by an EKS cluster should be
    # tagged so the AWS cloud-controller-manager / load balancer controller
    # can auto-discover them. "shared" = usable by more than one cluster.
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# 2. INTERNET GATEWAY - attached to the VPC, lets public subnets talk to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 3. PUBLIC SUBNETS
# count = 2 creates two subnets, one per CIDR/AZ pair.
# NOTE: element() cycles through the availability_zones list so each subnet
# lands in a DIFFERENT AZ (index 0 -> AZ[0], index 1 -> AZ[1]).
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # instances launched here auto-get a public IP

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"

    # --- Required/expected EKS tags for PUBLIC subnets ---
    # Tells the EKS cluster this subnet belongs to it (needed for the
    # AWS Load Balancer Controller / cloud-controller-manager to discover it).
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"

    # Tells Kubernetes this is a PUBLIC subnet suitable for internet-facing
    # load balancers (ELB/ALB). Value must be "1" (as a string).
    "kubernetes.io/role/elb" = "1"
  }
}

# 4. PUBLIC ROUTE TABLE - any traffic not destined for the VPC CIDR goes to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 5. ASSOCIATE both public subnets with the public route table above
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
