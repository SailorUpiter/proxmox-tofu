# Инструкция по установке Vault
Система ubuntu 22.04
Vault 2.0.0
## Скачивание
Компания Hashicorp запретила скачивать свои продукты из России. Пользуемся ВПН или скачиваем с зеркала яндекса
```
VAULT_VERSION="2.0.0"
wget https://hashicorp-releases.yandexcloud.net/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
```
## Установка
Установим архиватор, что бы распаковать бинарник
```
sudo apt-get install -y unzip
```
Распакуем и перенесем бинарник в папку с бинарниками
```
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin/
```
Проверим что работает
```
vault --version
```
Далее нужно создать системного юзера и директории для конфигов и данных
```
adduser \
   --system \
   --shell /bin/false \
   --gecos 'Vault user' \
   --group \
   --disabled-password \
   --no-create-home \
   vault
```
```
sudo nano /etc/vault/vault.hcl
```