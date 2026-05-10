output "webserver_instance_ids" { value = aws_instance.webserver[*].id }
output "webserver_public_ips" { value = aws_instance.webserver[*].public_ip }
output "bastion_public_ip" { value = aws_instance.bastion.public_ip }