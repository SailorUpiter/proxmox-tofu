# Нструкция по установке Gitea
Примитивная инструкция по установке gitea.
Ссылка на официальную документацию https://docs.gitea.com/next/installation/install-from-binary
Требования и версии
Ubuntu 22.04
postgresql 17.9
gitea main-nightly ( 1.27.0)
git => 2.0
## Подготовка базы
Установим и настроем базу данных postgresql
1) Добавим репозиторий и ключ
```
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo apt update

```
2) Установим postgresql, запустим и добавим в автозагрузку
```
sudo apt install postgresql-17
sudo systemctl start postgresql
sudo systemctl enable postgresql

```
3) Настроим файл postgesql.conf для подключения. Файл лежит /etc/postgresql/17/main/postgresql.conf (17 это версия postgesql)
Если сторка закоментирована, то раскоментировать и добавить адрес сервера на котором будет развернута gitea
```
listen_addresses = 'localhost, 203.0.113.3' 
```
4) Создадим юзера для БД. Для создания нового юзера надо подключится к Субд под дефолтным юзером postges. После ROLE идет имя юзера. Требуется заменить дефолтные на свои.
```
su -c "psql" - postgres
CREATE ROLE gitea WITH LOGIN PASSWORD 'gitea';
```
5) Создадим БД для gitea. Владельцем базы назначим свежесозданного юзера. Кодировка базы UTF8. Сменить имя базы на свою
```
CREATE DATABASE giteadb WITH OWNER gitea TEMPLATE template0 ENCODING UTF8 LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';
```
1) Разрешим подключаться к базе пользователю к созданной выше базе данных, добавив следующее правило аутентификации в pg_hba.conf. Файл лежит /etc/postgresql/17/main/
```
local    giteadb    gitea    scram-sha-256 #Для локальной базы данных
host    giteadb    gitea    192.0.2.10/32    scram-sha-256 #Для удаленной базы данных
```
1) На сервере Gitea проверим подключение к базе данных.

Для локальной базы данных:
```
psql -U gitea -d giteadb
```
Для удаленной базы данных:
```
psql "postgres://gitea@203.0.113.3/giteadb"
```
## Установка 
1) Обновим систему
```
sudo apt update && sudo apt upgrade -y
```
2) Скачаем бинарник и выдадим ему права на исполнение. 
```
wget -O gitea https://dl.gitea.com/gitea/main-nightly/gitea-main-nightly-linux-amd64

```
```
sudo chmod gitea
```
3) Проверим подпись бинарника. В репозитории есть GPG ключ.
```
gpg --keyserver hkps://keys.openpgp.org --recv 7C9E68152594688862D62AF62D9AE806EC1592E2
wget https://dl.gitea.com/gitea/main-nightly/gitea-main-nightly-linux-386.asc
gpg --verify gitea-main-nightly-linux-amd64.asc gitea-main-nightly-linux-amd64
```
4) НА сервере должен быть установлен git версии => 2.0. Убедимся что git подходящей версии
```
git --version
```
5) Добавим локального юзера для запуска gitea.
```
adduser \
   --system \
   --shell /bin/false \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/git \
   gitea
```
1) Создадим необходимые для работы директории и выдадим созданному юзеру права на них. Права 770 на директорию /etc/gitea выдаются только для первоначальной настройки. 
```
mkdir -p /mnt/data/gitea/{custom,data,log}
chown -R gitea:gitea /mnt/data/gitea/
chmod -R 750 /mnt/data/gitea/
mkdir /etc/gitea
chown root:gitea /etc/gitea
chmod 770 /etc/gitea
```
1) Создадим системный юнит для запуска gitea как сервиса systemd. Создадим файл юнита по пути /etc/systemd/system/gitea.service
Добавим конфиг юнита
```
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target
Wants=postgresql.service
After=postgresql.service
[Service]
# Uncomment the next line if you have repos with lots of files and get a HTTP 500 error because of that
# LimitNOFILE=524288:524288
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
[Install]
WantedBy=multi-user.target
```
Перечитаем список юнитов
```
sudo systemctl daemon-reload
```
Запустим gitea
```
sudo systemctl enable gitea --now
```
## Первоначальная настройка
1) Для первоначальной настройки нужно зайти по адресу нашего сервера на порте 3000
http://ip-addr-or-fqdn:3000/
Откроется веб странциа первоначальной настройки, где нужно:
1) указать юзера, пароль и БД, которую мы будем использовать. 
2) Указать домен и URl сервера
3) Зарегестрировать администратора. 
Если забудем логи\пароль админа, то его можно сменить через консоль сервера
```
gitea admin user change-password --username user --password password --config /etc/gitea/app.ini:
```
4) Так же стоит запретить самостоятельную регистрацию на сервер
После первоначальной настройки меняем права на директорию /etc/gitea на 750
```
chmod 750 /etc/gitea
```
