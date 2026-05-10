variable "project_name" { type = string }
variable "environment" { type = string }
variable "domain_name" { type = string }
variable "alb_listener_arn" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }