# Занятие 10. ГОТОВОЕ РЕШЕНИЕ (ответы): так выглядит папка practice после всех шагов 1–5.
# Сначала попробуйте сами в lesson10/practice — сюда подглядывайте, если застряли.

terraform {
  required_version = ">= 1.5"

  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.12"
    }
  }
}

# Ключи доступа НЕ пишем в код. Провайдер сам читает переменные окружения:
#   export SBC_ACCESS_KEY=...   export SBC_SECRET_KEY=...
provider "sbercloud" {
  auth_url = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region   = var.region
}
