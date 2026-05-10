# bgp-example/variables.tf
## Proxmox 
variable "pve_token_id" {
  description = "Proxmox API Token Name."
  sensitive   = true
}
variable "pve_token_secret" {
  description = "Proxmox API Token Value."
  sensitive   = true
}
variable "pve_api_url" {
  description = "Proxmox API Endpoint, e.g. 'https://pve.example.com/api2/json'"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("(?i)^http[s]?://.*/api2/json$", var.pve_api_url))
    error_message = "Proxmox API Endpoint Invalid. Check URL - Scheme and Path required."
  }
}
variable "node_name" {
  description = "Hostname proxmox node"
  type        = string
  default     = "pve-1"
}
# Ssh keys
variable "private_key_file" {
  description = "SSH privte key file"
  type        = string
}
variable "public_key_file" {
  description = "SSH public key file"
  type        = string
}
# Cloud-init
variable "cloud_init_user" {
  description = "Username cloud-init user"
  type        = string
  default     = "ubadmin"
}
variable "cloud_init_user_password" {
  description = "Password from user in custom cloud-init file."
  sensitive   = true
  default     = "Password"
}
variable "ci_ssh_key" {
  description = "File path to SSH key for 'default' user, e.g. `~/.ssh/id_ed25519.pub`."
  type        = string
  default     = null
}
variable "ci_ssh_port" {
  description = "Port for connecting to the server via ssh"
  type        = string
  default     = "22"
}

# Vm settings
variable "count_number" {
  description = "Number of iterations to create resource"
  type        = number
  default     = 1
}
variable "bios" {
  description = "VM bios, setting to `ovmf` will automatically create a EFI disk."
  type        = string
  default     = "seabios"
  validation {
    condition     = contains(["seabios", "ovmf"], var.bios)
    error_message = "Invalid bios setting: ${var.bios}. Valid options: 'seabios' or 'ovmf'."
  }
}
variable "vm_hostname" {
  description = "VM hostanme "
  type        = string
  default     = ["vm-1"]
}
variable "vm_domain" {
  description = "VM domain "
  type        = string
  default     = "example.com"
}

# Storage
variable "storage_pool" {
  description = "Storage name "
  type        = string
  default     = "local-lvm"
}
variable "snippet_storage" {
  description = "Storage name "
  type        = string
  default     = "local"
}
variable "image_storage" {
  description = "Storage contain vm image"
  type = string
  default = "local"
}
variable "stor_file_format" {
  description = "Format virtual disk"
  type        = string
  default     = "raw"
}

# Network
variable "network_int" {
  description = "Network interface"
  type        = string
  default     = "vmbr0"
}
variable "ip_addr" {
  description = "Network address "
  type        = string
  default = ["192.168.1.2/24"]
}
variable "dns_servers" {
  description = "Network address "
  type        = string
  default = ["8.8.8.8"]
}
variable "ip_gateway" {
  description = "ip address gateway CIDR"
  type        = string
}