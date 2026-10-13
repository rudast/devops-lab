# Блока provider в модуле нет: настройки провайдера приходят от вызывающего кода.
terraform {
  required_providers {
    sbercloud = {
      source = "sbercloud-terraform/sbercloud"
    }
  }
}
