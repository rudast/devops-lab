output "zone" {
  description = "Зона, которую выбрал хэш имени"
  value       = local.zone
}

# Часть 6. Когда публичного IP нет (count = 0), выходы отдают null, а не падают.
# one(...) — «ноль или один элемент»: вернёт элемент или null.
locals {
  eip = one(sbercloud_vpc_eip.ip[*].address)
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

# Из занятия 11: sensitive-выход
output "db_password" {
  value     = var.db_password
  sensitive = true
}
