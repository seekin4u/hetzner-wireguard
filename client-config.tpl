[Interface]
PrivateKey = ${client_private_key}
Address = ${client_ipv4_address},${client_ipv6_address}
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = ${server_public_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${server_public_ip}:51820
PersistentKeepalive = 25