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
  # Edit: fucking indent needed here because we do call template() on cloud-init.tmplname
  # Its going to be broken without that two TABs
  peer_configs = indent(6, join("\n", [
    for client in local.client_configs : <<-EOT
    [Peer]
    PublicKey = ${client.public_key}
    AllowedIPs = ${client.ipv4_address}/32,${client.ipv6_address}/128
    EOT
  ]))
}