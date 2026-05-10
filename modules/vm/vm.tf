
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


resource "tls_private_key" "vm_ssh_key" {
  algorithm = "ED25519" 
}

# Сохраняем приватный ключ локально
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.vm_ssh_key.private_key_openssh
  filename        = var.private_key_file
  file_permission = "0600"
}

# Сохраняем публичный ключ локально
resource "local_file" "public_key" {
  content  = tls_private_key.vm_ssh_key.public_key_openssh
  filename = var.public_key_file
}


resource "proxmox_virtual_environment_file" "ubuntu_cloud_init" {
  count        = length(var.vm_hostname)
  content_type = "snippets"
  datastore_id = var.snippet_storage
  node_name    = var.node_name
  source_raw {
    data = <<-EOF
#cloud-config
hostname: ${element(var.vm_hostname, count.index)}
fqdn: ${element(var.vm_hostname, count.index)}.${var.vm_domain}
manage_etc_hosts: true

package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
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

runcmd:
    - systemctl enable qemu-guest-agent fail2ban
    - systemctl start qemu-guest-agent
    - echo "done" > /tmp/cloud-config.done
    
power_state:
    delay: now
    mode: reboot
    message: Rebooting after cloud-init completion
    condition: true

EOF
    file_name = "${element(var.vm_hostname, count.index)}.cloud-config.yaml"
  }
}
resource "proxmox_virtual_environment_vm" "template" { #описание ресурса в виде ресурс "вид ресурса" "название"
  count       = length(var.vm_hostname)          # Счетчик цикла. Цикл используется для создания сразу нескольких ВМ
  name        = element(var.vm_hostname, count.index)   # Имя виртуальной машины
  bios        = var.bios
  node_name   = var.node_name # Имя ноды на которой будет развернута ВМ
  scsi_hardware = "virtio-scsi-single"
  cpu {                       # Секция для настроек ЦПУ
    cores      = var.cpu_num            # Количество виртуальных ядер (vCPU)
    sockets    = 1            # Количество сокетов для процессора
    type       = "x86-64-v2-AES"  # Указываем тип процессора. При значении host используем хостовой проц, а не эмулируем его
  }
  memory {                    # Секция для настроек оперативной памяти
    dedicated = var.memory_mb         # Количество выделяемой памяти в Mb
  }
  agent {                     # Секция кему агента. Кему агент позволяет более тесно взаимодействовать ВМ и хосту
    enabled = true
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
    size         = var.os_disk_size        # Размер диск в Gb
    file_format  = var.stor_file_format # Формат файла диска (Raw сырые данные в виде блоков, QCOW2 данные пишутся в файл)
  }
  disk {                      # Секция для настройки жесткого диска ВМ. Для добавления второго диска добавить еще секцию disk и увеличить счетчик интерфеса
    datastore_id = var.storage_pool # Имя хранилища. Хранилище должно быть активно на ноде, на которой создаем ВМ
    interface    = "scsi1"  # Интерфейс для подключения диска (эмуляция шины или рейд контроллера). virtio современный интерфейс.
    size         = var.data_disk_size          # Размер диск в Gb
    file_format  = var.stor_file_format # Формат файла диска (Raw сырые данные в виде блоков, QCOW2 данные пишутся в файл)
  }
  initialization {            # Секция для параметров Cloud-init. Добавляет в cdrom файл для облачной иницилизации. 
    interface         = "scsi2" # Интерфейс для подключения cd-rom для клауд инит файла
    datastore_id      = var.storage_pool # Хранилище для файла облачной иницилизации, обязательно должна быть включена категория контента snippets
    user_data_file_id = proxmox_virtual_environment_file.ubuntu_cloud_init[count.index].id # Переменная в которую передаем содержание файла облачной иницилизации
    dns {                     # Секция настройки DNS
      servers = var.dns_servers # IP адреса серверов имен
      domain  = var.vm_domain # Обслуживаемый домен
    }
    ip_config {               # Секция настройки IP 
      ipv4 {                  # Настройка IPv4
        address = element(var.ip_addr, count.index) # Адрес с указанием префикса маски, изменить на свой
        gateway = var.ip_gateway # Шлюз по умолчанию, изменить на свой
      }
    }
  }
  network_device {            # Секция для настройки сетевого адаптера
    bridge    = var.network_int  # Виртуальный сетевой интерфейс, изменить на свой 
  }
  lifecycle {                 # Жизненый цикл. При применении настроек треаформ приводит их к виду указано в файле состояния
    ignore_changes = [        # Игнорировать изменения. Перечислить секции через запятую
      network_device,         # Игнорировать изменения сетевого адаптера
    ]
  }

}

