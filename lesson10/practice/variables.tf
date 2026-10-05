variable "region" {
  description = "Регион облака"
  type        = string
  default     = "ru-moscow-1"
}

variable "prefix" {
  description = "Ваш префикс — фамилия латиницей. Все ресурсы в общем проекте называются <prefix>-…"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.prefix))
    error_message = "prefix: 3–21 символ, строчные латинские буквы, цифры и дефис, начинается с буквы. Например: ivanov."
  }
}

variable "subnet_name" {
  description = "Общая подсеть курса (её заранее создал преподаватель, см. lesson10/shared)"
  type        = string
  default     = "devops-course-subnet"
}

variable "image_name_regex" {
  description = "Шаблон имени публичного образа ОС"
  type        = string
  default     = "^Ubuntu 22.04 server 64bit$"   # $ — без GPU-образов «… with Grid Driver»
}

# Тип ВМ курса: s7n.medium.2 = поколение s7n, 1 vCPU, 2 ГБ — самый экономный по квотам
variable "vm_generation" {
  description = "Поколение (семейство) типа ВМ"
  type        = string
  default     = "s7n"
}

variable "vm_cpu" {
  description = "Число vCPU"
  type        = number
  default     = 1
}

variable "vm_ram" {
  description = "Память, ГБ"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Размер системного диска, ГБ. Меньше минимума образа не будет. Увеличивать можно, уменьшать — нет"
  type        = number
  default     = 10
}

variable "ssh_public_key_path" {
  description = "Путь к ВАШЕМУ публичному SSH-ключу (.pub!)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "С каких адресов разрешён SSH. 0.0.0.0/0 — отовсюду; лучше свой IP/32"
  type        = string
  default     = "0.0.0.0/0"
}
