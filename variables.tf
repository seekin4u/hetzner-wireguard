variable "hcloud_token" {
  description = "Hetzner Cloud token"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Hetzner Datacenter location https://docs.hetzner.com/cloud/general/locations/#what-locations-are-there"
  type        = string
  default     = "fsn1"
}

variable "server_type" {
  description = "Server Type https://docs.hetzner.com/cloud/servers/overview#pricing"
  type        = string
  default     = "cax11"
}

variable "image" {
  description = "Name or ID of the image the server is created from"
  default     = "ubuntu-20.04"
}

variable "client_count" {
  description = "Number of WireGuard clients to create"
  type        = number
  default     = 1
}

variable "vpn_ipv4_cidr" {
  description = "IPv4 CIDR for WireGuard VPN"
  type        = string
  default     = "10.10.0.0/24"
}

variable "vpn_ipv6_cidr" {
  description = "IPv6 CIDR for WireGuard VPN"
  type        = string
  default     = "fd00:10:10::/64"
}

variable "use_ipv6_endpoint" {
  description = "Use IPv6 endpoint in client config, otherwise use IPv4"
  default     = true
}

variable "interface" {
  description = "Default network interface on the instance"
  default     = "eth0"
}