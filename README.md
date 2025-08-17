Author of the module:
https://upvpn.app/articles/post/wireguard-vpn-on-hetzner-terraform/
https://github.com/upvpn/upvpn-app

---
terraform output -raw ssh_private_key > wireguard_private_key
chmod 600 ./wireguard_private_key
ssh -i ./wireguard_private_key root@ip
sudo wg
sudo journalctl -u wg-quick@wg0sudo cat /etc/wireguard/wg0.conf
