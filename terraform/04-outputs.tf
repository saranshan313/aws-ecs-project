output "ecs_lb_dns_name" {
  description = "DNS Name of the ECS Load Balancer"
  value       = try(aws_lb.ecs_alb.dns_name, null)
}