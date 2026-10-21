resource "aws_ecr_repository" "modelops_llm_api" {
  name                 = "modelops-llm-api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name      = "ModelOps-LLM-API"
    Project   = "ModelOps"
    ManagedBy = "Terraform"
    Component = "FastAPI"
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "llm_api_ecr_repository_url" {
  description = "Terraform-managed ECR repository URL for the ModelOps FastAPI image."
  value       = aws_ecr_repository.modelops_llm_api.repository_url
}
