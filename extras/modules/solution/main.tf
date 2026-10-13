# Занятие 12 — ГОТОВОЕ РЕШЕНИЕ: так выглядит practice после частей 1–6.
# Работаем В ПАРЕ: одна ВМ на команду (квота проекта — 15 ВМ на всю группу).

# ---------- Общее: читаем облако ----------
data "sbercloud_vpc_subnet" "course" {
  name = var.subnet_name
}

locals {
  tags = {
    course = "hse-devops"
    owner  = var.prefix
    lesson = "12"
  }
}

# ---------- Часть 6: firewall — свой модуль (папка ./firewall) ----------
module "firewall" {
  source = "./firewall"

  name = "${var.prefix}-web-sg"
  ports = {
    "22" = var.allowed_ssh_cidr
    "80" = "0.0.0.0/0"
  }
}

resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-l12-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path))) # trimspace — убрать перевод строки в конце файла
}

# ---------- Серверы: один модуль, столько копий, сколько строк в var.servers (у нас — одна) ----------
# Образ, тип ВМ, диск и зону модуль выбирает сам — см. ../modules/vm/main.tf
module "web" {
  source   = "../modules/vm"
  for_each = var.servers

  name               = "${var.prefix}-${each.key}"
  subnet_id          = data.sbercloud_vpc_subnet.course.id
  security_group_ids = [module.firewall.id] # выход одного модуля — вход другого
  key_pair           = sbercloud_kps_keypair.key.name
  disk_size          = each.value.disk_size # null — минимум образа
  tags               = local.tags

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name = "${var.prefix}-${each.key}"
  })
}

# ---------- Переезды без пересоздания ----------
# Часть 3: один вызов модуля → карта вызовов
moved {
  from = module.web
  to   = module.web["web-1"]
}

# Часть 6 (бонус): группа безопасности и правила переехали в модуль firewall
moved {
  from = sbercloud_networking_secgroup.web
  to   = module.firewall.sbercloud_networking_secgroup.this
}

moved {
  from = sbercloud_networking_secgroup_rule.ssh
  to   = module.firewall.sbercloud_networking_secgroup_rule.this["22"]
}

moved {
  from = sbercloud_networking_secgroup_rule.http
  to   = module.firewall.sbercloud_networking_secgroup_rule.this["80"]
}
