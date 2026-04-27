output "frontend_url" {
  value = "http://${aws_lb.main.dns_name}"
}
