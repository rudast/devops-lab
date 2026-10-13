# ЧАСТЬ 1: один сервер — смотрим, что модуль выбрал сам.
# В ЧАСТИ 3 (for_each) закомментируйте эти выходы: module.web станет картой серверов.
output "zone" {
  value = module.web.zone
}

output "flavor" {
  value = module.web.flavor
}

output "disk_size" {
  value = module.web.disk_size
}

output "url" {
  value = module.web.url
}

# ЧАСТЬ 4: выходы для карты серверов. Раскомментируйте и замените TODO на for-выражения.
# module.web — карта: { "web-1" = <выходы модуля> }
#
# output "public_ips" {
#   value = TODO # карта «имя → публичный IP»:  { "web-1" = "1.2.3.4" }
# }
#
# output "zones" {
#   value = TODO # карта «имя → зона», которую выбрал модуль
# }
#
# output "urls" {
#   value = TODO # список адресов страниц — из выхода url модуля
# }
#
# output "servers_count" {
#   value = TODO # сколько серверов (функция length)
# }
