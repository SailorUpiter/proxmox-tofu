data "local_file" "ssh_public_key" {
  filename = "${var.ci_ssh_key}"
}

resource "proxmox_virtual_environment_file" "ubuntu_cloud_init" {
  count        = var.count_number
  content_type = "snippets"
  datastore_id = var.snippet_storage
  node_name    = var.node_name
  
  source_raw {
    data = <<-EOF
#cloud-config
hostname: ${var.vm_hostname}-${count.index + 1}
fqdn: ${var.vm_hostname}-${count.index + 1}.${var.vm_domain}
manage_etc_hosts: true


package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - iptables-persistent
  - fail2ban
  - auditd
  - qemu-guest-agent
  - net-tools
  - zabbix-agent2

chpasswd:
  list: |
    ${var.cloud_init_user}:${var.cloud_init_user_password}
  expire: false
groups:
  - admins
users:
  - name: ${var.cloud_init_user}
    primary_group: admins
    groups:
      - sudo
      - admins
    groups: sudo
    shell: /bin/bash
    ssh-authorized-keys:
      - ${trimspace(data.local_file.ssh_public_key.content)}
    sudo: ALL=(ALL) NOPASSWD:ALL

device_aliases: {data_disk: /dev/sdb}
disk_setup:
  data_disk:
    layout: [100]
    overwrite: true
    table_type: gpt
fs_setup:
  - {cmd: mkfs -t %(filesystem)s -L %(label)s %(device)s, device: data_disk.1, filesystem: ext4,
  label: data}
mounts:
  - [data_disk.1, /mnt/data]


write_files:
  - path: /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
    permissions: 0640
    owner: root:root
    content: |
      Port ${var.ci_ssh_port}
      PermitRootLogin no
      PasswordAuthentication no
      ClientAliveInterval 5m
      ClientAliveCountMax 3
      AllowGroups admins

      
runcmd:
    - sudo sed -i 's/^Server=.*$/Server=${var.zabbix_server}/' /etc/zabbix/zabbix_agent2.conf
    - timedatectl set-timezone Europe/Moscow
    - systemctl enable qemu-guest-agent fail2ban
    - systemctl start qemu-guest-agent
    - echo "done" > /tmp/cloud-config.done
    
power_state:
    delay: now
    mode: reboot
    message: Rebooting after cloud-init completion
    condition: true

EOF

    file_name = "${var.vm_hostname}-${count.index + 1}.cloud-config.yaml"
  }
}