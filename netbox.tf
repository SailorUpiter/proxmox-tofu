data "netbox_cluster" "cluster_name" {
  name = var.cluster_name
}
data "netbox_tenant" "tenant" {
  name = var.tenant
}
resource "netbox_virtual_machine" "vm" {
    count        = var.count_number
    cluster_id   = data.netbox_cluster.cluster_name.id
    name         = "${var.vm_hostname}-${count.index + 1}" 
    disk_size_mb = var.os_disk_size * 1000 + var.data_disk_size * 1000
    memory_mb    = var.memory_mb
    vcpus        = var.cpu_num
    tenant_id    = data.netbox_tenant.tenant.id
}
resource "netbox_interface" "basic_int" {
  count              = var.count_number
  name               = "eth0"
  virtual_machine_id = netbox_virtual_machine.vm[count.index].id
}

resource "netbox_ip_address" "address" {
  count                        = var.count_number
  ip_address                   = "${var.ip_address}.${( var.ip_address + count.index)}${var.mask}"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.basic_int[count.index].id
  tenant_id                    = data.netbox_tenant.tenant.id
  dns_name                     = "${var.vm_hostname}-${count.index + 1}.${var.vm_domain}" 
}

resource "netbox_virtual_disk" "os_disk" {
  count              = var.count_number
  name               = "OS-disk"
  description        = "OS disk"
  size_mb            = var.os_disk_size * 1000
  virtual_machine_id = netbox_virtual_machine.vm[count.index].id
}
resource "netbox_virtual_disk" "data_disk" {
  count              = var.count_number
  name               = "Data-disk"
  description        = "Data disk"
  size_mb            = var.data_disk_size * 1000
  virtual_machine_id = netbox_virtual_machine.vm[count.index].id
}
resource "netbox_primary_ip" "site-trustinfo_ip_v4" {
  count = var.count_number
  ip_address_id      = netbox_ip_address.address[count.index].id
  virtual_machine_id = netbox_virtual_machine.vm[count.index].id
  ip_address_version = 4 ## ipv4
}