output "zone" {
  description = "Зона, которую выбрал хэш имени"
  value       = local.zone
}

# ЧАСТЬ 6. Когда появится count, адрес будет sbercloud_vpc_eip.ip[0].address — а при count = 0 его нет.
# Замените local.eip на one(sbercloud_vpc_eip.ip[*].address): «ноль или один элемент» → адрес или null.
locals {
  eip = sbercloud_vpc_eip.ip.address
}

output "private_ip" {
  value = sbercloud_compute_instance.app.access_ip_v4
}

output "public_ip" {
  value = local.eip
}

output "url" {
  value = local.eip == null ? null : "http://${local.eip}/"
}

output "health_url" {
  value = local.eip == null ? null : "http://${local.eip}/health"
}

output "ssh_command" {
  value = local.eip == null ? null : "ssh root@${local.eip}"
}

# Из занятия 11: output с паролем, помеченный sensitive
output "db_password" {
  value     = var.db_password
  sensitive = true
}
