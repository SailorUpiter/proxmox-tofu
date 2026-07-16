# NPM
Краткая инструкция как поднять и настроить NPM
Ссылки
Гайд с оф сайта https://nginxproxymanager.com/guide/
Гитхаб https://github.com/NginxProxyManager/nginx-proxy-manager
Для начала заходим на сервак и ставим докер. 
```
curl https://get.docker.com | sh -
```
Далее создаем директорию под NPM. Директорию лучше не называть npm, что бы не путать с пакетным менджером
```
mkdir proxy && cd proxy
```
Создаем compose.yaml
```
nano compose.yaml
```
И записываем туда конфиг для композа
```
services:
  app:
    image: 'jc21/nginx-proxy-manager:2.15.1' #Можно посмотреть севужую версию на https://github.com/NginxProxyManager/nginx-proxy-manager
    restart: unless-stopped
    environment:
      TZ: "Europe/Moscow"
    ports:
      - '80:80'
      - '81:81' #Порт веб панели администратора, лучше поменять на свой
      - '443:443'
    volumes: #Директории для сертов и данных, создадутся в рабочем каталоге
      - ./data:/data 
      - ./letsencrypt:/etc/letsencrypt
```
Разрешаем трафик по этим портам
```
sudo iptables -A INPUT -p tcp -i eth0 --dport 80,443,81 -j ACCEPT
```
Поднимаем контейнер композом
```
docker compose up -d
```
Заходим в вебку админа по ip-server:81 и настраиваем учетку и тд.