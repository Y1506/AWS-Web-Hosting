# terraform/modules/load_balancer/main.tf
# HTTP-only ALB for demo (ACM DNS validation requires real domain ownership)

# ── APPLICATION LOAD BALANCER ────────────────────────────────────
# FREE TIER: 750 hours/month + 15 LCUs for 12 months (new accounts only)
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false           # internet-facing
  load_balancer_type = "application"   # Layer 7
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids  # One node per AZ = HA

  enable_deletion_protection = false   # Demo — allow easy teardown
  enable_http2               = true    # HTTP/2 for better performance

  tags = { Name = "${var.project_name}-alb" }
}

# ── TARGET GROUP ─────────────────────────────────────────────────
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80         # Nginx listens on 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health check — ALB only sends traffic to healthy targets
  health_check {
    enabled             = true
    path                = "/health"     # Nginx returns 200 here
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30            # Check every 30s
    timeout             = 5             # Must respond in 5s
    healthy_threshold   = 2             # 2 consecutive successes = healthy
    unhealthy_threshold = 3             # 3 consecutive failures = removed
  }

  deregistration_delay = 30

  tags = { Name = "${var.project_name}-tg" }
}

# ── REGISTER EC2 INSTANCES IN TARGET GROUP ───────────────────────
resource "aws_lb_target_group_attachment" "webservers" {
  count            = length(var.webserver_instance_ids)
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = var.webserver_instance_ids[count.index]
  port             = 80
}

# ── HTTP LISTENER (port 80) ──────────────────────────────────────
# For production: add ACM cert + HTTPS listener with HTTP→HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ── ROUTING RULES ────────────────────────────────────────────────
# Route /api/* to the target group (extensible for separate API TG later)
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}