# Входы модуля: всё, что модулю нужно знать снаружи.
# Подсеть, ключ и группы безопасности ему передают. Образ, тип ВМ, диск и зону он умеет выбрать сам.

variable "name" {
  description = "Имя ВМ (и префикс для её ресурсов)"
  type        = string
}

variable "subnet_id" {
  description = "ID подсети, в которую подключается ВМ"
  type        = string
}

variable "security_group_ids" {
  description = "Группы безопасности ВМ"
  type        = list(string)
}

variable "key_pair" {
  description = "Имя SSH-ключа в облаке"
  type        = string
}

variable "user_data" {
  description = "cloud-init. null — без него"
  type        = string
  default     = null
}

# ---------- Квоты курса: один минимальный тип ВМ на всех ----------
# В общем проекте 15 ВМ, 30 vCPU и 60 ГБ RAM на 30 человек. 1 vCPU / 2 ГБ × 15 ВМ — влезает.
variable "flavor" {
  description = "Тип ВМ. В курсе разрешён только минимальный: s7n.medium.2 (1 vCPU / 2 ГБ)"
  type        = string
  default     = "s7n.medium.2"

  validation {
    condition     = contains(["s7n.medium.2"], var.flavor)
    error_message = "В общем проекте курса разрешён только тип s7n.medium.2 (1 vCPU / 2 ГБ) — иначе не хватит квоты на всех."
  }
}

# Диск: по умолчанию — минимум образа. Больше 20 ГБ нельзя: квота на диски общая.
# С null сравнивать нельзя, поэтому условие — через тернарный оператор, а не через ||.
variable "disk_size" {
  description = "Размер системного диска, ГБ. null — минимум образа (по умолчанию)"
  type        = number
  default     = null

  validation {
    condition     = var.disk_size == null ? true : var.disk_size <= 20
    error_message = "Диск не больше 20 ГБ: квота на диски общая на всю группу. Не задавайте disk_size — модуль возьмёт минимум образа."
  }
}

variable "availability_zone" {
  description = "Зона доступности. null — модуль выберет сам: «случайную» зону, где есть нужный тип ВМ"
  type        = string
  default     = null
}

variable "image_id" {
  description = "ID образа ОС. null — модуль найдёт свежий образ по image_name_regex"
  type        = string
  default     = null
}

variable "image_name_regex" {
  description = "Шаблон имени публичного образа (если image_id не задан)"
  type        = string
  default     = "^Ubuntu 22.04 server 64bit$"
}

variable "public_ip" {
  description = "true — выдать ВМ публичный IP (EIP), false — только внутренний адрес"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Теги ВМ"
  type        = map(string)
  default     = {}
}
