# Карта «сервер => публичный IP». for-выражение собирает её из всех копий модуля.
output "public_ips" {
  value = { for k, vm in module.web : k => vm.public_ip }
}

# Если в части 2 вы добавили в модуль выход url, можно короче: [for vm in module.web : vm.url]
output "urls" {
  value = [for vm in module.web : "http://${vm.public_ip}/"]
}

# for с фильтром if: только серверы с большим диском
output "big_disks" {
  value = [for name, s in var.servers : name if s.disk_size > 10]
}

output "servers_count" {
  value = length(module.web)
}

output "ssh_commands" {
  value = { for k, vm in module.web : k => "ssh root@${vm.public_ip}" }
}
