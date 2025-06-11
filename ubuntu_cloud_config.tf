data "local_file" "ssh_public_key" {
  filename = "${var.ci_ssh_key}"
}

resource "proxmox_virtual_environment_file" "ubuntu_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippet_storage
  node_name    = var.node_name
  
  source_raw {
    data = <<-EOF
#cloud-config
hostname: ${var.vm_hostname}
fqdn: ${var.vm_hostname}.${var.vm_domain}
manage_etc_hosts: true

package_update: true
packages:
  - iptables-persistent
  - fail2ban
  - auditd
  - qemu-guest-agent
  - net-tools

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

#device_aliases: {data_disk: /dev/sdb}
#disk_setup:
#  data_disk:
#   layout: [100]
#    overwrite: true
#    table_type: gpt
#fs_setup:
#  - {cmd: mkfs -t %(filesystem)s -L %(label)s %(device)s, device: data_disk.1, filesystem: ext4,
#  label: data}
#mounts:
#  - [data_disk.1, /mnt/data]


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

  - path: /etc/iptables/rules.v4
    permissions: 0640
    owner: root:root
    content: |
      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]
      -A INPUT -p tcp -m tcp --dport ${var.ci_ssh_port} -j ACCEPT
      -A INPUT -i lo -j ACCEPT
      -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
      -A INPUT -p icmp --icmp-type 0 -j ACCEPT
      -A INPUT -p icmp --icmp-type 3 -j ACCEPT
      -A INPUT -p icmp --icmp-type 11 -j ACCEPT
      COMMIT

  - path: /etc/fail2ban/jail.local
    permissions: 0640
    owner: root:root
    content: |
      [sshd]
      enabled = true
      findtime = 1m
      nmaxretry = 5
      bantime = 15m

  - path: /etc/audit/rules.d/audit.rules
    permissions: 0640
    owner: root:root
    content: |
      -D
      -e 1
      -f 1
      -a always,exclude -F msgtype=CWD
      -a always,exclude -F msgtype=PATH
      -a always,exclude -F msgtype=PROCTITLE
      -a always,exit -F dir=/var/log/audit/ -F perm=wa -F auid!=unset -F key=audit-trail-modification
      -a always,exit -F path=/var/log/syslog -F perm=wa -F auid!=unset -F key=audit-trail-modification
      -a always,exit -F path=/var/log/auth.log -F perm=wa -F auid!=unset -F key=audit-trail-modification
      -a always,exit -F arch=x86_64 -S setuid -F auid!=unset -F a0=0 -F exe=/usr/bin/su -F key=elevated-privileges-session
      -a always,exit -F arch=x86_64 -S setresuid -F auid!=unset -F a0=0 -F exe=/usr/bin/sudo -F key=elevated-privileges-session
      -a always,exit -F arch=x86_64 -S execve -F auid!=unset -C uid!=euid -F euid=0 -F key=elevated-privileges-session
      -a always,exit -F arch=x86_64 -S chmod -S fchmod -S chown -S fchown -S lchown -F auid!=unset -F key=access-rights-modification
      
runcmd:
    - apt upgrade
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

    file_name = "${var.vm_hostname}.cloud-config.yaml"
  }
}