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
  - yes | ufw enable
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  - echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
  - sysctl -p
  - systemctl enable wg-quick@wg0
  - systemctl start wg-quick@wg0
