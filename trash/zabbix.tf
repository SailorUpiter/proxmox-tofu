resource "zabbix_host" "zabbix-template" {
  count = var.count_number
  host = "${var.vm_hostname}-${count.index + 1}"
  name = "${var.vm_hostname}-${count.index + 1}"

  enabled = true
  templates = [ "10001" ] #Linux by zabbix agent passive
  groups = [ "2" ] #group linux servers
  interface {
    type = "agent"
    ip = "${var.network}.${ var.ip_address + count.index}"

    main = true
    port = 10050

    # if zabbix version >= 5 and type is snmp
  }
  tag {
     key = "Ubuntu22.04"  
  }
  tag {
     key = "VM"  
  }
  tag {
     key = "agent"  
  }
  tag {
     key = "Server"  
  }
}