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

# Какие серверы создать (ЧАСТЬ 3). Ключ карты — короткое имя сервера, значение — его настройки.
variable "servers" {
  description = "Серверы: имя => настройки"
  type = map(object({
    disk_size = optional(number) # null — минимум образа, решает модуль
  }))
  default = {
    "web-1" = {}
  }

  # Часть 2. Квота проекта — 15 ВМ на всю группу, поэтому на команду — не больше ОДНОЙ ВМ.
  validation {
    condition     = length(var.servers) <= 1
    error_message = "Квота: не больше одной ВМ на команду (15 ВМ на всю группу)."
  }
}

variable "subnet_name" {
  description = "Общая подсеть курса"
  type        = string
  default     = "devops-course-subnet"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу того, кто запускает apply (.pub!)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "С каких адресов разрешён SSH"
  type        = string
  default     = "0.0.0.0/0"
}
