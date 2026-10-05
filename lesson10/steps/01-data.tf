# ШАГ 1. Data sources — ЧИТАЕМ то, что уже есть в облаке. Ничего не создаём.
#   cp ../steps/01-data.tf .  &&  terraform plan  &&  terraform apply
# Ожидаемо: "0 to add, 0 to change, 0 to destroy" и значения outputs.

# Зоны доступности региона
data "sbercloud_availability_zones" "zones" {}

# Свежий публичный образ Ubuntu
data "sbercloud_images_image" "ubuntu" {
  name_regex  = var.image_name_regex
  visibility  = "public"
  most_recent = true
}

# Тип ВМ (flavor) с нужным числом vCPU и памяти
data "sbercloud_compute_flavors" "vm" {
  availability_zone = data.sbercloud_availability_zones.zones.names[0]
  performance_type  = "normal"
  generation        = var.vm_generation
  cpu_core_count    = var.vm_cpu
  memory_size       = var.vm_ram
}

# Общая подсеть курса — её создал преподаватель (lesson10/shared). Ищем по имени
data "sbercloud_vpc_subnet" "course" {
  name = var.subnet_name
}

output "zone" {
  value = data.sbercloud_availability_zones.zones.names[0]
}

output "image" {
  value = "${data.sbercloud_images_image.ubuntu.name} (${data.sbercloud_images_image.ubuntu.id})"
}

# Минимальный размер системного диска для этого образа
output "disk_min_gb" {
  value = data.sbercloud_images_image.ubuntu.min_disk_gb
}

output "flavor" {
  value = data.sbercloud_compute_flavors.vm.ids[0]
}

output "subnet" {
  value = "${data.sbercloud_vpc_subnet.course.name} ${data.sbercloud_vpc_subnet.course.cidr}"
}
