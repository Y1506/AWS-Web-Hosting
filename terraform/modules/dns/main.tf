# terraform/modules/dns/main.tf

# ── DNS RECORD: www.myapp.com → ALB ─────────────────────────────
resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Root apex: myapp.com → ALB
resource "aws_route53_record" "apex" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Health check disabled for free tier ($0.50/month)
# Uncomment for production DNS failover:
# resource "aws_route53_health_check" "main" {
#   fqdn              = "www.${var.domain_name}"
#   port              = 443
#   type              = "HTTPS"
#   resource_path     = "/health"
#   failure_threshold = 3
#   request_interval  = 30
#   tags = { Name = "${var.project_name}-health-check" }
# }