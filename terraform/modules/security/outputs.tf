output "alb_sg_id" { value = aws_security_group.alb.id }
output "webserver_sg_id" { value = aws_security_group.webserver.id }
output "bastion_sg_id" { value = aws_security_group.bastion.id }