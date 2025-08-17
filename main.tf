# main.tf
# SSH Key Generation
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "vpn" {
  name       = "wireguard-vpn-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# WireGuard Key Generation
resource "wireguard_asymmetric_key" "server" {}

resource "wireguard_asymmetric_key" "clients" {
  count = var.client_count
}

# Calculate IP addresses for server and clients
locals {
  server_ipv4_address = cidrhost(var.vpn_ipv4_cidr, 1)
  server_ipv6_address = cidrhost(var.vpn_ipv6_cidr, 1)

  client_configs = [
    for idx in range(var.client_count) : {
      ipv4_address = cidrhost(var.vpn_ipv4_cidr, idx + 2)
      ipv6_address = cidrhost(var.vpn_ipv6_cidr, idx + 2)
      private_key  = wireguard_asymmetric_key.clients[idx].private_key
      public_key   = wireguard_asymmetric_key.clients[idx].public_key
    }
  ]

  # Indent string to keep cloud-init.yaml well formatted after interpolation
  peer_configs = indent(6, join("\n", [
    for client in local.client_configs : <<-EOT
    [Peer]
    PublicKey = ${client.public_key}
    AllowedIPs = ${client.ipv4_address}/32,${client.ipv6_address}/128
    EOT
  ]))
}

# Create firewall
resource "hcloud_firewall" "vpn" {
  name = "wireguard-vpn"
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "51820"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  apply_to {
    server = hcloud_server.wireguard.id
  }
}

data "template_file" "cloud_init" {
  template = file("cloud-init.yaml.tpl")

  vars = {
    server_private_key  = wireguard_asymmetric_key.server.private_key
    server_ipv4_address = "${local.server_ipv4_address}/32"
    server_ipv6_address = "${local.server_ipv6_address}/128"
    peer_configs        = local.peer_configs
    interface           = var.interface
  }
}

# Create server
resource "hcloud_server" "wireguard" {
  name        = "wireguard-vpn"
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.vpn.id]
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = data.template_file.cloud_init.rendered
}


# outputs.tf
# Creates ready to use local files for client configurations.
# Generate QR code on Linux:
# cat clientN.conf | qrencode -t ansiutf8
resource "local_file" "client_configs" {
  count = var.client_count

  content = templatefile("client-config.tpl", {
    client_private_key  = wireguard_asymmetric_key.clients[count.index].private_key
    client_ipv4_address = local.client_configs[count.index].ipv4_address
    client_ipv6_address = local.client_configs[count.index].ipv6_address
    server_public_key   = wireguard_asymmetric_key.server.public_key
    server_public_ip = (var.use_ipv6_endpoint ?
      "[${hcloud_server.wireguard.ipv6_address}]" :
    hcloud_server.wireguard.ipv4_address)
  })

  filename = "client${count.index + 1}.conf"
}

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



# cloud-init.yaml.tpl
#cloud-config
package_update: true
package_upgrade: false

packages:
  - wireguard
  - ufw

write_files:
  - path: /etc/wireguard/wg0.conf
    content: |
      [Interface]
      Address = ${server_ipv4_address},${server_ipv6_address}
      PrivateKey = ${server_private_key}
      ListenPort = 51820

      PostUp = ufw route allow in on wg0 out on ${interface}
      PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
      PostUp = iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE
      PostUp = ip6tables -A FORWARD -i wg0 -j ACCEPT
      PostUp = ip6tables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE
      PostDown = ufw route delete allow in on wg0 out on ${interface}
      PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
      PostDown = iptables -t nat -D POSTROUTING -o ${interface} -j MASQUERADE
      PostDown = ip6tables -D FORWARD -i wg0 -j ACCEPT
      PostDown = ip6tables -t nat -D POSTROUTING -o ${interface} -j MASQUERADE

      ${peer_configs}
    owner: root:root
    permissions: '0600'

runcmd:
  - ufw allow 51820/udp
  - ufw allow OpenSSH
  - echo "y" | ufw enable
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  - echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
  - sysctl -p
  - systemctl enable wg-quick@wg0
  - systemctl start wg-quick@wg0


# client-config.tpl
[Interface]
PrivateKey = ${client_private_key}
Address = ${client_ipv4_address},${client_ipv6_address}
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = ${server_public_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${server_public_ip}:51820
PersistentKeepalive = 25
