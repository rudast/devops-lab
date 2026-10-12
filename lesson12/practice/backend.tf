# State занятия 12 — в PostgreSQL курса, как в занятии 11, но в своём workspace:
#   export PG_CONN_STR="…"              # строка подключения от преподавателя
#   terraform init
#   terraform workspace new <prefix>-l12
#
# Блокировка есть: пока «водитель» делает apply, plan/apply штурмана в тот же workspace подождут.

terraform {
  backend "pg" {
    schema_name = "devops_course"
  }
}
