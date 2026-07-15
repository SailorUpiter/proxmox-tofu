terraform {
  required_providers {
    proxmox = {
      source = "registry.terraform.io/bpg/proxmox"
    }
    local = {
      source = "registry.terraform.io/hashicorp/local"
    }
    null = {
      source = "registry.terraform.io/hashicorp/null"
    }
    time = {
      source = "registry.terraform.io/hashicorp/time"
    }
    netbox = {
      source = "registry.terraform.io/e-breuninger/netbox"
    }
    zabbix = {
      source = "registry.terraform.io/kgeroczi/zabbix"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_api_url
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = true
  ssh {
    agent    = true
    username = "root"
    private_key = file("C:\\Users\\medik\\Documents\\ssh\\id_ed25519")
  }
}

provider "netbox" {
  server_url = var.netbox_api_url
  api_token  = var.netbox_token_secret
}
provider "zabbix" {
  # Required
  username = var.zabbix_login
  password = var.zabbix_password
  url = var.zabbix_server_url
  
  # Disable TLS verfication (false by default)
  tls_insecure = true

  # Serialize Zabbix API calls (false by default)
  # Note: race conditions have been observed, enable this if required
  serialize = true
}