# Модуль «одна ВМ»: машина + (по желанию) публичный IP.
# Код тот же, что в занятии 10, но модуль сам подбирает всё, что упирается в общие квоты курса:
#   тип ВМ  — минимальный (var.flavor, проверка в variables.tf);
#   диск    — минимум образа (если disk_size не задан);
#   зону    — «случайную», но стабильную, и только ту, где этот тип ВМ сейчас есть.

# ---------- Что есть в облаке ----------
data "sbercloud_availability_zones" "all" {}

# Свежий публичный образ Ubuntu: нужен его id и минимальный размер диска
data "sbercloud_images_image" "this" {
  name_regex  = var.image_name_regex
  visibility  = "public"
  most_recent = true
}

# Список типов ВМ в КАЖДОЙ зоне: for_each по зонам — одна копия data-источника на зону
data "sbercloud_compute_flavors" "zone" {
  for_each          = toset(data.sbercloud_availability_zones.all.names)
  availability_zone = each.key
}

locals {
  # Зоны, где наш тип ВМ есть (в «распроданной» зоне apply упал бы с ошибкой)
  zones = sort([for z, f in data.sbercloud_compute_flavors.zone : z if contains(f.ids, var.flavor)])

  # «Случайная», но СТАБИЛЬНАЯ зона: число из хэша имени ВМ → номер зоны.
  # Одно и то же имя → всегда одна и та же зона; разные команды → разные зоны.
  # (random_shuffle тоже подошёл бы, но это ещё один провайдер с зеркала.)
  hash      = parseint(substr(md5(var.name), 0, 6), 16)
  auto_zone = length(local.zones) > 0 ? local.zones[local.hash % length(local.zones)] : null
  zone      = var.availability_zone != null ? var.availability_zone : local.auto_zone

  image_id = var.image_id != null ? var.image_id : data.sbercloud_images_image.this.id
  disk     = max(coalesce(var.disk_size, 0), data.sbercloud_images_image.this.min_disk_gb) # не меньше минимума образа
}

# ---------- ВМ ----------
resource "sbercloud_compute_instance" "this" {
  name               = var.name
  image_id           = local.image_id
  flavor_id          = var.flavor
  availability_zone  = local.zone
  security_group_ids = var.security_group_ids
  key_pair           = var.key_pair
  user_data          = var.user_data

  system_disk_type = "SAS"
  system_disk_size = local.disk

  network {
    uuid = var.subnet_id
  }

  tags = var.tags

  lifecycle {
    # Список зон или свежий образ могут поменяться (зону «распродали», вышел новый образ).
    # Из-за этого ВМ НЕ должна пересоздаваться: смена зоны или образа = удалить и создать заново.
    ignore_changes = [availability_zone, image_id]

    precondition {
      condition     = local.zone != null
      error_message = "Тип ВМ ${var.flavor} сейчас недоступен ни в одной зоне. Сообщите преподавателю."
    }
  }
}

# ---------- Публичный IP: count = 1 или 0 — так в Terraform делают «ресурс по условию» ----------
resource "sbercloud_vpc_eip" "this" {
  count = var.public_ip ? 1 : 0

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.name}-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }
}

resource "sbercloud_compute_eip_associate" "this" {
  count = var.public_ip ? 1 : 0

  public_ip   = sbercloud_vpc_eip.this[0].address
  instance_id = sbercloud_compute_instance.this.id
}
