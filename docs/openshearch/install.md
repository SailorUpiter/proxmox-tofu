# Установка Opensearch
Ссылка на офф доку https://docs.opensearch.org/latest/install-and-configure/install-opensearch/tar/
Установка опенсерча производится из архива. 
Стендэлон
Подготавливаем ноду для установки. Все это дело работает на джаве. И хоть в архиве опенсерча уже есть жаба лучше поставить ее прямо на машину, что бы было проще работать
```
sudo apt update && sudo apt upgrade -y
sudo apt install -y openjdk-25-jdk
```
Отключим свап и настроем виртуальную память хоста
```
sudo vim /etc/sysctl.conf

vm.max_map_count=262144

sudo sysctl -p
cat /proc/sys/vm/max_map_count
```
После обновления и установки жабы, лучше всего перезагрузится. Далее мы качаем архив с опенсерчем с оффсайта 
```
wget https://artifacts.opensearch.org/releases/bundle/opensearch/3.6.0/opensearch-3.6.0-linux-x64.deb
sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD=5ruXurur! dpkg -i opensearch-3.6.0-linux-x64.deb
sudo systemctl enable opensearch
```

Выполним скрипт ssl.sh (лежит в доке как пример) для создания самоподписанных сертификатов и хранилища сертификатов. СОздадутся корневой сертификат ЦА. Так же создастся на его основе админский сертификат и сертификаты для каждой ноды. Это нужно что бы общение между нодами и дашбордой были зашифрованы. Так же выпустится админский серт для зашифрованного подключения админа.
После завершения подготовки требуется нарисовать кофниг. Конфиг имеет формат YAML и различается в зависимости от кластера или стендэлон опенсерча


 mv /etc/opensearch/opensearch.yml /etc/opensearch/opensearch.yml.back

 rm /etc/opensearch/*.pem

vim /etc/opensearch/opensearch.yml

systemctl start opensearch


wget https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/3.6.0/opensearch-dashboards-3.6.0-linux-x64.deb

$2y$12$7.7YOQi6.CEN1VSNXg3BqefgQLEeqDbsqxNBNhY1tgZ085q1eZeCK
