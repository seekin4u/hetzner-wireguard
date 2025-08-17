# outputs.tf

# Get ssh private key `terraform output -raw ssh_private_key > wireguard-ssh-key`
# chmod 400 wireguard-ssh-key
# ssh -i wireguard-ssh-key root@<ip-address>
output "ssh_private_key" {
  value     = tls_private_key.ssh.private_key_openssh
  sensitive = true
}

output "server_public_ipv4" {
  value = hcloud_server.wireguard.ipv4_address
}

output "server_public_ipv6" {
  value = hcloud_server.wireguard.ipv6_address
}