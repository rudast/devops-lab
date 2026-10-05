# Занятие 10 — ГОТОВОЕ РЕШЕНИЕ: так выглядит папка practice после шагов 1–5 (файлы steps/ собраны вместе).

# ---------- Data sources: читаем образ, тип ВМ и общую сеть курса ----------
data "sbercloud_availability_zones" "zones" {}

# Свежий публичный образ Ubuntu
data "sbercloud_images_image" "ubuntu" {
  name_regex  = var.image_name_regex
  visibility  = "public"
  most_recent = true
}

# Тип ВМ (flavor) с нужным числом vCPU и памяти
# (список всех типов с таким же числом vCPU и памяти в зоне — чтобы проверить, что наш тип там есть)
data "sbercloud_compute_flavors" "vm" {
  availability_zone = data.sbercloud_availability_zones.zones.names[0]
  cpu_core_count    = var.vm_cpu
  memory_size       = var.vm_ram
}

# Общая подсеть курса — её создал преподаватель (lesson10/shared). Ищем по имени
data "sbercloud_vpc_subnet" "course" {
  name = var.subnet_name
}

# ---------- Группа безопасности: SSH (22) и HTTP (80) ----------
resource "sbercloud_networking_secgroup" "vm" {
  name        = "${var.prefix}-sg"
  description = "Lesson 10: ${var.prefix}"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  security_group_id = sbercloud_networking_secgroup.vm.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr
}

resource "sbercloud_networking_secgroup_rule" "http" {
  security_group_id = sbercloud_networking_secgroup.vm.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

# ---------- Публичный SSH-ключ студента ----------
resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}


# ---------- ВМ, публичный IP и их связка ----------
resource "sbercloud_compute_instance" "vm" {
  name               = "${var.prefix}-vm"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = var.vm_flavor
  availability_zone  = data.sbercloud_availability_zones.zones.names[0]
  security_group_ids = [sbercloud_networking_secgroup.vm.id]
  key_pair           = sbercloud_kps_keypair.key.name

  # cloud-init: ставит nginx при ПЕРВОМ запуске. Изменение user_data = пересоздание ВМ (-/+)
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", { prefix = var.prefix })

  system_disk_type = "SAS"
  system_disk_size = max(var.vm_disk_size, data.sbercloud_images_image.ubuntu.min_disk_gb) # не меньше минимума образа

  network {
    uuid = data.sbercloud_vpc_subnet.course.id
  }

  tags = {
    course = "hse-devops"
    owner  = var.prefix
  }
}

# Публичный IP — ОТДЕЛЬНЫЙ ресурс: он переживёт пересоздание ВМ
resource "sbercloud_vpc_eip" "ip" {
  name = "${var.prefix}-eip"

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.prefix}-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }
}

resource "sbercloud_compute_eip_associate" "ip_to_vm" {
  public_ip   = sbercloud_vpc_eip.ip.address
  instance_id = sbercloud_compute_instance.vm.id
}
