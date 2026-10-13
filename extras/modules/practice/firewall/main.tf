# ЧАСТЬ 6. Модуль firewall: группа безопасности + по правилу на каждый порт.
# Образец — ресурсы sbercloud_networking_secgroup* в ../main.tf.
#
# 1. Ресурс sbercloud_networking_secgroup с именем "this", name = var.name.
# 2. Ресурс sbercloud_networking_secgroup_rule с именем "this" и for_each = var.ports:
#      порт        — each.key   (строка! в число: tonumber(each.key))
#      откуда      — each.value
#      direction = "ingress", ethertype = "IPv4", protocol = "tcp"
#
# Раскомментируйте и замените TODO:

# resource "sbercloud_networking_secgroup" "this" {
#   name = TODO
# }
#
# resource "sbercloud_networking_secgroup_rule" "this" {
#   for_each = TODO
#
#   security_group_id = sbercloud_networking_secgroup.this.id
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   protocol          = "tcp"
#   port_range_min    = TODO
#   port_range_max    = TODO
#   remote_ip_prefix  = TODO
# }
