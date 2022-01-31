output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = main.aws_lb.alb.dns_name
}