output "cluster_name" {
  value = aws_eks_cluster.gpu.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.gpu.endpoint
}

output "node_group_name" {
  value = aws_eks_node_group.gpu.node_group_name
}

output "gpu_node_role_arn" {
  value = aws_iam_role.node.arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --profile modelops --region ${var.aws_region} --name ${aws_eks_cluster.gpu.name}"
}
