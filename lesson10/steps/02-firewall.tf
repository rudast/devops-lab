# ШАГ 2. Группа безопасности (облачный firewall) и правило для SSH.
#   cp ../steps/02-firewall.tf .  &&  terraform plan  &&  terraform apply
# Ожидаемо: "2 to add".
#
# ЗАДАНИЕ: замените TODO_PORT на номер порта SSH (в двух местах).
# Пока не замените — terraform plan покажет ошибку. Это нормально: прочитайте её.

resource "sbercloud_networking_secgroup" "vm" {
  name        = "${var.prefix}-sg"
  description = "Lesson 10: ${var.prefix}"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  security_group_id = sbercloud_networking_secgroup.vm.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = TODO_PORT
  port_range_max    = TODO_PORT
  remote_ip_prefix  = var.allowed_ssh_cidr
}
