# terraform/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "webserver_ips" {
  description = "Public IPs of all web servers (access the app here)"
  value       = module.compute.webserver_public_ips
}

output "bastion_ip" {
  description = "Bastion host public IP (SSH via PuTTY here)"
  value       = module.compute.bastion_public_ip
}

output "alb_dns_name" {
  description = "ALB DNS name (access the app via load balancer)"
  value       = module.load_balancer.alb_dns_name
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.invoke_url
}

output "nameservers" {
  description = "Route 53 name servers"
  value       = aws_route53_zone.main.name_servers
}

output "ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${module.compute.bastion_public_ip}"
}