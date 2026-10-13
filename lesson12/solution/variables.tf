variable "region" {
  description = "Регион облака"
  type        = string
  default     = "ru-moscow-1"
}

variable "prefix" {
  description = "Префикс команды — две фамилии латиницей через дефис. Все ресурсы называются <prefix>-…"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}$", var.prefix))
    error_message = "prefix: 3–29 символов, строчные латинские буквы, цифры и дефис, начинается с буквы. Например: ivanov-petrov."
  }
}

variable "subnet_name" {
  description = "Общая подсеть курса (её создал преподаватель, см. lesson10/shared)"
  type        = string
  default     = "devops-course-subnet"
}

variable "image_name_regex" {
  description = "Шаблон имени публичного образа ОС"
  type        = string
  default     = "^Ubuntu 22.04 server 64bit$"
}

# ---------- Квоты курса: 15 ВМ, 30 vCPU, 60 ГБ RAM на всю группу ----------
variable "vm_flavor" {
  description = "Тип ВМ. В курсе разрешён только минимальный: s7n.medium.2 (1 vCPU / 2 ГБ)"
  type        = string
  default     = "s7n.medium.2"

  validation {
    condition     = contains(["s7n.medium.2"], var.vm_flavor)
    error_message = "В общем проекте курса разрешён только тип s7n.medium.2 (1 vCPU / 2 ГБ) — иначе не хватит квоты на всех."
  }
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу того, кто запускает apply (.pub!)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# Часть 6. Выключатель публичного IP
variable "public_ip" {
  description = "true — у ВМ есть публичный IP, false — только внутренний адрес"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr" {
  description = "С каких адресов разрешён SSH. Лучше свой IP/32: curl -s ifconfig.me"
  type        = string
  default     = "0.0.0.0/0"
}

# ---------- Приложение ----------
variable "repo_url" {
  description = "Откуда ВМ берёт код курса (docker-compose.yml занятия 9 и бэкенд)"
  type        = string
  default     = "https://github.com/tenroman1-design/devops-lab.git"
}

variable "registry" {
  description = "Реестр с копиями образов Docker Hub (Docker Hub из облака работает нестабильно)"
  type        = string
  default     = "ghcr.io/tenroman1-design/devops-lab"
}

# Часть 6: сколько копий бэкенда за nginx — как docker compose up --scale backend=N в занятии 9
variable "backend_count" {
  description = "Число копий бэкенда (1–3: на ВМ всего 2 ГБ памяти)"
  type        = number
  default     = 1

  validation {
    condition     = var.backend_count >= 1 && var.backend_count <= 3
    error_message = "backend_count: от 1 до 3 — на ВМ 1 vCPU и 2 ГБ памяти."
  }
}

# Пароль базы. Значения по умолчанию НЕТ: Terraform возьмёт его из переменной окружения
#   export TF_VAR_db_password="$(openssl rand -hex 12)"
# sensitive = true — Terraform не печатает значение в plan, apply и output.
variable "db_password" {
  description = "Пароль PostgreSQL (только латинские буквы и цифры, не короче 12 символов)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9]{12,}$", var.db_password))
    error_message = "db_password: не короче 12 символов, только латинские буквы и цифры (спецсимволы ломают строку подключения к базе). Например: export TF_VAR_db_password=\"$(openssl rand -hex 12)\"."
  }
}
