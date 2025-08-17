resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "vpn" {
  name       = "wireguard-vpn-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "wireguard_asymmetric_key" "server" {}

resource "wireguard_asymmetric_key" "clients" {
  count = var.client_count
}

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
