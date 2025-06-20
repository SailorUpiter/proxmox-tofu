data "netbox_cluster" "cluster_name" {
  name = var.cluster_name
}
data "netbox_tenant" "tenant" {
  name = var.tenant
}
resource "netbox_virtual_machine" "basic_vm" {
    cluster_id   = data.netbox_cluster.cluster_name.id
    name         = var.vm_hostname
    disk_size_mb = (var.os_disk_size + var.data_disk_size) * 1000
    memory_mb    = var.memory_mb
    vcpus        = var.cpu_num
    tenant_id    = data.netbox_tenant.tenant.id
}
resource "netbox_interface" "basic_int" {
  name               = "eth0"
  virtual_machine_id = netbox_virtual_machine.basic_vm.id
}

resource "netbox_ip_address" "address" {
  ip_address                   = var.ip_address
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.basic_int.id
  tenant_id                    = data.netbox_tenant.tenant.id
  dns_name                     = "${var.vm_hostname}.${var.vm_domain}"
}

resource "netbox_virtual_disk" "os_disk" {
  name               = "OS-disk"
  description        = "OS disk"
  size_mb            = netbox_virtual_machine.basic_vm.disk_size_mb
  virtual_machine_id = netbox_virtual_machine.basic_vm.id
}
resource "netbox_virtual_disk" "data_disk" {
  name               = "Data-disk"
  description        = "Data disk"
  size_mb            = var.data_disk_size * 1000
  virtual_machine_id = netbox_virtual_machine.basic_vm.id
}