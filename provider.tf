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
  }
}

provider "proxmox" {
  endpoint  = var.pve_api_url
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = true
  ssh {
    agent    = true
    username = "root"
  }
}