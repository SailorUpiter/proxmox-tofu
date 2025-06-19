
resource "proxmox_virtual_environment_vm" "template" { #описание ресурса в виде ресурс "вид ресурса" "название"
  count       = 1             # Счетчик цикла. Цикл используется для создания сразу нескольких ВМ
  name        = var.vm_hostname   # Имя виртуальной машины
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
    file_id      = "${var.image_storage}:iso/jammy-server-cloudimg-amd64.img" # ИСО файл для установки ОС (облачной конфигурации). Должен лежать на локальном хранилище.
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
    user_data_file_id = proxmox_virtual_environment_file.ubuntu_cloud_init.id # Переменная в которую передаем содержание файла облачной иницилизации

    dns {                     # Секция настройки DNS
      servers = ["8.8.8.8", "8.8.4.4"] # IP адреса серверов имен
      domain  = var.vm_domain # Обслуживаемый домен
    }
    ip_config {               # Секция настройки IP 
      ipv4 {                  # Настройка IPv4
        address = var.ip_address # Адрес с указанием префикса маски, изменить на свой
        gateway = var.ip_gateway # Шлюз по умолчанию, изменить на свой
      }
    }

  }

  network_device {            # Секция для настройки сетевого адаптера
    bridge    = "vmbr0"       # Виртуальный сетевой интерфейс, изменить на свой 
    vlan_id   = "0"           # Тег VLAN трафика. (Тег должен быть настроен на коммутаторе)
    enabled   = true          # Включить интерфейс
    firewall  = false         # Включить Фаерволл на интерфейсе
    model     = "virtio"      # Модель интерфейса
    mtu       = 0             # Размер MTU (количество байт в пакете)
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