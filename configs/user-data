```
#cloud-config
package_update: true
packages:
  - iptables-persistent
  - fail2ban
  - auditd
  - qemu-guest-agent
  - net-tools
groups:
  - admins
users:
  - name: ubadmin
    primary_group: admin
    groups:
      - sudo
      - admins
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - <ssh_public_key>
write_files:
  - path: /etc/iptables/rules.v4
    permissions: 0640
    owner: root:root
    content: |
      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]
      -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
      -A INPUT -i lo -j ACCEPT
      -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
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
  - printf "%s\n""readonly TMOUT=900" "export TMOUT" >> /etc/profile
  - printf "%s\n" "net.ipv6.conf.all.disable_ipv6 = 1" "net.ipv6.conf.default.disable_ipv6 = 1" "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf && sysctl -p
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^#ClientAliveInterval/s/^.*$/ClientAliveInterval 5m/' /etc/ssh/sshd_config
  - sed -i -e '/^#ClientAliveCountMax/s/^.*$/ClientAliveCountMax 3/' /etc/ssh/sshd_config
  - sed -i -e '$aAllowGroups admins' /etc/ssh/sshd_config
  - systemctl enable fail2ban
  - reboot
```