variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "node_security_group_ids" {
  type = list(string)
}

variable "autoscaling_group_name" {
  type = string
}
