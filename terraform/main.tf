# terraform/main.tf
# Ties all modules together

# ── Route 53 Hosted Zone (created for demo) ──────────────────────
# $0.50/month — destroy after demo to stop billing
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# ── VPC ──────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

# ── Security Groups & NACLs ──────────────────────────────────────
module "security" {
  source = "./modules/security"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_ssh_cidr   = var.allowed_ssh_cidr
}

# ── EC2 Instances (Web Servers + Bastion) ────────────────────────
module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  instance_type      = var.instance_type
  instance_count     = length(var.availability_zones)
  availability_zones = var.availability_zones
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  webserver_sg_id    = module.security.webserver_sg_id
  bastion_sg_id      = module.security.bastion_sg_id
  public_key_path    = var.public_key_path
}

# ── Application Load Balancer (HTTP-only for demo) ───────────────
module "load_balancer" {
  source = "./modules/load_balancer"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_sg_id              = module.security.alb_sg_id
  webserver_instance_ids = module.compute.webserver_instance_ids
}

# ── DNS Records ──────────────────────────────────────────────────
module "dns" {
  source = "./modules/dns"

  project_name    = var.project_name
  route53_zone_id = aws_route53_zone.main.zone_id
  domain_name     = var.domain_name
  alb_dns_name    = module.load_balancer.alb_dns_name
  alb_zone_id     = module.load_balancer.alb_zone_id

  depends_on = [module.load_balancer]
}

# ── API Gateway ──────────────────────────────────────────────────
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name      = var.project_name
  environment       = var.environment
  domain_name       = var.domain_name
  alb_listener_arn  = module.load_balancer.http_listener_arn
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}