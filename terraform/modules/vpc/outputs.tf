# terraform/modules/vpc/outputs.tf
output "vpc_id"                { value = aws_vpc.main.id }
output "public_subnet_ids"     { value = aws_subnet.public[*].id }
output "private_subnet_ids"    { value = aws_subnet.private[*].id }
output "database_subnet_ids"   { value = aws_subnet.database[*].id }
output "internet_gateway_id"   { value = aws_internet_gateway.main.id }