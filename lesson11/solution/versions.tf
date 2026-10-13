# Занятие 11 — ГОТОВОЕ РЕШЕНИЕ: так выглядит practice после всех частей.
# Сначала попробуйте сами в lesson11/practice — сюда подглядывайте, если застряли.

terraform {
  required_version = ">= 1.5"

  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.12"
    }
  }
}

# Ключи доступа — только из переменных окружения SBC_ACCESS_KEY / SBC_SECRET_KEY
provider "sbercloud" {
  auth_url = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region   = var.region
}
