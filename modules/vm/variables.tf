# bgp-example/variables.tf
## Proxmox 
variable "node_name" {
  description = "Hostname proxmox node"
  type        = string
  default     = "pve-1"
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
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYLoOiQU4lCH+u0rKjbTGOT9dHqeXXS6XdkV+KzSlqK"
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
  default     = ["vm-1"]
}
variable "vm_domain" {
  description = "VM domain "
  type        = string
  default     = "example.com"
}
variable "cpu_num" {
  description = "Number of vCpu"
  type        = number
  default     = "4"
}
variable "memory_mb" {
  description = "Memory in Mb"
  type =  number
  default = "4096"
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
variable "os_disk_size" {
  description = "Size disk in Gb"
  type        = number
  default     = "20"
}
variable "data_disk_size" {
  description = "Size disk in Gb"
  default     = null
}
# Network
variable "network_int" {
  description = "Network interface"
  type        = string
  default     = "vmbr0"
}
variable "ip_addr" {
  description = "Network address "
  default = ["192.168.1.2/24"]
}
variable "dns_servers" {
  description = "Network address "
  default = ["8.8.8.8"]
}
variable "ip_gateway" {
  description = "ip address gateway CIDR"
  type        = string
  default = "192.168.1.1"
}