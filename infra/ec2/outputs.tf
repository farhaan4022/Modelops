output "gpu_instance_id" {
  description = "EC2 GPU instance ID"
  value       = aws_instance.gpu.id
}

output "ssm_connection" {
  description = "Connect to the GPU host using Session Manager"
  value       = "aws ssm start-session --profile modelops --region us-east-1 --target ${aws_instance.gpu.id}"
}
