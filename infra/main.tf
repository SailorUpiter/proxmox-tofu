module "ssh_key_dns" {
  source = "../modules/ssh"
  key_name = ["dns_ssh_key"]
}

module "dns" {
  source = "../modules/vm"
  vm_hostname = ["dns"]
  vm_domain = "sailor.lab"
  os_disk_size = 10
  ip_addr = ["192.168.1.2/24"]
  ci_ssh_key = module.ssh_key_dns.public_key
}

module "ssh_key_gitlab" {
  source = "../modules/ssh"
  key_name = ["gitlab_ssh_key"]
}

module "gitlab" {
  source = "../modules/vm"
  vm_hostname = ["gitlab"]
  vm_domain = "sailor.lab"
  os_disk_size = 10
  ip_addr = ["192.168.1.3/24"]
  data_disk_size = 10
  ci_ssh_key = module.ssh_key_gitlab.public_key
}
module "ssh_key_vault" {
  source = "../modules/ssh"
  key_name = ["vault_ssh_key"]
}

module "vault" {
  source = "../modules/vm"
  vm_hostname = ["vault"]
  vm_domain = "sailor.lab"
  os_disk_size = 10
  ip_addr = ["192.168.1.4/24"]
  data_disk_size = 10
  ci_ssh_key = module.ssh_key_vault.public_key
}
