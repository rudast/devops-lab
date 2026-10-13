# ШАГ 1. Data sources — ЧИТАЕМ то, что уже есть в облаке. Ничего не создаём.
#   cp ../steps/01-data.tf .  &&  terraform plan  &&  terraform apply
# Ожидаемо: "0 to add, 0 to change, 0 to destroy" и значения outputs.

# Зоны доступности региона
data "sbercloud_availability_zones" "zones" {}

# Типы ВМ в КАЖДОЙ зоне: в одной зоне нужный тип может закончиться, тогда apply упадёт.
# for_each — по одной копии data-источника на зону.
data "sbercloud_compute_flavors" "by_zone" {
  for_each          = toset(data.sbercloud_availability_zones.zones.names)
  availability_zone = each.key
  cpu_core_count    = var.vm_cpu
  memory_size       = var.vm_ram
}

locals {
  # Зоны, где наш тип ВМ сейчас есть
  zones_with_flavor = sort([for z, f in data.sbercloud_compute_flavors.by_zone : z if contains(f.ids, var.vm_flavor)])

  # «Случайная», но стабильная зона — по хэшу префикса: у разных людей разные зоны,
  # у одного человека всегда одна и та же (иначе ВМ пересоздавалась бы при каждом plan).
  zone_index = parseint(substr(md5(var.prefix), 0, 6), 16)
  zone       = length(local.zones_with_flavor) > 0 ? local.zones_with_flavor[local.zone_index % length(local.zones_with_flavor)] : null
}

# Свежий публичный образ Ubuntu
data "sbercloud_images_image" "ubuntu" {
  name_regex  = var.image_name_regex
  visibility  = "public"
  most_recent = true
}

# Общая подсеть курса — её создал преподаватель (lesson10/shared). Ищем по имени
data "sbercloud_vpc_subnet" "course" {
  name = var.subnet_name
}

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

# Минимальный размер системного диска для этого образа
output "disk_min_gb" {
  value = data.sbercloud_images_image.ubuntu.min_disk_gb
}

output "flavor" {
  value = var.vm_flavor
}

output "subnet" {
  value = "${data.sbercloud_vpc_subnet.course.name} ${data.sbercloud_vpc_subnet.course.cidr}"
}
