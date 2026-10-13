output "zone" {
  value = local.zone

  precondition {
    condition     = local.zone != null
    error_message = "Типа ВМ ${var.vm_flavor} сейчас нет ни в одной зоне региона. Доступные типы ${var.vm_cpu} vCPU / ${var.vm_ram} ГБ по зонам: ${join("; ", [for z, f in data.sbercloud_compute_flavors.by_zone : "${z}: ${join(", ", f.ids)}"])}"
  }
}

output "image" {
  value = "${data.sbercloud_images_image.ubuntu.name} (${data.sbercloud_images_image.ubuntu.id})"
}

output "flavor" {
  value = var.vm_flavor
}

output "subnet" {
  value = "${data.sbercloud_vpc_subnet.course.name} ${data.sbercloud_vpc_subnet.course.cidr}"
}

# Отпечаток ключа — сравните с локальным: ssh-keygen -lf ~/.ssh/id_ed25519.pub
output "key_fingerprint" {
  value = sbercloud_kps_keypair.key.fingerprint
}

output "private_ip" {
  value = sbercloud_compute_instance.vm.access_ip_v4
}

output "public_ip" {
  value = sbercloud_vpc_eip.ip.address
}

output "url" {
  value = "http://${sbercloud_vpc_eip.ip.address}/"
}

output "ssh_command" {
  value = "ssh root@${sbercloud_vpc_eip.ip.address}"
}
