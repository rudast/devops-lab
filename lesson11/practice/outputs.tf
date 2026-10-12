# ЧАСТЬ 1: один сервер — один IP.
# В ЧАСТИ 3 (for_each) закомментируйте эти два выхода: module.web станет картой серверов.
output "public_ip" {
  value = module.web.public_ip
}

output "url" {
  value = "http://${module.web.public_ip}/" # ЧАСТЬ 2: замените на module.web.url
}

# ЧАСТЬ 4: выходы для нескольких серверов. Раскомментируйте и замените TODO на for-выражения.
# module.web — карта: { "web-1" = <выходы модуля>, "web-2" = <выходы модуля> }
#
# output "public_ips" {
#   value = TODO # карта «имя → публичный IP»:  { "web-1" = "1.2.3.4", … }
# }
#
# output "urls" {
#   value = TODO # список адресов страниц — из выхода url модуля
# }
#
# output "big_disks" {
#   value = TODO # имена серверов из var.servers, у которых disk_size > 10 (for … if …)
# }
#
# output "servers_count" {
#   value = TODO # сколько серверов (функция length)
# }
