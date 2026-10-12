# Занятия 11–12. ДЛЯ ПРЕПОДАВАТЕЛЯ: PostgreSQL для state студентов — с блокировками.
#
# Terraform-бэкенд "pg" хранит state в таблице БД и ставит блокировку (advisory lock) на время
# plan/apply. Второй человек, запустивший plan/apply в тот же state, получит
# «Error acquiring the state lock», а не испортит state. Упал ноутбук — соединение с БД рвётся,
# блокировка снимается сама.
#
# Включить (перед занятием 11):
#   export TF_VAR_state_db_password="$(openssl rand -hex 16)"   # сохраните его! повторно он нужен при каждом apply здесь
#   echo 'enable_state_db = true' >> terraform.tfvars
#   terraform apply
#   terraform output -raw state_db_conn_str                      # строку подключения — студентам в закрытый чат
#
# Студенты:  export PG_CONN_STR="<строка>"  — и в backend.tf уже ничего секретного нет.
# Резервная копия: каждый час pg_dump на самой ВМ, /var/backups/tfstate (последние 48 штук).

variable "enable_state_db" {
  description = "true — создать ВМ с PostgreSQL для state студентов (занятия 11–12)"
  type        = bool
  default     = false
}

variable "state_db_password" {
  description = "Пароль пользователя tfstate. Только через TF_VAR_state_db_password, не в файлах"
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.state_db_password == null || can(regex("^[A-Za-z0-9]{16,}$", var.state_db_password))
    error_message = "Пароль: не короче 16 символов, только латинские буквы и цифры (openssl rand -hex 16)."
  }
}

variable "state_db_allowed_cidr" {
  description = "Откуда можно подключаться к БД state. Студенты работают и из дома, поэтому по умолчанию — отовсюду (вход только по паролю и через SSL)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "teacher_ssh_public_key_path" {
  description = "Ваш публичный SSH-ключ — для входа на ВМ с БД (бэкапы, отладка)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "mirror_registry" {
  description = "Наш реестр с копиями образов Docker Hub"
  type        = string
  default     = "ghcr.io/tenroman1-design/devops-lab"
}

locals {
  state_db = var.enable_state_db ? 1 : 0
}

data "sbercloud_availability_zones" "zones" {
  count = local.state_db
}

data "sbercloud_images_image" "ubuntu" {
  count       = local.state_db
  name_regex  = "^Ubuntu 22.04 server 64bit$"
  visibility  = "public"
  most_recent = true
}

resource "sbercloud_networking_secgroup" "state_db" {
  count = local.state_db
  name  = "devops-course-state-db-sg"
}

resource "sbercloud_networking_secgroup_rule" "state_db" {
  for_each = var.enable_state_db ? { postgres = 5432, ssh = 22 } : {}

  security_group_id = sbercloud_networking_secgroup.state_db[0].id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = var.state_db_allowed_cidr
}

resource "sbercloud_kps_keypair" "teacher" {
  count      = local.state_db
  name       = "devops-course-teacher-key"
  public_key = file(pathexpand(var.teacher_ssh_public_key_path))
}

resource "sbercloud_compute_instance" "state_db" {
  count = local.state_db

  name               = "devops-course-state-db"
  image_id           = data.sbercloud_images_image.ubuntu[0].id
  flavor_id          = "s7n.medium.2"
  availability_zone  = data.sbercloud_availability_zones.zones[0].names[0]
  security_group_ids = [sbercloud_networking_secgroup.state_db[0].id]
  key_pair           = sbercloud_kps_keypair.teacher[0].name

  system_disk_type = "SAS"
  system_disk_size = 20

  user_data = templatefile("${path.module}/state-db-cloud-init.yaml.tftpl", {
    password = var.state_db_password
    registry = var.mirror_registry
  })

  network {
    uuid = sbercloud_vpc_subnet.course.id
  }

  tags = {
    course = "hse-devops"
    role   = "state-db"
  }

  # Пересоздание ВМ = потеря state ВСЕХ студентов. Поэтому новый образ Ubuntu
  # или правка cloud-init не должны пересоздавать машину.
  lifecycle {
    ignore_changes = [image_id, user_data]
    precondition {
      condition     = var.state_db_password != null
      error_message = "Задайте пароль: export TF_VAR_state_db_password=\"$(openssl rand -hex 16)\""
    }
  }
}

resource "sbercloud_vpc_eip" "state_db" {
  count = local.state_db

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "devops-course-state-db-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }
}

resource "sbercloud_compute_eip_associate" "state_db" {
  count       = local.state_db
  public_ip   = sbercloud_vpc_eip.state_db[0].address
  instance_id = sbercloud_compute_instance.state_db[0].id
}

output "state_db" {
  value = var.enable_state_db ? "PostgreSQL для state: ${sbercloud_vpc_eip.state_db[0].address}:5432, ssh root@${sbercloud_vpc_eip.state_db[0].address}" : "БД для state выключена"
}

# terraform output -raw state_db_conn_str — строка для студентов (export PG_CONN_STR="…")
output "state_db_conn_str" {
  value     = var.enable_state_db ? "postgres://tfstate:${var.state_db_password}@${sbercloud_vpc_eip.state_db[0].address}:5432/tfstate?sslmode=require" : ""
  sensitive = true
}
