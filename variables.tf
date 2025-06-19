# bgp-example/variables.tf
## Provider Login Variables
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

variable "cloud_init_user_password" {
  description = "Password from user in custom cloud-init file."
  sensitive   = true
}

## VM Variables
variable "bios" {
  description = "VM bios, setting to `ovmf` will automatically create a EFI disk."
  type        = string
  default     = "seabios"
  validation {
    condition     = contains(["seabios", "ovmf"], var.bios)
    error_message = "Invalid bios setting: ${var.bios}. Valid options: 'seabios' or 'ovmf'."
  }
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

variable "node_name" {
  description = "Hostname proxmox node"
  type        = string
}

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
variable "vm_hostname" {
  description = "VM hostanme "
  type        = string
}

variable "vm_domain" {
  description = "VM domain "
  type        = string
}

variable "vm_id" {
  description = "VM_ID"
  type        = number
  default     = "10000"
}

variable "ip_address" {
  description = "ip address CIDR/prefix"
  type        = string
}

variable "ip_gateway" {
  description = "ip address gateway CIDR"
  type        = string
}

variable "stor_file_format" {
  description = "Format virtual disk"
  type        = string
  default     = "raw"
}

variable "cloud_init_user" {
  description = "Username cloud-init user"
  type        = string
  default     = "ubadmin"
}

variable "netbox_api_url" {
  description = "Proxmox API Endpoint, e.g. 'https://netbox.example.com/api'"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("(?i)^http[s]?://.*/", var.netbox_api_url))
    error_message = "Netbox API Endpoint Invalid. Check URL - Scheme and Path required."
  }
}

variable "netbox_token_secret" {
  description = "Netbox API Token Value."
  sensitive   = true
} 

variable "cluster_name" {
  description = "Name Proxmox cluster in Netbox"
  type        = string
  default     = "pve-cluster"
}
variable "tenant" {
  description = "Name tenant in Netbox"
  type        = string
  default     = "trustinfo"
}
variable "os_disk_size" {
  description = "Size disk in Gb"
  type        = number
  default     = "20"
}
variable "data_disk_size" {
  description = "Size disk in Gb"
  type        = number
  default     = "20"
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