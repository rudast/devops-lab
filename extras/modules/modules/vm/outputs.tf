# Выходы модуля: что вызывающий код может прочитать как module.<имя>.<выход>

output "id" {
  value = sbercloud_compute_instance.this.id
}

output "name" {
  value = sbercloud_compute_instance.this.name
}

# Что модуль выбрал сам: зона, тип, диск
output "zone" {
  value = sbercloud_compute_instance.this.availability_zone
}

output "flavor" {
  value = sbercloud_compute_instance.this.flavor_id
}

output "disk_size" {
  value = sbercloud_compute_instance.this.system_disk_size
}

output "private_ip" {
  value = sbercloud_compute_instance.this.access_ip_v4
}

# null, если public_ip = false
output "public_ip" {
  value = var.public_ip ? sbercloud_vpc_eip.this[0].address : null
}

output "url" {
  value = var.public_ip ? "http://${sbercloud_vpc_eip.this[0].address}/" : null
}
