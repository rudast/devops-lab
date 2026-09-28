variable "region" {
  description = "Регион облака"
  type        = string
  default     = "ru-moscow-1"
}

variable "prefix" {
  description = "Префикс имён ресурсов (например, фамилия студента)"
  type        = string
}

variable "image_name" {
  description = "Точное имя публичного образа ОС (проверьте в консоли: ECS → Images)"
  type        = string
  default     = "Ubuntu 22.04 server 64bit"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "С какого адреса разрешён SSH (лучше свой IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}
