data "aws_caller_identity" "current" {}

locals {
  tags = {
    Project = "modelops"
  }
}

# Dedicated EKS VPC and networking

resource "aws_vpc" "eks" {
  cidr_block           = "10.80.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "modelops-eks-vpc"
  }
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "modelops-eks-igw"
  }
}

resource "aws_subnet" "a" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "10.80.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "modelops-eks-subnet-a"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "b" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "10.80.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "modelops-eks-subnet-b"
    "kubernetes.io/role/elb" = "1"
  }
}


resource "aws_subnet" "c" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "10.80.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "modelops-eks-subnet-c"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "d" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "10.80.4.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "modelops-eks-subnet-d"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "f" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "10.80.5.0/24"
  availability_zone       = "us-east-1f"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "modelops-eks-subnet-f"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "modelops-eks-public-routes"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.b.id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.d.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "f" {
  subnet_id      = aws_subnet.f.id
  route_table_id = aws_route_table.public.id
}

# EKS control-plane IAM role

resource "aws_iam_role" "cluster" {
  name = "modelops-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS control plane

resource "aws_eks_cluster" "gpu" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.a.id,
      aws_subnet.b.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true

    public_access_cidrs = [
      var.admin_cidr
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]

  tags = {
    Name = var.cluster_name
  }
}

# Cluster administrator access

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.gpu.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.gpu.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# GPU worker IAM role

resource "aws_iam_role" "node" {
  name = "modelops-eks-gpu-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "registry" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Single NVIDIA L4 worker.
# Capacity recovery: use only us-east-1b.

resource "aws_eks_node_group" "gpu" {
  cluster_name    = aws_eks_cluster.gpu.name
  node_group_name = "modelops-l4"
  node_role_arn   = aws_iam_role.node.arn

  subnet_ids = [
    aws_subnet.b.id,
    aws_subnet.c.id,
    aws_subnet.d.id,
    aws_subnet.f.id
  ]

  instance_types = ["g6.xlarge"]
  ami_type       = "AL2023_x86_64_NVIDIA"
  capacity_type  = "ON_DEMAND"
  disk_size      = 120

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "gpu-inference"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker,
    aws_iam_role_policy_attachment.registry,
    aws_iam_role_policy_attachment.cni,
    aws_route.internet,
    aws_route_table_association.a,
    aws_route_table_association.b
  ]

  tags = {
    Name = "modelops-l4"
  }
}
