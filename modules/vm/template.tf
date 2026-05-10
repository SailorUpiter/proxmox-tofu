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

  - path: /etc/iptables/rules.v4
    permissions: 0640
    owner: root:root
    content: |
      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]
      -A INPUT -p tcp -m tcp --dport ${var.ci_ssh_port} -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 10050 -j ACCEPT
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
    - sudo wget https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4+ubuntu22.04_all.deb
    - sudo dpkg -i zabbix-release_latest_7.4+ubuntu22.04_all.deb
    - apt update
    - sudo apt install zabbix-agent2 
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
resource "proxmox_virtual_environment_vm" "template" { #описание ресурса в виде ресурс "вид ресурса" "название"
  count       = var.count_number           # Счетчик цикла. Цикл используется для создания сразу нескольких ВМ
  name        = "${var.vm_hostname}-${count.index + 1}"   # Имя виртуальной машины
  description = "Managed by Terraform. Aded in Netbox" # Описание ВМ
  tags        = ["terraform", "ubuntu"] # Теги в проксмоксе. Для ВМ созданных терраформом тег terraform обязательный
  bios        = var.bios
  node_name   = var.node_name # Имя ноды на которой будет развернута ВМ
  #vm_id       = var.vm_id        # Айди ВМ. ОБЯЗАТЕЛЬНО ДОЛЖНО БЫТЬ ИНДИВИДУАЛЬНЫМ!!!!
  scsi_hardware = "virtio-scsi-single"

  cpu {                       # Секция для настроек ЦПУ
    cores      = var.cpu_num            # Количество виртуальных ядер (vCPU)
    sockets    = 1            # Количество сокетов для процессора
    type       = "x86-64-v2-AES"  # Указываем тип процессора. При значении host используем хостовой проц, а не эмулируем его
                              # Хостовой проц может вызвать проблемы с миграцией на другие сервера, но не накладывает оверхеда
    numa       = false        # Включение технологии NUMA (Привязка ВМ к физическому процессору и памяти этого проца. Для многопроцессорных серверов)
    hotplugged = 0            # Включить горячую замену для виртуальных ядер процессора (Требуется включенная NUMA)
  }

  memory {                    # Секция для настроек оперативной памяти
    dedicated = var.memory_mb         # Количество выделяемой памяти в Mb
  }


  agent {                     # Секция кему агента. Кему агент позволяет более тесно взаимодействовать ВМ и хосту
                              # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
  }

  startup {                   # Секция для настроек запуска ВМ
    order      = "1"          # Порядок запуска. Машина с наименьшим числом запускается первой
    up_delay   = "15"         # Задержка перед запуском
    down_delay = "15"         # Задержка перед выключением
  }
  efi_disk {
    datastore_id = var.storage_pool # Имя хранилища . Хранилище должно быть активно на ноде, на которой создаем ВМ
    file_format  = var.stor_file_format # Формат файла диска (Raw сырые данные в виде блоков, QCOW2 данные пишутся в файл)
    type         = "4m"       # Тип ефи раздела
  }

  disk {                      # Секция для настройки жесткого диска ВМ. Для добавления второго диска добавить еще секцию disk и увеличить счетчик интерфеса
    datastore_id = var.storage_pool # Имя хранилища. Хранилище должно быть активно на ноде, на которой создаем ВМ
    file_id      = "${var.image_storage}:import/jammy-server-cloudimg-amd64.qcow2" # ИСО файл для установки ОС (облачной конфигурации). Должен лежать на локальном хранилище.
    interface    = "scsi0"  # Интерфейс для подключения диска (эмуляция шины или рейд контроллера). virtio современный интерфейс.
                              # рекомендуется использовать его, если не требуется эмулировать аппаратный рейд контроллер
    iothread     = true       # Потоки ввода\вывода, нужны для искорения 
    discard      = "on"       # При включении данной опции при тонком выделении ресурсов диск будет сжиматься если обнаружит пустое место, иногда требуется для ssd
    size         = var.os_disk_size        # Размер диск в Gb
    file_format  = var.stor_file_format # Формат файла диска (Raw сырые данные в виде блоков, QCOW2 данные пишутся в файл)
    backup       = true       # Бекапить ли данный диск через PBS
    cache        = "none"     # Включить кеш диск (Не требуется если у хоста есть свой кеш)
    replicate    = true       # Включить возможности репликации
    ssd          = false      # Включить эмуляцию SSD
  }
  disk {                      # Секция для настройки жесткого диска ВМ. Для добавления второго диска добавить еще секцию disk и увеличить счетчик интерфеса
    datastore_id = var.storage_pool # Имя хранилища. Хранилище должно быть активно на ноде, на которой создаем ВМ
    interface    = "scsi1"  # Интерфейс для подключения диска (эмуляция шины или рейд контроллера). virtio современный интерфейс.
                              # рекомендуется использовать его, если не требуется эмулировать аппаратный рейд контроллер
    iothread     = true       # Потоки ввода\вывода, нужны для искорения 
    discard      = "on"       # При включении данной опции при тонком выделении ресурсов диск будет сжиматься если обнаружит пустое место, иногда требуется для ssd
    size         = var.data_disk_size          # Размер диск в Gb
    file_format  = var.stor_file_format # Формат файла диска (Raw сырые данные в виде блоков, QCOW2 данные пишутся в файл)
    backup       = true       # Бекапить ли данный диск через PBS
    cache        = "none"     # Включить кеш диск (Не требуется если у хоста есть свой кеш)
    replicate    = true       # Включить возможности репликации
    ssd          = false      # Включить эмуляцию SSD
  }

  initialization {            # Секция для параметров Cloud-init. Добавляет в cdrom файл для облачной иницилизации. 
    interface         = "scsi2" # Интерфейс для подключения cd-rom для клауд инит файла
    datastore_id      = var.storage_pool # Хранилище для файла облачной иницилизации, обязательно должна быть включена категория контента snippets
    user_data_file_id = proxmox_virtual_environment_file.ubuntu_cloud_init[count.index].id # Переменная в которую передаем содержание файла облачной иницилизации

    dns {                     # Секция настройки DNS
      servers = ["8.8.8.8", "8.8.4.4"] # IP адреса серверов имен
      domain  = var.vm_domain # Обслуживаемый домен
    }
    ip_config {               # Секция настройки IP 
      ipv4 {                  # Настройка IPv4
        address = "${var.network}.${ var.ip_address + count.index}${var.mask}" # Адрес с указанием префикса маски, изменить на свой
        gateway = var.ip_gateway # Шлюз по умолчанию, изменить на свой
      }
    }

  }

  network_device {            # Секция для настройки сетевого адаптера
    bridge    = var.network_int  # Виртуальный сетевой интерфейс, изменить на свой 
    vlan_id   = "0"           # Тег VLAN трафика. (Тег должен быть настроен на коммутаторе)
    enabled   = true          # Включить интерфейс
    firewall  = false         # Включить Фаерволл на интерфейсе
    model     = "virtio"      # Модель интерфейса
    mtu       = 1             # Размер MTU (количество байт в пакете)
  }

  operating_system {          # Тип гостевой операционной системы
    type = "l26"              # Линукс с ядром 2.6
  }

#  keyboard_layout = "no"      # 

  lifecycle {                 # Жизненый цикл. При применении настроек треаформ приводит их к виду указано в файле состояния
    ignore_changes = [        # Игнорировать изменения. Перечислить секции через запятую
      network_device,         # Игнорировать изменения сетевого адаптера
    ]
  }

}

