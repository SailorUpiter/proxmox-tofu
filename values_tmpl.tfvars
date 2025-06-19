# bgp-example/proxmox.tfvars
## Host settings
tenant                      = "Trustinfo"
cluster_name                = "pve-cluster"
node_name                   = "server-name"  # Имя сервера на котором развернется ВМ
pve_api_url                 = "https://ip-address:8006/api2/json" # Адрес Апи сервера 
pve_token_id                = "root@pam!tofu" # Пользователь на которого выдаем токен для доступа к апи
pve_token_secret            = "token" # Сам токен для доступа
storage_pool                = "nfs-stor" # Хранилище где создаться ВМ
snippet_storage             = "local" # Хранилище куда записывается файл содержащий клауд конфиг. По умолчанию локальный диск. 
                                      #Для этого в датацентре должна быть включена возможность записи Snippets
image_storage               = "nfs-stor" #Хранилище которое содержит имедж виртуальной машины, который копируется в новый диск вм.
## VM settings
#vm_id                       = "100" # ID виртуальной машины. ДОЛЖЕН БЫТЬ УНИКАЛЬНЫМ!!!! ОБЯЗАТЕЛЬНО ИЗМЕНИТЬ ЕГО ПЕРЕД ПРИМЕНЕНИЕМ КОНФИГУРАЦИИ!!!!!
vm_hostname                 = "template" # Имя виртуальной машины
vm_domain                   = "example.com" # Домен виртуальной машины, нужен для FQDN и DNSы
stor_file_format            = "raw" # Формат файла виртуального жесткого диска. Возможные значения raw/qcow2
bios                        = "ovmf" # UEFI или BIOS. Возможные значения seabios/ovmf
cpu_num                     = "4" #Количество виртуальных ядер процессора
memory_mb                   = "8192" #Количество оперативной памяти
os_disk_size                = "20" # Размер диска в Gb. Для операционной системы
data_disk_size              = "20" # Размер диска в Gb Для данных
ip_address                  = "ip address CIDR\mask" # Ip адрес виртуальной машины.
ip_gateway                  = "Default gateway CIDR" # Адрес шлюза по умолчанию
ci_ssh_port                 = "22" # Порт для подключения SSH

#Cloud-init settings
cloud_init_user             = "ubadmin"  # Имя юзера которого создаст клауд инит.
cloud_init_user_password    = "Password hash" # Хеш пароля для юзера по умолчанию.
#Для хеширования пароля требуется пакет mkpasswd
#Команда для хешировани mkpasswd -m sha-512
ci_ssh_key                  = "/home/ubadmin/.ssh/id_ed25519.pub" # Файл в котором храниться публичный ключ для доступа к ВМ

#Netbox
netbox_api_url = "http://ip-addr-netbox-server:8000/"
netbox_token_secret = "netbox-token"
