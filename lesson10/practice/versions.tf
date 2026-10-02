# Занятие 10. Стартовая папка практики: здесь вы шаг за шагом соберёте свою ВМ.
# Файлы шагов лежат в ../steps — копируйте их сюда по одному (см. README).

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
