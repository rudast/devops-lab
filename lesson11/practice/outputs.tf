output "zone" {
  description = "Зона, которую выбрал хэш имени"
  value       = local.zone
}

output "public_ip" {
  value = sbercloud_vpc_eip.ip.address
}

output "url" {
  value = "http://${sbercloud_vpc_eip.ip.address}/"
}

output "health_url" {
  value = "http://${sbercloud_vpc_eip.ip.address}/health"
}

output "ssh_command" {
  value = "ssh root@${sbercloud_vpc_eip.ip.address}"
}

# Как следить за запуском приложения на ВМ
output "logs_command" {
  value = "ssh root@${sbercloud_vpc_eip.ip.address} tail -f /var/log/start-app.log"
}

# ЧАСТЬ 5: выход с паролем. Раскомментируйте и посмотрите terraform output и terraform output -raw db_password.
# Попробуйте убрать строку sensitive — что скажет Terraform?
output "db_password" {
  value     = var.db_password
  #sensitive = true
}
