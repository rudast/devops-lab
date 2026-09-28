output "public_ip" {
  description = "Публичный IP ВМ — пригодится для SSH, Ansible и CI/CD"
  value       = sbercloud_vpc_eip.ip.address
}

output "ssh_command" {
  value = "ssh root@${sbercloud_vpc_eip.ip.address}"
}
