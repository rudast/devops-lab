# Занятие 12. Работаем В ПАРЕ: одна ВМ на команду. Инфраструктура та же, что на занятии 11.
# Порядок работы — в README, части 1–7. Код специально слегка «помят» — часть 1 начинается с terraform fmt.

# ---------- Data sources: читаем облако ----------
data "sbercloud_availability_zones" "all" {}

data "sbercloud_images_image" "ubuntu" {
  name_regex  = var.image_name_regex
  visibility  = "public"
  most_recent = true
}

# Типы ВМ в КАЖДОЙ зоне: for_each по зонам — одна копия data-источника на зону
data "sbercloud_compute_flavors" "zone" {
  for_each          = toset(data.sbercloud_availability_zones.all.names)
  availability_zone = each.key
}

data "sbercloud_vpc_subnet" "course" {
  name = var.subnet_name
}

locals {
  name = "${var.prefix}-app"

  # Зоны, где наш тип ВМ сейчас есть (в «распроданной» зоне apply упал бы)
  zones = sort([for z, f in data.sbercloud_compute_flavors.zone : z if contains(f.ids, var.vm_flavor)])

  # «Случайная», но стабильная зона: число из хэша имени ВМ → номер зоны.
  # Одно и то же имя → всегда одна зона; разные команды → разные зоны.
  hash = parseint(substr(md5(local.name), 0, 6), 16)
  zone = length(local.zones) > 0 ? local.zones[local.hash % length(local.zones)] : null

  tags = {
    course = "hse-devops"
    owner  = var.prefix
    lesson = "12"
  }
}

# ---------- Группа безопасности: SSH (22) и HTTP (80) ----------
resource "sbercloud_networking_secgroup" "app" {
  name = "${var.prefix}-app-sg"
  description =   "Lesson 12: ${var.prefix}"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  security_group_id = sbercloud_networking_secgroup.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr

  # ЧАСТЬ 5. Сюда — lifecycle { create_before_destroy = true } (см. README).
}

resource "sbercloud_networking_secgroup_rule" "http" {
  security_group_id = sbercloud_networking_secgroup.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

# ---------- SSH-ключ ----------
# ЧАСТЬ 2. Переименуйте ресурс: "key" → "ssh" (здесь и в key_pair ниже). Потом — см. README.
resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-l12-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# ---------- ВМ с приложением ----------
resource "sbercloud_compute_instance" "app" {
  name               = local.name
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = var.vm_flavor
  availability_zone  = local.zone
  security_group_ids = [sbercloud_networking_secgroup.app.id]
  key_pair           = sbercloud_kps_keypair.key.name

  # cloud-init: Docker → код курса → .env с паролем → docker compose up. Только при ПЕРВОМ запуске ВМ.
  # Поменяли что-то внутри user_data → нужна новая ВМ: terraform apply -replace=sbercloud_compute_instance.app
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name          = local.name
    repo_url      = var.repo_url
    registry      = var.registry
    db_password   = var.db_password
    backend_count = var.backend_count
  })

  system_disk_type="SAS"
  system_disk_size = data.sbercloud_images_image.ubuntu.min_disk_gb   # минимум образа — квота на диски общая

  network {
    uuid = data.sbercloud_vpc_subnet.course.id
  }

  tags = local.tags

  lifecycle {
    # Список зон и «свежий» образ со временем меняются. ВМ из-за этого пересоздаваться не должна.
    ignore_changes = [availability_zone, image_id]

    precondition {
      condition     = local.zone != null
      error_message = "Тип ВМ ${var.vm_flavor} сейчас недоступен ни в одной зоне. Сообщите преподавателю."
    }
  }
}

# ---------- Публичный IP — отдельный ресурс: переживёт пересоздание ВМ ----------
# ЧАСТЬ 6. Выключатель: добавьте  count = var.public_ip ? 1 : 0  сюда и в привязку ниже,
# а ссылку на адрес замените на sbercloud_vpc_eip.ip[0].address (см. README).
resource "sbercloud_vpc_eip" "ip" {
  name = "${var.prefix}-l12-eip"

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.prefix}-l12-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }

  # ЧАСТЬ 5. Сюда — lifecycle { prevent_destroy = true } (см. README).
}

resource "sbercloud_compute_eip_associate" "ip_to_vm" {
  public_ip   = sbercloud_vpc_eip.ip.address
  instance_id = sbercloud_compute_instance.app.id
}

# ЧАСТЬ 2, вариант «в коде»: тот же переезд, что state mv, но через Git и ревью. После apply блок удаляют.
# moved {
#   from = sbercloud_kps_keypair.key
#   to   = sbercloud_kps_keypair.ssh
# }

# ЧАСТЬ 4. «Потерянный» ресурс: после terraform state rm ключ возвращают в state блоком import
# (нужен один раз, потом блок удаляют). ID ключа в cloud.ru — его имя. Раскомментируйте и поправьте адрес.
# import {
#   to = sbercloud_kps_keypair.ssh
#   id = "${var.prefix}-l12-key"
# }
