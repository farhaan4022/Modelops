variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "modelops-gpu"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "admin_cidr" {
  type        = string
  description = "Your current public IPv4 address as a /32 CIDR."

  validation {
    condition = (
      can(cidrhost(var.admin_cidr, 0)) &&
      endswith(var.admin_cidr, "/32")
    )
    error_message = "Provide your public IPv4 as x.x.x.x/32."
  }
}
