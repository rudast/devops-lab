# ШАГ 5. Открываем HTTP и ставим nginx при создании ВМ (cloud-init).
#   cp ../steps/05-http.tf ../steps/cloud-init.yaml.tftpl .
#
# Затем ВРУЧНУЮ добавьте в ресурс sbercloud_compute_instance.vm (файл 04-vm.tf) строку:
#   user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", { prefix = var.prefix })
#
# terraform plan покажет: правило — "+ create", ВМ — "~ update in-place" (поменяется user_data).
# ЛОВУШКА: cloud-init выполняется только при ПЕРВОМ запуске ВМ. Машина уже запущена — nginx не появится.
# Поэтому ВМ пересоздаём явно:
#   terraform apply -replace=sbercloud_compute_instance.vm

resource "sbercloud_networking_secgroup_rule" "http" {
  security_group_id = sbercloud_networking_secgroup.vm.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

output "url" {
  value = "http://${sbercloud_vpc_eip.ip.address}/"
}
