# ---------- Данные (data sources): читаем, а не создаём ----------
data "sbercloud_availability_zones" "zones" {}

data "sbercloud_images_image" "ubuntu" {
  name        = var.image_name
  visibility  = "public"
  most_recent = true
}

data "sbercloud_compute_flavors" "small" {
  availability_zone = data.sbercloud_availability_zones.zones.names[0]
  performance_type  = "normal"
  cpu_core_count    = 2
  memory_size       = 4
}

# ---------- Сеть ----------
resource "sbercloud_vpc" "vpc" {
  name = "${var.prefix}-vpc"
  cidr = "192.168.0.0/16"
}

resource "sbercloud_vpc_subnet" "subnet" {
  name              = "${var.prefix}-subnet"
  cidr              = "192.168.10.0/24"
  gateway_ip        = "192.168.10.1"
  vpc_id            = sbercloud_vpc.vpc.id
  availability_zone = data.sbercloud_availability_zones.zones.names[0]
}

# ---------- Firewall (security group) ----------
resource "sbercloud_networking_secgroup" "web" {
  name        = "${var.prefix}-sg"
  description = "SSH + HTTP + HTTPS"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  security_group_id = sbercloud_networking_secgroup.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr
}

resource "sbercloud_networking_secgroup_rule" "http" {
  security_group_id = sbercloud_networking_secgroup.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "sbercloud_networking_secgroup_rule" "https" {
  security_group_id = sbercloud_networking_secgroup.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

# ---------- SSH-ключ ----------
resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---------- Виртуальная машина ----------
resource "sbercloud_compute_instance" "vm" {
  name               = "${var.prefix}-vm"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = data.sbercloud_compute_flavors.small.ids[0]
  availability_zone  = data.sbercloud_availability_zones.zones.names[0]
  security_group_ids = [sbercloud_networking_secgroup.web.id]
  key_pair           = sbercloud_kps_keypair.key.name

  system_disk_type = "SAS"
  system_disk_size = 20

  network {
    uuid = sbercloud_vpc_subnet.subnet.id
  }
}

# ---------- Публичный IP ----------
resource "sbercloud_vpc_eip" "ip" {
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

# ---------- Мост к Ansible: генерируем inventory ----------
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOT
    [web]
    ${sbercloud_vpc_eip.ip.address} ansible_user=root
  EOT
}
