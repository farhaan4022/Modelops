# MODELOPS_TERRAFORM_MANAGED_FASTAPI
# Phase 8: CPU-only API gateway; existing GPU deployment is untouched.

resource "kubernetes_deployment_v1" "modelops_llm_api" {
  metadata {
    name      = "modelops-llm-api"
    namespace = "modelops"
    labels    = {
      "app" = "modelops-llm-api"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "modelops-llm-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "modelops-llm-api"
        }
      }

      spec {
        container {
          name              = "fastapi"
          image             = "743502211832.dkr.ecr.us-east-1.amazonaws.com/modelops-llm-api:guardrails-20261021T095120Z"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8000
          }

          env {
            name  = "VLLM_BASE_URL"
            value = "http://qwen-vllm.modelops.svc.cluster.local:8000"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "modelops_llm_api" {
  metadata {
    name      = "modelops-llm-api"
    namespace = "modelops"
  }

  spec {
    type = "NodePort"

    selector = {
      app = "modelops-llm-api"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      node_port = 30081
      protocol    = "TCP"
    }
  }
}
