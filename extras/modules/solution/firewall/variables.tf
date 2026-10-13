# Входы модуля firewall — готовы, их менять не нужно.

variable "name" {
  description = "Имя группы безопасности"
  type        = string
}

# Карта «порт => откуда разрешён доступ». Ключ — строка: у for_each ключи всегда строки.
# Пример: { "22" = "0.0.0.0/0", "80" = "0.0.0.0/0" }
variable "ports" {
  description = "Открытые TCP-порты: порт => CIDR"
  type        = map(string)
}
