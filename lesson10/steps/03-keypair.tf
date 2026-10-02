# ШАГ 3. Загружаем в облако ваш ПУБЛИЧНЫЙ SSH-ключ.
#   cp ../steps/03-keypair.tf .  &&  terraform plan  &&  terraform apply
# Ожидаемо: "1 to add".
#
# ЗАДАНИЕ: замените TODO на ссылку на переменную с путём к ключу (см. variables.tf).
# Подсказка: к переменной обращаются так: var.<имя>

resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-key"
  public_key = file(pathexpand(TODO))
}

# Отпечаток ключа — сравните с локальным: ssh-keygen -lf ~/.ssh/id_ed25519.pub
output "key_fingerprint" {
  value = sbercloud_kps_keypair.key.fingerprint
}
