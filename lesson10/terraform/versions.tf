terraform {
  required_version = ">= 1.5"

  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.12"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Ключи НЕ пишем в код. Провайдер сам читает переменные окружения:
#   export SBC_ACCESS_KEY=...   export SBC_SECRET_KEY=...
provider "sbercloud" {
  auth_url = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region   = var.region
}
