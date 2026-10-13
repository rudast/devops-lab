# Занятие 11. Работаем В ПАРЕ: одна ВМ на команду (квота проекта — 30 vCPU на всю группу, запас нужен).
# На ВМ — стек занятия 9: на ней стек занятия 9
# (nginx → backend → PostgreSQL + Redis), который поднимает cloud-init при первом запуске.
# Порядок работы — в README, части 1–7.

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
    lesson = "11"
  }
}

# ---------- Группа безопасности: SSH (22) и HTTP (80) ----------
resource "sbercloud_networking_secgroup" "app" {
  name        = "${var.prefix}-app-sg"
  description = "Lesson 11: ${var.prefix}"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  security_group_id = sbercloud_networking_secgroup.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr
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
resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-l11-key"
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
  #
  # ЧАСТЬ 2. Откройте cloud-init.yaml.tftpl и найдите все подстановки ${…}.
  # Каждой нужно значение в карте ниже. Три уже есть — допишите две, вместо TODO:
  #   db_password   — пароль базы (переменная);
  #   backend_count — число копий бэкенда (переменная).
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name          = local.name
    repo_url      = var.repo_url
    registry      = var.registry
    db_password   = var.db_password
    backend_count = var.backend_count
  })

  system_disk_type = "SAS"
  system_disk_size = data.sbercloud_images_image.ubuntu.min_disk_gb # минимум образа — квота на диски общая

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
resource "sbercloud_vpc_eip" "ip" {
  name = "${var.prefix}-l11-eip"

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.prefix}-l11-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }
}

resource "sbercloud_compute_eip_associate" "ip_to_vm" {
  public_ip   = sbercloud_vpc_eip.ip.address
  instance_id = sbercloud_compute_instance.app.id
}
