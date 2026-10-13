# Модуль firewall — ГОТОВОЕ РЕШЕНИЕ части 6.
# Группа безопасности + по правилу на каждый порт из карты var.ports.

resource "sbercloud_networking_secgroup" "this" {
  name = var.name
}

resource "sbercloud_networking_secgroup_rule" "this" {
  for_each = var.ports # ключ — порт ("22"), значение — откуда разрешён доступ

  security_group_id = sbercloud_networking_secgroup.this.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.key)
  port_range_max    = tonumber(each.key)
  remote_ip_prefix  = each.value
}
