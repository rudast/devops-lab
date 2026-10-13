# Занятие 12. Стартовая папка практики. Порядок работы — в README, части 1–7.

terraform {
  required_version = ">= 1.5" # блок import (часть 4) появился в 1.5

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
