# Альтернативный registry
Есть 2 ситуации когда нужен альтернативный реджистри докера:
1) требуется качать свое приложение из своего регистри
2) Докерхаб не доступен\ограничено кол-во скачиваний\санкции
Для решение этих проблем мы можем в конфиг файле докера указать альтернативный регистри. Данная инструкция для обычной установки докера. Если докер рутлесс, то команды будут иными
- Открываем или создаем, если нет, файл по пути
```
nano /etc/docker/daemon.json
```
- Редактируем или вставляем в свежий файл конфиг. В данном случае используется зеркало таймвеба. Ниже будет список альтернативныйх зеркал
```
{ 
"registry-mirrors" : [ "https://dockerhub.timeweb.cloud" ]
}
```
- Перезапускаем демон докера
```
systemctl reload docker
```
# Список альтернативных зеркал
Адрес реестра Компания-владелец
https://mirror.gcr.io Google
https://public.ecr.aws Amazon
https://dockerhub.timeweb.cloud Timeweb Cloud
https://dh-mirror.gitverse.ru GitVerse (СберБанк)
https://dockerhub1.beget.com Beget
https://quay.io Red Hat
https://registry.access.redhat.com Red Hat
https://registry.redhat.io Red Hat