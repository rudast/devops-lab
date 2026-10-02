# Занятие 10. ДЛЯ ПРЕПОДАВАТЕЛЯ: общая сеть курса в общем проекте cloud.ru.
# Запускается ОДИН раз до занятия. Студенты эту сеть только читают (data source в steps/01-data.tf).
#
#   export SBC_ACCESS_KEY=...  SBC_SECRET_KEY=...
#   terraform init && terraform apply
#
# Почему общая сеть: в проекте есть квота на число VPC (обычно единицы), а студентов — десятки.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.12"
    }
  }
}

provider "sbercloud" {
  auth_url = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region   = "ru-moscow-1"
}

resource "sbercloud_vpc" "course" {
  name = "devops-course-vpc"
  cidr = "192.168.0.0/16"
}

# /22 — до ~1000 адресов: хватит на всю группу с запасом
resource "sbercloud_vpc_subnet" "course" {
  name       = "devops-course-subnet"
  cidr       = "192.168.8.0/22"
  gateway_ip = "192.168.8.1"
  vpc_id     = sbercloud_vpc.course.id
}

output "vpc" {
  value = "${sbercloud_vpc.course.name} ${sbercloud_vpc.course.cidr}"
}

output "subnet" {
  value = "${sbercloud_vpc_subnet.course.name} ${sbercloud_vpc_subnet.course.cidr}"
}
