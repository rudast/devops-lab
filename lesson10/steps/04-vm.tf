# ШАГ 4. Виртуальная машина и публичный IP.
#   cp ../steps/04-vm.tf .  &&  terraform plan  &&  terraform apply     (3–5 минут)
# Ожидаемо: "3 to add". Потом: ssh root@$(terraform output -raw public_ip)
#
# ЗАДАНИЕ: замените TODO_KEY на ссылку на ИМЯ ключа из шага 3.
# Подсказка: <тип_ресурса>.<имя>.<атрибут>, например sbercloud_networking_secgroup.vm.id

resource "sbercloud_compute_instance" "vm" {
  name               = "${var.prefix}-vm"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = var.vm_flavor
  availability_zone  = data.sbercloud_availability_zones.zones.names[0]
  security_group_ids = [sbercloud_networking_secgroup.vm.id]
  key_pair           = TODO_KEY

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

output "private_ip" {
  value = sbercloud_compute_instance.vm.access_ip_v4
}

output "public_ip" {
  value = sbercloud_vpc_eip.ip.address
}

output "ssh_command" {
  value = "ssh root@${sbercloud_vpc_eip.ip.address}"
}
