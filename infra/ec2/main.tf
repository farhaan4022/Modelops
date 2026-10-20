terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "modelops"

  default_tags {
    tags = {
      Project     = "modelops-farhan"
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "modelops-farhan"
}

# Network

resource "aws_vpc" "gpu" {
  cidr_block           = "10.72.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

resource "aws_subnet" "gpu" {
  vpc_id                  = aws_vpc.gpu.id
  cidr_block              = "10.72.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name}-subnet"
  }
}

resource "aws_internet_gateway" "gpu" {
  vpc_id = aws_vpc.gpu.id

  tags = {
    Name = "${local.name}-igw"
  }
}

resource "aws_route_table" "gpu" {
  vpc_id = aws_vpc.gpu.id

  tags = {
    Name = "${local.name}-routes"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.gpu.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gpu.id
}

resource "aws_route_table_association" "gpu" {
  subnet_id      = aws_subnet.gpu.id
  route_table_id = aws_route_table.gpu.id
}

# No inbound access; outbound access for SSM and downloads

resource "aws_security_group" "gpu" {
  name_prefix = "${local.name}-gpu-"
  description = "ModelOps GPU host - outbound only"
  vpc_id      = aws_vpc.gpu.id

  tags = {
    Name = "${local.name}-gpu-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.gpu.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound access for SSM and model downloads"
}

# IAM role for EC2 Session Manager

resource "aws_iam_role" "gpu" {
  name = "${local.name}-ec2-ssm"

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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.gpu.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gpu" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.gpu.name
}

# NVIDIA L4 instance

resource "aws_instance" "gpu" {
  ami           = "ami-07ab2d4b1490816c3"
  instance_type = "g6.xlarge"

  subnet_id                   = aws_subnet.gpu.id
  vpc_security_group_ids      = [aws_security_group.gpu.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.gpu.name

  instance_initiated_shutdown_behavior = "stop"
  monitoring                           = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 120
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name}-gpu"
    Role = "inference-baseline"
  }

  depends_on = [
    aws_route_table_association.gpu,
    aws_route.internet,
    aws_iam_role_policy_attachment.ssm
  ]
}
