# Часть 4. module.web — карта копий модуля, поэтому выходы собираем for-выражениями.

# Карта «сервер => публичный IP»
output "public_ips" {
  value = { for k, vm in module.web : k => vm.public_ip }
}

# Карта «сервер => зона, которую выбрал модуль»
output "zones" {
  value = { for k, vm in module.web : k => vm.zone }
}

# Список адресов страниц — из выхода url модуля
output "urls" {
  value = [for vm in module.web : vm.url]
}

output "servers_count" {
  value = length(module.web)
}

output "ssh_commands" {
  value = { for k, vm in module.web : k => "ssh root@${vm.public_ip}" }
}
