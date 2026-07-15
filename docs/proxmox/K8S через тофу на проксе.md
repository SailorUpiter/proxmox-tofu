Сделаю наверное перевод с дополнениями

В этом посте я буду использовать следующие продукты:

- Proxmox - [домашняя страница](https://www.proxmox.com/en/)
- Ubuntu - [домашняя страница](https://ubuntu.com/)
- OpenTofu - [домашняя страница](https://opentofu.org/)
- поставщик terraform для bpg/proxmox — [реестр](https://registry.terraform.io/providers/bpg/proxmox/latest) и [github](https://github.com/bpg/terraform-provider-proxmox)
- Ansible - [домашняя страница](https://www.ansible.com/community)
- Kubespray - [домашняя страница](https://kubespray.io/#/) и [github](https://github.com/kubernetes-sigs/kubespray/tree/master)

### Установить OpenTofu

Чтобы начать работу с OpenTofu, я установил его на свой компьютер с Linux с помощью Snap, но есть и несколько других альтернатив. Подробнее см. на официальной странице [документации](https://opentofu.org/docs/intro/install/snap) OpenTofu.

```bash
sudo snap install --classic opentofu
```

Теперь OpenTofu установлен, и я могу начать его использовать. Я также установил автозаполнение bash следующим образом:

```bash
tofu -install-autocomplete # restart shell session...
```

Я решил создать отдельную папку для своих «проектов», поэтому я создал папку в своей домашней папке под названием *tofu/proxmox, в которой у меня есть разные подпапки в зависимости от задач или ресурсов, для которых я буду использовать OpenTofu.

```bash
tofu/proxmox/
├── k8s-cluster-02
├── proxmox-images
```

## Сетевое зеркало реестра провайдеров terraform

Так как реестры и тераформ заблокированы для РФ требуется использовать пути обхода.
Для использования зеркала добавьте в [файл настроек terraform](https://www.terraform.io/cli/config/config-file) следующий код:

```

provider_installation {
  network_mirror {
    url     = "https://nm.tf.org.ru/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
        
```

- В Windows файл должен называться `terraform.rc` и находиться в каталоге `%APPDATA%` соответствующего пользователя. Расположение каталога зависит от версии Windows. Чтобы найти этот каталог в своей системе используйте `$env:APPDATA` в PowerShell.
- В остальных системах файл должен называться `.terraformrc` и находиться в домашнем каталоге пользователя. (/home/ubadmin)
## Другие сайты
## Зеркала реестров
- [registry.comcloud.xyz](https://registry.comcloud.xyz/)
- [terraform-mirror.yandexcloud.net](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#configure-provider)
## Зеркала релизов
- [hashicorp-releases.website.yandexcloud.net](https://hashicorp-releases.website.yandexcloud.net/terraform/)
- [hc-mirror.express42.net](https://hc-mirror.express42.net/)
- [releases.comcloud.xyz](https://releases.comcloud.xyz/)
## Документация
- [docs.comcloud.xyz](https://docs.comcloud.xyz/)

### Провайдер OpenTofu Proxmox

Чтобы использовать OpenTofu с Proxmox, мне нужен провайдер, который может использовать API Proxmox. Я быстро изучил различные варианты и остановился на этом провайдере: [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox). Он кажется очень активным и недавно обновлялся (согласно репозиторию git [здесь](https://github.com/bpg/terraform-provider-proxmox))

Поставщик OpenTofu/Terraform определяется следующим образом, а приведенный ниже пример настраивает установку поставщика bpg/proxmox, необходимого для взаимодействия с Proxmox.
terraform {

```
  required_providers {
    proxmox = {
      source = "registry.terraform.io/bpg/proxmox"
    }
    local = {
      source = "registry.terraform.io/hashicorp/local"
    }
    null = {
      source = "registry.terraform.io/hashicorp/null"
    }
    time = {
      source = "registry.terraform.io/hashicorp/time"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_api_url
  api_token = "${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = true
  ssh {
    agent    = true
    username = "root"
  }
}
```

Я сохраню это содержимое в файле под названием _providers.tf_
Сначала краткое объяснение двух разделов выше. Разделы _terraform_ указывают OpenTofu/Terraform, какой провайдер следует загрузить и включить. Поле _version_ определяет конкретную версию для использования, а не _последнюю_, а именно эту версию. Использование этого поля гарантирует, что ваша автоматизация не сломается, если в версии провайдера произойдут какие-либо изменения в API.
Раздел _provider_ настраивает взаимодействие прокси-провайдера с Proxmox. Вместо обычного имени пользователя и пароля я решил использовать токен API. Здесь я использую значение переменной в ключах endpoint и api-token, которые определены в другом файле под названием variables.tf и credentials.auto.tfvars. В моей системе автоматизации есть задачи, для которых требуется взаимодействие с Proxmox по SSH, поэтому я также включил его, настроив поле _ssh_.

Для получения дополнительной информации о провайдере bpg/proxmox перейдите [сюда](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
### Подготовьте Proxmox с помощью токена API для поставщика OpenTofu bpg/proxmox

Чтобы использовать описанный выше провайдер с Proxmox, мне нужно подготовить Proxmox для использования токена API. Я следовал документации провайдера bpg/proxmox [здесь](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication)

```
# Create the user
sudo pveum user add terraform@pve

# Create a role for the user above
sudo pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt User.Modify"

# Assign the terraform user to the above role
sudo pveum aclmod / -user terraform@pve -role Terraform

# Create the token
sudo pveum user token add terraform@pve provider --privsep=0

┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ terraform@pve!provider               │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":"0"}                      │
├──────────────┼──────────────────────────────────────┤
│ value        │ <token>                               │
└──────────────┴──────────────────────────────────────┘
# make a backup of the token
    

```

Теперь я могу войти в свой узел Proxmox по SSH без пароля с моего Linux-шлюза. Но при использовании в сочетании с opentofu этого недостаточно. Мне нужно загрузить ключ в хранилище ключей. Если я этого не сделаю, автоматизация, требующая доступа по SSH, завершится ошибкой с этим сообщением:
```bash
Error: failed to open SSH client: unable to authenticate user "root" over SSH to "172.18.5.102:22". Please verify that ssh-agent is correctly loaded with an authorized key via 'ssh-add -L' (NOTE: configurations in ~/.ssh/config are not considered by golang's ssh implementation). The exact error from ssh.Dial: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none password], no supported methods remain
```
Для того что бы избавиться от ошибки нужно выполнить команды в терминале:
```
eval `ssh-agent -s`
ssh-add /home/ubadmin/.ssh/id_ed25519
```
