output "app_url" {
  description = "The live URL of the deployed app"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}
