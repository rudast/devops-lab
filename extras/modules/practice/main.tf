# Занятие 12. Работаем В ПАРЕ: одна ВМ на команду (квота проекта — 15 ВМ на всю группу).
# prefix в terraform.tfvars — две фамилии: ivanov-petrov.

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

# ---------- Firewall и ключ: создаём один раз ----------
# ЧАСТЬ 6: эти три ресурса переедут в ваш модуль ./firewall
resource "sbercloud_networking_secgroup" "web" {
  name = "${var.prefix}-web-sg"
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

resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-l12-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path))) # trimspace — убрать перевод строки в конце файла
}

# ---------- Сервер через модуль ----------
# ЧАСТЬ 1. Вызовите модуль vm и создайте ОДИН сервер.
# Какие входы есть у модуля — смотрите ../modules/vm/variables.tf.
# Образ, тип ВМ, диск и зону передавать НЕ нужно — модуль выберет их сам.
# Замените три TODO:
#   source    — путь к папке модуля (относительно этой папки);
#   subnet_id — ID общей подсети (она уже прочитана data-источником выше);
#   key_pair  — ИМЯ ключа, созданного ресурсом выше.

module "web" {
  source = "TODO"

  name               = "${var.prefix}-web-1"
  subnet_id          = TODO
  security_group_ids = [sbercloud_networking_secgroup.web.id]
  key_pair           = TODO
  tags               = local.tags

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name = "${var.prefix}-web-1"
  })
}

# ЧАСТЬ 2 — ломаем входы модуля: flavor = "s7n.large.4", disk_size = 50 (см. README).
# ЧАСТЬ 3 — for_each по var.servers, понадобится и блок moved:
# moved {
#   from = module.web
#   to   = module.web["web-1"]
# }

# ЧАСТЬ 6 (бонус) — переезд firewall в модуль без пересоздания:
# moved {
#   from = sbercloud_networking_secgroup.web
#   to   = module.firewall.sbercloud_networking_secgroup.this
# }
# …и ещё два блока moved — для правил ssh и http. Допишите сами.
# Адрес правила внутри модуля: module.firewall.sbercloud_networking_secgroup_rule.this["22"]
