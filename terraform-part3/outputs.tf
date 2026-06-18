output "alb_dns_endpoint" {
  value       = "http://${aws_lb.external_alb.dns_name}"
  description = "The single public entry point for your entire application stack"
}

output "frontend_ecr_url" {
  value       = aws_ecr_repository.frontend.repository_url
  description = "Target address path tag for your Express Docker image"
}

output "backend_ecr_url" {
  value       = aws_ecr_repository.backend.repository_url
  description = "Target address path tag for your Flask Docker image"
}