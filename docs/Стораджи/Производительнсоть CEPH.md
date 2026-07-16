
[Открыть главное меню](https://yourcmc.ru/wiki/%D0%A1%D0%BB%D1%83%D0%B6%D0%B5%D0%B1%D0%BD%D0%B0%D1%8F:%D0%9C%D0%BE%D0%B1%D0%B8%D0%BB%D1%8C%D0%BD%D0%BE%D0%B5_%D0%BC%D0%B5%D0%BD%D1%8E "Открыть главное меню")

- Наблюдать за этой страницей

# Производительность Ceph

Ссылки сюда (2) →

[![Ceph-funnel.svg](https://yourcmc.ru/wiki/images/3/39/Ceph-funnel.svg)](https://yourcmc.ru/wiki/%D0%A4%D0%B0%D0%B9%D0%BB:Ceph-funnel.svg)

Ceph — это SDS (по-русски — программная СХД), которая по некоторым параметрам является уникальной в своём роде, и в целом, умеет очень многое — S3, диски виртуалок, кластерную FS + огромный багаж дополнительных фич.

И всё было бы хорошо — бери, ставь, запускай своё облако и руби бабло — если бы не один маленький нюанс: ПРОИЗВОДИТЕЛЬНОСТЬ. Терять 95 % производительности в Production-е разумным людям обычно жалко. «Облакам» типа AWS, GCP, Яндекса, по-видимому, не жалко — у них тоже собственные крафтовые SDS и они тоже тормозят примерно так же :-) но этот вопрос оставим — кто мы такие, чтобы их судить.

В данной статье описано, каких показателей производительности можно добиться от цефа и как. Если вкратце, то примерным ориентиром служит доклад Nick Fisk «Low-Latency Ceph», в его исполнении Low Latency это 0.7 мс (на запись). Лучший результат с Ceph-ом получить практически невозможно (худший — легко). При этом 0.7 мс — это всего лишь примерно ~1500 iops в 1 поток. На чтение в идеальной ситуации можно получить где-то раза в 2 больше, то есть где-то до 3000 iops в 1 поток.

Для сравнения: любой самый дешёвый серверный SSD-диск раз в 10 быстрее, средний порядок задержки SSD на запись — 0.01-0.04 мс, на чтение — 0.1 мс.

**UPDATE: Догнать (почти догнать) SDS-кой локальной диск можно, я это сделал в своём собственном проекте — Vitastor: [https://vitastor.io](https://vitastor.io/) :-) это блочная SDS с архитектурой, похожей на Ceph, но при этом БЫСТРАЯ — в тесте на SATA SSD кластере задержка и чтения, и записи составила 0.14 мс. На том же кластере задержка записи у Ceph была 1 мс, а чтения — 0.57 мс. Детали в [README](https://yourcmc.ru/git/vitalif/vitastor/src/branch/master/README.md) — смотрите по ссылке.**

## 

Содержание

- [Бенчмаркинг](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.91.D0.B5.D0.BD.D1.87.D0.BC.D0.B0.D1.80.D0.BA.D0.B8.D0.BD.D0.B3)
    - [Тестирование дисков](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A2.D0.B5.D1.81.D1.82.D0.B8.D1.80.D0.BE.D0.B2.D0.B0.D0.BD.D0.B8.D0.B5_.D0.B4.D0.B8.D1.81.D0.BA.D0.BE.D0.B2)
        - [Лирическое отступление](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9B.D0.B8.D1.80.D0.B8.D1.87.D0.B5.D1.81.D0.BA.D0.BE.D0.B5_.D0.BE.D1.82.D1.81.D1.82.D1.83.D0.BF.D0.BB.D0.B5.D0.BD.D0.B8.D0.B5)
            
    - [Тестирование кластера Ceph](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A2.D0.B5.D1.81.D1.82.D0.B8.D1.80.D0.BE.D0.B2.D0.B0.D0.BD.D0.B8.D0.B5_.D0.BA.D0.BB.D0.B0.D1.81.D1.82.D0.B5.D1.80.D0.B0_Ceph)
        - [RBD](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#RBD)
            
        - [Отдельные OSD](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9E.D1.82.D0.B4.D0.B5.D0.BB.D1.8C.D0.BD.D1.8B.D0.B5_OSD)
            
        - [CephFS](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#CephFS)
            
        - [S3 (rgw)](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#S3_.28rgw.29)
            
        - [Что использовать не надо](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A7.D1.82.D0.BE_.D0.B8.D1.81.D0.BF.D0.BE.D0.BB.D1.8C.D0.B7.D0.BE.D0.B2.D0.B0.D1.82.D1.8C_.D0.BD.D0.B5_.D0.BD.D0.B0.D0.B4.D0.BE)
            
        - [Про RBD и параллелизм](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.BE_RBD_.D0.B8_.D0.BF.D0.B0.D1.80.D0.B0.D0.BB.D0.BB.D0.B5.D0.BB.D0.B8.D0.B7.D0.BC)
            
    - [Тестирование сети](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A2.D0.B5.D1.81.D1.82.D0.B8.D1.80.D0.BE.D0.B2.D0.B0.D0.BD.D0.B8.D0.B5_.D1.81.D0.B5.D1.82.D0.B8)
        
- [О транзакционности записи](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9E_.D1.82.D1.80.D0.B0.D0.BD.D0.B7.D0.B0.D0.BA.D1.86.D0.B8.D0.BE.D0.BD.D0.BD.D0.BE.D1.81.D1.82.D0.B8_.D0.B7.D0.B0.D0.BF.D0.B8.D1.81.D0.B8)
    
- [Конденсаторы](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9A.D0.BE.D0.BD.D0.B4.D0.B5.D0.BD.D1.81.D0.B0.D1.82.D0.BE.D1.80.D1.8B)
    
- [Bluestore vs Filestore](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#Bluestore_vs_Filestore)
    - [Тест на 1 NVMe](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A2.D0.B5.D1.81.D1.82_.D0.BD.D0.B0_1_NVMe)
        
    - [Про размер block.db](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.BE_.D1.80.D0.B0.D0.B7.D0.BC.D0.B5.D1.80_block.db)
        
- [RGW vs Minio](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#RGW_vs_Minio)
    
- [Снапшоты](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A1.D0.BD.D0.B0.D0.BF.D1.88.D0.BE.D1.82.D1.8B)
    
- [EC](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#EC)
    - [Про вероятность потери данных](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.BE_.D0.B2.D0.B5.D1.80.D0.BE.D1.8F.D1.82.D0.BD.D0.BE.D1.81.D1.82.D1.8C_.D0.BF.D0.BE.D1.82.D0.B5.D1.80.D0.B8_.D0.B4.D0.B0.D0.BD.D0.BD.D1.8B.D1.85)
        
- [Контроллеры](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9A.D0.BE.D0.BD.D1.82.D1.80.D0.BE.D0.BB.D0.BB.D0.B5.D1.80.D1.8B)
    
- [Процессоры](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.BE.D1.86.D0.B5.D1.81.D1.81.D0.BE.D1.80.D1.8B)
    
- [Сеть](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A1.D0.B5.D1.82.D1.8C)
    
- [Настройка виртуалок и ФС](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9D.D0.B0.D1.81.D1.82.D1.80.D0.BE.D0.B9.D0.BA.D0.B0_.D0.B2.D0.B8.D1.80.D1.82.D1.83.D0.B0.D0.BB.D0.BE.D0.BA_.D0.B8_.D0.A4.D0.A1)
    - [Драйвер виртуального диска и ФС](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.94.D1.80.D0.B0.D0.B9.D0.B2.D0.B5.D1.80_.D0.B2.D0.B8.D1.80.D1.82.D1.83.D0.B0.D0.BB.D1.8C.D0.BD.D0.BE.D0.B3.D0.BE_.D0.B4.D0.B8.D1.81.D0.BA.D0.B0_.D0.B8_.D0.A4.D0.A1)
        
    - [cache=writeback](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#cache.3Dwriteback)
        
    - [ФС](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A4.D0.A1)
        
- [Оценка производительности кластера](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9E.D1.86.D0.B5.D0.BD.D0.BA.D0.B0_.D0.BF.D1.80.D0.BE.D0.B8.D0.B7.D0.B2.D0.BE.D0.B4.D0.B8.D1.82.D0.B5.D0.BB.D1.8C.D0.BD.D0.BE.D1.81.D1.82.D0.B8_.D0.BA.D0.BB.D0.B0.D1.81.D1.82.D0.B5.D1.80.D0.B0)
    
- [Картина маслом «Тормозящий кэш»](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9A.D0.B0.D1.80.D1.82.D0.B8.D0.BD.D0.B0_.D0.BC.D0.B0.D1.81.D0.BB.D0.BE.D0.BC_.C2.AB.D0.A2.D0.BE.D1.80.D0.BC.D0.BE.D0.B7.D1.8F.D1.89.D0.B8.D0.B9_.D0.BA.D1.8D.D1.88.C2.BB)
    - [O_SYNC vs fsync vs hdparm -W 0](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#O_SYNC_vs_fsync_vs_hdparm_-W_0)
        
    - [Серверные SSD](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A1.D0.B5.D1.80.D0.B2.D0.B5.D1.80.D0.BD.D1.8B.D0.B5_SSD)
        
    - [Ceph HDD+SSD](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#Ceph_HDD.2BSSD)
        - [Примечания](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.B8.D0.BC.D0.B5.D1.87.D0.B0.D0.BD.D0.B8.D1.8F)
            
- [Почему вообще Bluestore такой медленный?](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D0.BE.D1.87.D0.B5.D0.BC.D1.83_.D0.B2.D0.BE.D0.BE.D0.B1.D1.89.D0.B5_Bluestore_.D1.82.D0.B0.D0.BA.D0.BE.D0.B9_.D0.BC.D0.B5.D0.B4.D0.BB.D0.B5.D0.BD.D0.BD.D1.8B.D0.B9.3F)
    
- [DPDK и SPDK](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#DPDK_.D0.B8_SPDK)
    
- [RAID WRITE HOLE](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#RAID_WRITE_HOLE)
    
- [Краткий экскурс в устройство SSD и флеш-памяти](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9A.D1.80.D0.B0.D1.82.D0.BA.D0.B8.D0.B9_.D1.8D.D0.BA.D1.81.D0.BA.D1.83.D1.80.D1.81_.D0.B2_.D1.83.D1.81.D1.82.D1.80.D0.BE.D0.B9.D1.81.D1.82.D0.B2.D0.BE_SSD_.D0.B8_.D1.84.D0.BB.D0.B5.D1.88-.D0.BF.D0.B0.D0.BC.D1.8F.D1.82.D0.B8)
    - [Бонус: USB-флешки](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.91.D0.BE.D0.BD.D1.83.D1.81:_USB-.D1.84.D0.BB.D0.B5.D1.88.D0.BA.D0.B8)
        
- [Пример теста от Micron](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.B8.D0.BC.D0.B5.D1.80_.D1.82.D0.B5.D1.81.D1.82.D0.B0_.D0.BE.D1.82_Micron)
    - [Апдейт](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.90.D0.BF.D0.B4.D0.B5.D0.B9.D1.82)
        
    - [Бонус: висян (vSAN)](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.91.D0.BE.D0.BD.D1.83.D1.81:_.D0.B2.D0.B8.D1.81.D1.8F.D0.BD_.28vSAN.29)
        
- [Модели](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9C.D0.BE.D0.B4.D0.B5.D0.BB.D0.B8)
    
- [Резюме](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A0.D0.B5.D0.B7.D1.8E.D0.BC.D0.B5)
    
- [Примечание](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9F.D1.80.D0.B8.D0.BC.D0.B5.D1.87.D0.B0.D0.BD.D0.B8.D0.B5)
    
- [См. также](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A1.D0.BC._.D1.82.D0.B0.D0.BA.D0.B6.D0.B5)
    
- [Советы лучших собаководов](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.A1.D0.BE.D0.B2.D0.B5.D1.82.D1.8B_.D0.BB.D1.83.D1.87.D1.88.D0.B8.D1.85_.D1.81.D0.BE.D0.B1.D0.B0.D0.BA.D0.BE.D0.B2.D0.BE.D0.B4.D0.BE.D0.B2)
    

## 

Бенчмаркинг

Основные направления тестирования:

- Линейное чтение/запись (большими блоками)
- Пиковая производительность высоко-параллельного случайного чтения/записи мелкими блоками
- Задержка однопоточного случайного чтения мелкими блоками (4-8 Кб)
- Задержка однопоточной транзакционной записи мелкими блоками (4-8 Кб) — обычно последовательной, как в журнал СУБД, но в один поток это обычно слабо отличается от случайной

Задержки обычно важнее простой пиковой производительности случайного чтения/записи, так как далеко не каждое приложение может загрузить диск при большом параллелизме / глубокой очереди (32-128 запросов).

### Тестирование дисков

[SSD Bench Google Docs](https://docs.google.com/spreadsheets/d/1E9-eXjzsKboiCCX-0u0r5fAjjufLKayaut_FOPxYZjc)

Сначала прогоните fio на голом диске:

![Warning icon.svg](https://yourcmc.ru/wiki/images/2/24/Warning_icon.svg) ВНИМАНИЕ! Для тех, кто в танке — fio-тест записи на диск ДЕСТРУКТИВНЫЙ. Не вздумайте запускать его на дисках/разделах, на которых есть нужные данные… например, журналы OSD (был прецедент).

- Перед тестированием попробуйте отключить кэш записи диска: hdparm -W 0 /dev/sdX (SATA-диски через SATA или HBA), sdparm --set WCE=0 /dev/sdX (SAS-диски). Не совсем ясно, почему, но эта операция на серверных SSD может увеличить IOPS-ы на 2 порядка (а может НЕ увеличить, поэтому пробуйте оба варианта — и W0, и W1). Также см.ниже [#Картина маслом «Тормозящий кэш»](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#.D0.9A.D0.B0.D1.80.D1.82.D0.B8.D0.BD.D0.B0_.D0.BC.D0.B0.D1.81.D0.BB.D0.BE.D0.BC_.C2.AB.D0.A2.D0.BE.D1.80.D0.BC.D0.BE.D0.B7.D1.8F.D1.89.D0.B8.D0.B9_.D0.BA.D1.8D.D1.88.C2.BB).
- Линейное чтение: fio -ioengine=libaio -direct=1 -invalidate=1 -name=test -bs=4M -iodepth=32 -rw=read -runtime=60 -filename=/dev/sdX
- Линейная запись: fio -ioengine=libaio -direct=1 -invalidate=1 -name=test -bs=4M -iodepth=32 -rw=write -runtime=60 -filename=/dev/sdX
- Пиковые IOPS случайного чтения: fio -ioengine=libaio -direct=1 -invalidate=1 -name=test -bs=4k -iodepth=128 -rw=randread -runtime=60 -filename=/dev/sdX
- Задержка случайного чтения: fio -ioengine=libaio -sync=1 -direct=1 -invalidate=1 -name=test -bs=4k -iodepth=1 -rw=randread -runtime=60 -filename=/dev/sdX
- Пиковые IOPS случайной записи: fio -ioengine=libaio -direct=1 -invalidate=1 -name=test -bs=4k -iodepth=128 -rw=randwrite -runtime=60 -filename=/dev/sdX
- Задержка записи в журнал: fio -ioengine=libaio -sync=1 -direct=1 -invalidate=1 -name=test -bs=4k -iodepth=1 -rw=write -runtime=60 -filename=/dev/sdX — также стоит повторить тот же тест с -fsync=1 вместо -sync=1 и принять худший результат, так как иногда бывает, что одним из методов sync игнорируется (зависит от контроллера).
- Задержка случайной записи: fio -ioengine=libaio -sync=1 -direct=1 -invalidate=1 -name=test -bs=4k -iodepth=1 -rw=randwrite -runtime=60 -filename=/dev/sdX

«А почему так мало…» — см.ниже сагу про конденсаторы.

![Warning icon.svg](https://yourcmc.ru/wiki/images/2/24/Warning_icon.svg) Когда разворачиваете Ceph OSD на SSD — очень разумно не отдавать её под Ceph целиком, а оставить небольшой раздел (10-20 гб) пустым для будущего использования под бенчмаркинг. Ибо SSD имеют свойство со временем (или при забивании данными под 80%) начинать тормозить. Очень удобно иметь возможность гонять fio на пустом никем не используемом разделе.

#### Лирическое отступление

Почему нужно тестировать именно так? Ведь в целом производительность диска зависит от многих параметров:

- Размер блока
- Режим — чтение, запись или смешанный режим чтение+запись в разных пропорциях
- Параллелизм — размер очереди и число потоков, то есть, в целом число одновременно запрашиваемых у диска операций
- Длительность теста
- Исходное состояние — пуст, заполнен линейной записью, заполнен случайной записью, заполнен случайной записью на протяжении какого-то времени и т. п.
- Распределение данных — например, 10% горячих данных и 90% холодных — или, например, определённое расположение горячих данных (в начале диска)
- Другие смешанные режимы тестов, например, тестирование одновременно с разными размерами блоков

Также и результаты можно интерпретировать с разной степенью детализации — вместо простого среднего числа операций или мегабайт в секунду можно также приводить графики, гистограммы, перцентили и так далее — это, естественно, даст больше информации о поведении тестируемого образца.

Есть и философская сторона тестов — например, производители серверных SSD иногда заявляют о необходимости подготовки диска к тестам путём 2-х кратной полной случайной перезаписи, чтобы нагрузить слой трансляции адресов диска, а я считаю, что это на самом деле ставит SSD в неправдоподобно плохие по сравнению с реальной нагрузкой условия; есть сторонники рисования графиков формата «задержка в зависимости от числа операций в секунду», что я считаю немного странным, но тоже возможным подходом — в нём, по сути, строится график F1(q) в зависимости от F2(q) и график обычно получается достаточно замысловатый — но для каких-то применений, может быть, и тоже разумный.

В общем, бенчмаркингом заниматься можно бесконечно, и уж несколько дней, чтобы предоставить полную информацию, точно уйдёт. Этим обычно и занимаются ресурсы типа 3dnews в своих обзорах SSD. А мы не хотим сидеть несколько дней. Мы хотим обозначить набор тестов, которые можно провести быстро и сразу составить примерное представление о производительности.

Посему общая идея — выделить несколько наиболее «крайних» режимов, протестировать диск в них и представить, что остальная часть «амплитудно-скоростной характеристики» диска является некоторой гладкой функцией в пределах изменения параметров между крайними точками. Тем более, что каждому из крайних режимов соответствует и реальное применение в своей категории приложений:

1. Использующих в основном линейный или крупноблочный доступ. Для таких приложений наиболее важная характеристика — производительность линейного доступа в мегабайтах в секунду. Отсюда режим тестирования линейным доступом 4 МБ блоком со средней очередью — 16-32 операции. Результаты — только в МБ/с.
2. Использующих случайный доступ мелким блоком и при этом способных к распараллеливанию. Отсюда — режимы тестирования случайным доступом 4 КБ блоком (стандартный блок для большинства ФС и, плюс-минус, СУБД) с большой очередью — 128 операций или, если диск не удаётся нагрузить одним потоком CPU с глубиной очереди 128 — тогда в несколько (2-4-8 или больше) потоков по 128 операций. Результаты — только в iops. Задержку (latency) указывать не нужно, так как в данном тесте её можно произвольно увеличить, просто подняв размер очереди — задержка жёстко связана с iops формулой latency=queue/iops.
3. Использующих случайный доступ мелким блоком и при этом НЕспособных к распараллеливанию. Таких приложений больше, чем вы могли подумать — например, в части записи сюда относятся все транзакционные СУБД. Отсюда вытекают режимы тестирования случайным доступом 4 КБ блоком с очередью 1 и, для записи, с fsync после каждой операции, чтобы диск/СХД не могли нас обмануть и положить запись во внутренний кэш. Результаты — iops или latency, по желанию — но выберите что-то одно, так как числа, опять же, жёстко связанные.

### Тестирование кластера Ceph

Как тестировать Ceph после сборки.

#### RBD

fio -ioengine=rbd. Нужно сделать следующее:

1. fio -ioengine=rbd -direct=1 -name=test -bs=4M -iodepth=16 -rw=write -pool=rpool_hdd -runtime=60 -rbdname=testimg
2. fio -ioengine=rbd -direct=1 -name=test -bs=4k -iodepth=1 -rw=randwrite -pool=rpool_hdd -runtime=60 -rbdname=testimg
3. fio -ioengine=rbd -direct=1 -name=test -bs=4k -iodepth=128 -rw=randwrite -pool=rpool_hdd -runtime=60 -rbdname=testimg
4. ...и потом то же самое для read/randread.

Смысл в том, чтобы протестировать а) задержку в идеальных условиях б) линейную пропускную способность в) случайные iops-ы.

Перед тестами чтения образ сначала нужно заполнить линейной записью, так как чтение из пустого образа очень быстрое :)

Запускать нужно оттуда, где будут реальные пользователи RBD. В целом, с другого узла результаты обычно лучше.

Также всё то же самое можно повторить изнутри виртуалки или через krbd:

1. fio -ioengine=libaio -direct=1 -name=test -bs=4M -iodepth=16 -rw=write -runtime=60 -filename=/dev/rbdX
2. fio -ioengine=libaio -direct=1 -sync=1 -name=test -bs=4k -iodepth=1 -rw=randwrite -runtime=60 -filename=/dev/rbdX
3. fio -ioengine=libaio -direct=1 -name=test -bs=4k -iodepth=128 -rw=randwrite -runtime=60 -filename=/dev/rbdX

Заметьте, что при тестировании задержки через libaio добавилась опция -sync=1. Это не случайно, а соответствует режиму работы СУБД (транзакционная запись в 1 поток). В ioengine=rbd понятие sync отсутствует, там всё всегда «sync».

#### Отдельные OSD

ceph-gobench: [https://github.com/rumanzo/ceph-gobench/](https://github.com/rumanzo/ceph-gobench/)

Либо [https://github.com/vitalif/ceph-bench](https://github.com/vitalif/ceph-bench), что примерно то же самое. Родоначальник идеи — @socketpair Марк Коренберг ([оригинал](https://github.com/socketpair/ceph-bench)). Бенчилка тестирует _отдельные OSD_, что очень помогает понять, кто же из них тупит-то.

Перед запуском надо создать пул без репликации ceph osd pool create bench 128 replicated; ceph osd pool set bench size 1; ceph osd pool set bench min_size 1 и с числом PG, достаточным, чтобы при случайном выборе туда попали все OSD (ну или прибить их вручную к каждому OSD upmap-ами).

#### CephFS

«Нормальных» инструментов для тестирования ФС, сцуко, нет!!!

«Нормальный» инструмент — это такой инструмент, который вёл бы себя, как файловый сервер: случайно открывал, создавал/писал/читал и закрывал маленькие файлы среди большого общего количества, разбитые по набору каталогов

Всё, что есть, какое-то кривожопое: bonnie++, например, зачем-то тестирует запись по 1 байту. iometer, fs_mark не обновлялись лет по 10, но и паттерн файл сервера не умеют. Лучшее, что умеют — это тест создания файлов.

Пришлось написать свой ioengine для fio: [https://github.com/vitalif/libfio_fileserver](https://github.com/vitalif/libfio_fileserver) :)

#### S3 (rgw)

Предпочтительный вариант: [hsbench](https://github.com/vitalif/hsbench) — ссылка дана на исправленную версию (!). Максимально простой, консольное Golang приложение. Оригинальная версия пока что имеет 2 неприятных бага: во-первых, вместо чтения объектов целиком читает только первые 64 КБ, во-вторых, производит последовательное, а не случайное, чтение. Что, например, с minio приводит к слишком оптимистичным результатам тестов. В моей данные баги исправлены.

[cosbench](https://github.com/intel-cloud/cosbench) — очень толстый, Java с Web-интерфейсом, XML-настройки.

[minio warp](https://github.com/minio/warp) — тестов чуть больше, чем в hsbench, но зато тестирует только 1 бакет и при каждом тесте загружает данные заново.

#### Что использовать не надо

- dd и hdparm для бенчмаркинга не использовать вообще никогда!!!
- rados bench использовать тоже не надо, так как он создаёт для тестирования очень мало объектов (в 1 поток всего 2, в 128 — несколько сотен). «Случайная» запись в такое число объектов не очень-то и случайная.
- rbd bench лучше тоже не использовать. В принципе, он адекватен, но fio всё равно лучше.
- Не надо удивляться, если Ceph не может загрузить диски на 100 % при случайной записи. Он тормоз :)

#### Про RBD и параллелизм

![Warning icon.svg](https://yourcmc.ru/wiki/images/2/24/Warning_icon.svg) Тестировать запись несколькими параллельными процессами (fio numjobs > 1) в один RBD-образ бесполезно. Из-за особенностей реализации RBD, в частности, из-за object-map, при параллельной записи из нескольких источников производительность СИЛЬНО проседает (в 2-10 раз). Можно отключить object-map, но это будет некорректный тест, т.к. в реальной эксплуатации в 99% случаев он нужен, так что с отключенным object-map вы лишь получите неправильный (слишком хороший) результат.

Если вы не можете загрузить кластер одним процессом fio, то нужно создать несколько отдельных RBD-образов и запустить несколько процессов fio параллельно, каждый на своём RBD-образе.

### Тестирование сети

sockperf. На одной ноде запускаем сервер: sockperf sr -i IP --tcp. На другой клиент в режиме ping-pong: sockperf pp -i SERVER_IP --tcp -m 4096. ВНИМАНИЕ: В выводе фигурирует **половина** задержки (задержка в одну сторону). Таким образом, для получения RTT её стоит умножить на 2. Нормальный средний RTT - в районе 30-50 микросекунд (0.05ms).

~~Также qperf. На одной ноде просто qperf. На второй qperf -vvs -m 4096 SERVER_IP tcp_lat.~~

qperf написан криво: 1) всегда использует для tcp_lat размер сообщения 1 байт!!! 2) не использует TCP_NODELAY. Так что его юзать, только если возьмёте его с моим патчем отсюда: [Мой Debian репозиторий](https://yourcmc.ru/wiki/%D0%9C%D0%BE%D0%B9_Debian_%D1%80%D0%B5%D0%BF%D0%BE%D0%B7%D0%B8%D1%82%D0%BE%D1%80%D0%B8%D0%B9 "Мой Debian репозиторий").

![Warning icon.svg](https://yourcmc.ru/wiki/images/2/24/Warning_icon.svg) Внимание: в Ubuntu на сетевую задержку негативно влияет AppArmor, его лучше отключить. Картина примерно такая (Intel X520-DA2):

- centos 3.10: rtt min/avg/max/mdev = 0.039/0.053/0.132/0.012 ms
- ubuntu 4.x + apparmor: rtt min/avg/max/mdev = 0.068/0.163/0.230/0.029 ms
- ubuntu 4.x: rtt min/avg/max/mdev = 0.037/0.071/0.157/0.018 ms

## 

О транзакционности записи

![Warning icon.svg](https://yourcmc.ru/wiki/images/2/24/Warning_icon.svg) Плохая новость!

Важная особенность Ceph — _вся запись, даже та, для которой никто этого явно не просит, ведётся транзакционно_. То есть, никакая операция записи не завершается, пока она не записана в журналы всех OSD и не сделан fsync() диска. Так сделано, чтобы предотвращать [#RAID WRITE HOLE](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#RAID_WRITE_HOLE)-подобные ситуации рассинхронизации данных между репликами при отключении питания, потере сети и т.п…

Если конкретизировать сильнее, это означает, что Ceph не использует никакие буферы записи дисков (наоборот, он делает всё, чтобы эти буферы всё время очищать). Это не значит, что буферизации записи нет вообще — она есть на уровне клиентов (page cache в linux, кэш RBD устройства на уровне драйвера librbd qemu…). Но именно внутренние дисковые буферы не используются.

Это приводит к тому, что типичная настольная SSD под журналом в Ceph выдаёт **неприлично низкие IOPS-ы** — обычно от 500 до 2000. И это при том, что при обычном тестировании почти любая SSD выдаёт > 20000 iops. Даже самый паршивый китайский noname выдаёт не менее 10000 iops. NVMe легко выжимает 150000 и больше. Но стоит начать использовать fsync… и та же NVMe выдаёт 600 iops (на 2.5 порядка меньше).

В общем, чтобы понять, сколько у вас теоретически может быть IOPS-ов на запись в Ceph, диски под него нужно тестировать с опциями fio **sync=1 iodepth=1**. Это даст «журнальные» иопсы (производительность последовательного коммита операций по одной).

Другие почти идентичные варианты: fdatasync=1 (в файле поверх ФС) либо fsync=1 (на голом девайсе). Разница между опциями:

- fsync=1 синхронизирует данные и метаданные тестируемого файла отдельным запросом после каждой операции записи. Так работает BlueStore.
- fdatasync=1 синхронизирует только данные (но не метаданные) тестируемого файла после каждой операции записи. Соответственно, от fsync=1 это отличается, только если тестируется **файл в ФС**, а не блочное устройство.  
    ![Note.svg](https://yourcmc.ru/wiki/images/5/5f/Note.svg) fdatasync=1 надо использовать, когда на диске уже есть ФС, а прогнать тест хочется. Результаты будут достаточно корректными.
- sync=1 использует O_SYNC и синхронный ввод/вывод, то есть, каждая операция начинается только после завершения предыдущей. Так работает FileStore.
    
    Но ещё нужна опция iodepth=1, иначе в очередь диска до синхронизации «пролезает» несколько операций и IOPS-ы растут, тест перестаёт быть тестом журнала.
    

## 

Конденсаторы

Нас спасёт такое чудо инженерной мысли, как **SSD с конденсаторами** (или с суперконденсаторами — ионисторами). Которые на M.2 SSD, кстати, прекрасно видны невооружённым глазом (только тут это не ионисторы :)):

[![Micron 5100 sata m2.jpg](https://yourcmc.ru/wiki/images/2/2d/Micron_5100_sata_m2.jpg)](https://yourcmc.ru/wiki/%D0%A4%D0%B0%D0%B9%D0%BB:Micron_5100_sata_m2.jpg)

Конденсаторы работают фактически как встроенный в SSD ИБП и позволяют SSD успеть сбросить кэш во флеш-память при потере питания. Таким образом кэш становится «энергонезависимым» — и таким образом SSD может просто игнорировать запросы fsync, так как точно знает, что данные из кэша в любом случае доедут до постоянной памяти.

При этом **IOPS-ы транзакционной записи становятся равны IOPS-ам нетранзакционной**.

Конденсаторы в официальных описаниях SSD-шек обычно называются «enhanced/advanced power loss protection». Этой характеристикой обладают, как правило, только «серверные» SSD, да и то не все. Например, в Intel DC S3100 конденсаторов нет, а в Intel DC S4600 есть.

![Note.svg](https://yourcmc.ru/wiki/images/5/5f/Note.svg) Это и является главным отличием серверных SSD от настольных. Обычному пользователю транзакции нужны редко — а вот на серверах живут СУБД, которым транзакции как раз нужны позарез.

То есть, под Ceph следует закупать **только** SSD с конденсаторами. Даже если рассматривать NVMe — NVMe без конденсаторов хуже, чем SATA с оными.

И ещё один вариант — Intel Optane. Это тоже SSD, но они основаны не на Flash памяти (не NAND и не NOR), а на Phase-Change-Memory «3D XPoint». По спецификации заявляются 550000 iops при полном отсутствии необходимости в стирании блоков, кэше и конденсаторах. Но если даже задержка такого диска и равна 0.005мс (она действительно равна), то задержка Ceph всё равно 0.5-1мс, соответственно, с Ceph оптаны использовать чуть менее, чем бессмысленно — за большие деньги (1500$ за 960 гб, 500$ за 240 гб) вы получите не сильно лучший результат.

## 

Bluestore vs Filestore

Блюстор — «новое» хранилище. От «нового» хранилища честно ожидаешь лучшей или хотя бы не худшей производительности во всех сценариях. Однако это, увы, не совсем так.

Что лучше в Bluestore?

- Ликвидирована двойная запись при линейной записи. Линейная запись быстрее в честных 2 раза практически в любых конфигурациях.
- Отложенная запись, эффективная для HDD (и, частично, для очень плохих SSD). iops случайной записи в HDD-only конфигурациях почти в 2 раза больше, чем в Filestore. Правда, речь об iops на HDD не идёт в принципе, поэтому вся разница — 33 или 66 iops на 1 HDD.
- Возможность использования EC под CephFS и RBD благодаря реализованной частичной перезаписи объектов в EC-пулах.
- Эффективные снапшоты (благодаря «виртуальным клонам»): после снятия снапшота iops практически не падают, в отличие от Filestore, в котором они падают до считанных сотен даже на NVMe, так как при перезаписи даже 4 КБ после снятия снапшота в Filestore копируется целый 4 МБ объект.
    
    ![Warning icon.svg](https://yourcmc.ru/wiki/images/2/24/Warning_icon.svg) Увы, это относится только к **rbd snapshot**, но не к **rbd clone**. Клоны неэффективны в Bluestore точно так же, как и в Filestore. Запись 4 КБ в клон точно так же выливается в копирование 4 МБ.
    
- Это не так критично, но в Bluestore есть поддержка сжатия и контрольных сумм данных.

А что хуже? В целом, претензии сводятся к производительности:

- Гораздо хуже производительность случайной записи на SSD+HDD, SSD-раздел не работает как буфер для быстрой записи. Bluestore не пишет быстрее, чем может в среднем сам HDD. То есть, с SSD-журналом и Filestore будет 1000—2000 иопс случайной записи, а с Bluestore (и без bcache) — 200—300. 1000—2000, конечно, упадёт до 100 или даже ниже, когда у Filestore забьётся журнал и его придётся сбрасывать — но тем не менее, «буфер» для сглаживания пиков Filestore предоставляет. А Bluestore — нет.
    
    И проблема не только в том, что параметры по умолчанию — deferred_batch_ops и max_deferred_txc — задают частый сброс операций на медленный диск (раз в 64 операции). Проблема ещё в том, что в Bluestore отсутствуют механизмы фоновой очистки «журнала» (очереди отложенной записи). Поэтому, когда очередь забивается, производительность просто падает до HDD-шной до перезапуска OSD. Ну и сама очередь находится в RocksDB, поэтому сильно поднимать её размер, по идее, неполезно.
    
- До 1.5-2 раз хуже latency случайной записи на SSD/NVMe (All-Flash), ибо накладных расходов на каждую операцию записи у Bluestore больше.
- Жор памяти больше. Да, у Filestore много занимал pagecache, но Bluestore меньше 2 ГБ памяти не жрёт вообще никогда. Причиной тому — RocksDB (одни только memtable-ы с дефолтными настройками съедают 1 ГБ памяти) и собственный кэш метаданных и данных (Bluestore не может использовать pagecache).
- Фрагментация приводит к снижению скорости чтения.

Также BlueStore делает огромное количество fsync-ов (что очень смешно — даже больше, чем запросов записи), из-за чего не терпит десктопных SSD под журналом. Но FileStore работает похоже, и кардинальных различий производительности это не вносит.

Как полечить высокие задержки на SSD+HDD?

- Либо вместо журнала (или рядом с журналом) сделать на SSD bcache для HDD.
- Либо использовать HDD с SSD Cache, Media Cache или аналогом (перманентным кэшем случайной записи на пластинах). Например, в старых дисках HGST это включается при отключении волатильного кэша командой `hdparm -W 0 /dev/sdXX`. В новых, похоже, включено всё время.

### Тест на 1 NVMe

Threadripper 2920X, NVMe Intel P4500, localhost. 1 OSD без репликации, 8 PG, чтобы не упираться в блокировки, 1 маленький RBD образ 10 Гб.

Журнал Filestore 1 GB, чтобы в тестах успевал начинаться сброс. Bluestore 4k — это min_alloc_size и prefer_deferred_size = 4096 (4k запись идёт через redirect-write), Bluestore 16k — 16384 (4k запись идёт через deferred).

||Filestore|Bluestore 16k|Bluestore 4k||
|---|---|---|---|---|
|bs=4M iodepth=16 rw=write|950 MB/s|1700 MB/s|1700 MB/s||
|bs=4M iodepth=16 rw=read|1250 MB/s|1300 MB/s|1300 MB/s|После полной линейной перезаписи + drop_caches|
|bs=4M iodepth=16 rw=read|1250 MB/s|450 MB/s|320 MB/s|После 33 % случайной перезаписи блоком min_alloc_size|
|bs=4k iodepth=1 rw=randwrite|3900 iops|3200 iops|2500 iops||
|bs=4k iodepth=128 rw=randwrite|19100 iops|19500 iops|25500 iops||
|bs=4k iodepth=1 rw=randwrite|180 iops|2800 iops|2500 iops|Сразу после снятия snapshot-а RBD|
|bs=4k iodepth=128 rw=randwrite|180 iops|8800 iops|15600 iops|Сразу после снятия snapshot-а RBD|
|bs=4k iodepth=1 rw=randread|3900 iops|4500 iops|4500 iops|После drop_caches / перезапуска OSD|
|bs=4k iodepth=1 rw=randread|6300 iops|4500 iops|4500 iops|Прогретый кэш|
|bs=4k iodepth=128 rw=randread|33000 iops|32000 iops|33000 iops||
|RAM|270 MB|2 GB +||Filestore также использует произвольный объём page cache|
|CPU randwrite Q=128|600 %|550 %|||

### Про размер block.db

**Внимание:** актуально до Ceph 14. Начиная с Ceph 15, благодаря добавленным «allocation hints» RocksDB, Bluestore стал нормально утилизировать раздел block.db. Для истории — это коммит 5f72c376deb64562e5e88be2f22339135ac7372b, там добавили опцию bluestore_volume_selection_policy.

Дальше стоит читать, только если у вас всё ещё проблемы со spillover-ами.

Спилловер — это когда вы собрали Bluestore на SSD+HDD, выделив SSD под базу (block.db), но при этом эта самая база постоянно частично утекает на HDD. При этом она, вроде бы, даже влезает в SSD с запасом — но всё равно утекает. Начиная с Ceph 14 Nautilus о спилловерах предупреждает ceph -s.

Когда случается спилловер в SSD+HDD конфигурациях, работа кластера замедляется — в большей или меньшей степени, в зависимости от размеров RocksDB и паттерна нагрузки, так как когда метаданных не очень много, они влезают в кэш OSD — либо onode cache, либо rocksdb cache, либо, если включено bluefs buffered io — то ещё и в системный page cache. Если кэш-промахов достаточно много, или если OSD упирается в compaction RocksDB, могут даже появляться slow ops-ы.

Так в чём же дело и как это победить? А дело в том, что с выбором раздела для очередного файла БД (RocksDB организована в виде набора файлов) «есть нюанс», точнее, даже два.

**Нюанс № 1:** RocksDB кладёт файл на быстрый диск только когда считает, что на быстром диске хватит места под все файлы этого же уровня (для тех, кто ещё не в курсе — RocksDB это [LSM база](https://github.com/facebook/rocksdb/wiki/Leveled-Compaction)).

Дефолтные настройки цефа:

- 1 Гб WAL = 4x256 Мб
- max_bytes_for_level_base и max_bytes_for_level_multiplier не изменены, поэтому равны 256 Мб и 10 соответственно
- соответственно, L1 = 256 Мб
- L2 = 2560 Мб
- L3 = 25600 Мб и т. д.

…Соответственно!

Rocksdb положит L2 на block.db, только если раздел имеет размер хотя бы 2560+256+1000 Мб — округлим вверх до **4 ГБ**. А L3 она положит на block.db, только если block.db размером хотя бы 25600+2560+256+1000 МБ = около **30 ГБ**. А L4, соответственно, если ещё +256 ГБ, то есть итого **286 ГБ**.

Иными словами, имеют смысл только размеры раздела block.db 4 ГБ, 30 ГБ, 286 ГБ. Все промежуточные значения бессмысленны — место сверх предыдущего граничного значения использоваться не будет. Например, если БД занимает 10 ГБ, а раздел SSD — 20 ГБ, то фактически на SSD ляжет только WAL (1 ГБ), L1 и L2 (256 МБ + 2.56 ГБ). L3, составляющий бОльшую часть базы, уедет на HDD и будет тормозить работу.

При этом 4 ГБ — слишком мало, 286 ГБ — слишком много. Так что, по сути, правильно делать block.db размером 30 ГБ для OSD любого размера. Ещё раз повторюсь: это актуально до Ceph 14, с Ceph 15 уже не актуально.

Кстати, из этого же следует то, что официальная рекомендация — выделять под block.db то ли 2 %, то ли 4 % от размера устройства данных — полный отстой.

Но что делать, если у вас разделы другого размера? Например, 80 ГБ, и вы по каким-то причинам не хотите делать bcache, но хотите использовать эти 80 ГБ по максимуму. В этом случае можно поменять базовый размер уровня RocksDB (max_bytes_for_level_base). multiplier менять не будем, оставим по умолчанию 10 — его значение влияет на итоговое количество уровней RocksDB, а это уже более тонкая материя. Теоретически, меньшее число уровней снижает read и space amplification, но замедляет compaction и из-за этого может сильно повысить итоговый write amplification. Также есть тема с уменьшением размера отдельных memtable и кратным увеличением общего их числа, то есть, например, установки 32*32 МБ вместо дефолтных 4*256 МБ и min_write_buffer_to_merge=8, но эффект от этого тоже не совсем понятен (возможно, немного экономится CPU при compaction-е), так что это тоже пока лучше не трогать.

Так как каждый уровень отличается от предыдущего в 10 раз, общий размер раздела БД должен быть равен k*X, где k — коэффициенты из ряда: 1, 11, 111, 1111 и т. п. (по числу уровней RocksDB). Значит, мы можем взять размер нашего block.db, вычесть из него 1 ГБ WAL (лучше даже вычесть с запасом 2 ГБ) и делить его последовательно на каждую из цифр до тех пор, пока не получим значение, близкое к 256 МБ … 1 ГБ. Это значение округлить вниз, принять за базовый размер уровня RocksDB и прописать в конфиг как max_bytes_for_level_base. База компактится по 256 МБ за раз, так что меньше 256 МБ размер первого уровня ставить точно смысла нет. Например, для 80 ГБ раздела это будет 719 МБ, только не забываем считать всё в двоичных мегабайтах — MiB. Остаётся прописать это значение в конфигурацию (bluestore_rocksdb_options = …,max_bytes_for_level_base=719MB), перезапустить OSD и сделать ручной compaction (можно дважды).

**Нюанс № 2:** При ручном compaction-е RocksDB переписывает уровни целиком. Если при этом на SSD нет запаса места в размере этого уровня, то уровень, опять-таки, утечёт на HDD и так там и останется, ибо перемещать после compaction-а его обратно она не умеет. Теоретически, если после этого сделать compaction ещё раз, то уровень должен вернуться на SSD (поэтому выше дана рекомендация делать ручной compaction дважды). Однако по сведениям из чата якобы бывает так, что один-два файла *.sst на SSD не возвращается. Чтобы это побороть на 100 %, можно предусмотреть на SSD-разделе ещё и запас в размере первого + последнего уровня БД. В этом случае коэффициенты вместо 1-11-111-1111 превращаются в 2-22-212-2112 и т. п.

## 

RGW vs Minio

Вопрос частый, так как Ceph и Minio — две наиболее распространённые реализации S3.

Сравнение, как всегда, не совсем честное, так как в Minio «бесконечного масштабирования» и произвольных схем избыточности нет. Есть только erasure коды, которые оперируют группами дисков, кратными по количеству 4 или 16 дискам. Расширения кластера в Minio раньше не было вообще, потом в каком-то смысле появилось через создание дополнительных зон.

Таких же гарантий целостности, как в Ceph, в Minio тоже нет. Minio работает поверх обычных ФС, даже не делая fsync данных. На практике ext4, правда, делает sync автоматически раз в 5 секунд, да и Minio пишет с O_DIRECT, так что не совсем всё плохо — но тем не менее, потенциально небольшие потери при отключении питания возможны.

Особенно классный перл был в баге [https://github.com/minio/minio/issues/3478](https://github.com/minio/minio/issues/3478):

> Minio in this case is working as intended, minio cannot be expanded or shrinkable in this manner. Minio is different by design. It is designed to solve all the needs of a single tenant. Spinning minio per tenant is the job of external orchestration layer. Any addition and removal means one has to rebalance the nodes. When Minio does it internally, it behaves like blackbox. It also adds significant complexity to Minio. Minio is designed to be deployed once and forgotten. We dont even want users to be replacing failed drives and nodes. Erasure code has enough redundancy built it. By the time half the nodes or drives are gone, it is time to refresh all the hardware. If the user still requires rebalancing, one can always start a new minio server on the same system on a different port and simply migrate the data over. It is essentially what minio would do internally. Doing it externally means more control and visibility. Minio is meant to be deployed in static units per tenant.

Короче, всё работает как надо, в минио нет возможности расширения, если у вас будут ломаться диски — не меняйте, просто дождитесь, пока из строя выйдет половина дисков и пересоздайте кластер. На самом деле всё не так печально, можно заменить диск и запустить heal, но, конечно, без той же прозрачности, что в Ceph — оно будет просто сканировать все объекты и проверять отсутствующие. Если дисков много, это очень накладно.

Ещё Minio хранит объекты в виде обычных файлов, даже не шардируя каталоги (соответствующие бакетам) по подкаталогам, плюс на каждый объект ещё создаёт директорию с парой файлов метаданных. Ну а директории в ФС по миллиону файлов — это, естественно, удовольствие ниже среднего. Хотя просто для раздачи оно, благодаря всяким dir_index-ам, работает.

Для представления о производительности проведём простой тест Ceph (bluestore) vs Minio (ext4) на 1 HDD. Да, я знаю, что это тупо и нужно ещё хотя бы посравнивать их на SSD. Но всё-таки результаты довольно показательны. Да и объектное хранилище чаще холодное/прохладное и строится на HDD, а не на SSD.

Тест делался через [hsbench](https://github.com/vitalif/hsbench). Заключался в заливке примерно 1.1 миллиона объектов в 1 бакет, потом сброса кэшей и перезапуска Ceph/Minio, и потом — их раздачи в случайном порядке, а также проверки скорости выполнения операций листингов. Результаты:

- Заливка в 32 потока: Minio — 305 объектов в секунду, RGW — 135 объектов в секунду. RGW indexless — 288 объектов в секунду.
- Раздача в 32 потока: Minio — 45 объектов в секунду, RGW — 78 объектов в секунду
- Листинги в 32 потока: Minio — после сброса кэша 35 сек, после прогрева — 2.9 сек с разбросом от 0.5 до 16 сек. RGW — стабильно — 0.4 сек

Да, заливка в Minio быстрее. Но, во-первых, меньшая скорость заливки — это цена, во-первых, консистентности (fsync), а во-вторых, bucket index-а и bucket index log-а, которые позволяют RGW, например, делать геосинхронизацию (multisite), чего в Minio нет.

Кроме того, индексы в RGW можно положить на отдельные SSD (как обычно все и делают), а если же вам совсем не нужны листинги, синхронизация и прочее, в Ceph бакеты можно сделать безиндексными (indexless), и тогда оверхед bucket index-а вообще исчезает, как и возможные проблемы с его шардированием.

## 

Снапшоты

В реализации снапшотов в Ceph есть целый ворох проблем из-за количества параллельных реализаций и общего накопленного архитектурного бардака:

- На уровне RADOS снапшоты свои и их уже 2 вида: снапшоты пулов и снапшоты объектов.
- На уровне RBD тоже свои снапшоты, причём они отличаются от RADOS-снапшотов, хоть внутри и реализованы частично через них. RBD снапшоты, можно сказать, не юзабельны ни для чего, кроме быстрого снятия бэкапов, за которым тут же следует удаление снапшота. Откат к RBD снапшотам очень медленный и реализован не просто ужасно, а отвратительно — копированием содержимого снапшота поверх образа, _даже неизменённых частей_. Кроме того, при откате цепочка последующих снапшотов уничтожается. Кроме того, есть прикол с жором места — см. на 2 пункта ниже.
- В Bluestore снапшоты эффективны — после снятия снапшота случайная запись практически не замедляется, в отличие от Filestore, где принцип работы снапшотов схож со старым LVM и при записи даже 4 КБ после снятия снапшота соответствующий 4 МБ объект копируется целиком.
- Но при этом эта оптимизация снапшотов — «виртуальные клоны» — реализована именно на уровне Bluestore, ни клиент, ни OSD о ней ничего не знают и поэтому она… ломается при ребалансе. Выглядит это так: ты добавляешь в кластер диск, он заполняется, а доступного места больше не становится. Почему? Потому что изначально, при записи, Bluestore получил запрос «клонировать 4 МБ объект в новую версию» и сделал это внутри себя, реально не копируя данные, а потом перезаписал 4 КБ. А при ребалансе эта связь порвалась и объект стал занимать все 4 МБ… Fail.
- Также на уровне RBD есть клоны, которые, с одной стороны, более юзабельны — реализованы они через ссылку на родительский образ, соответственно, откат к такому «снапшоту» быстрый — достаточно просто создать новый клон. С другой стороны, для клонов не работает эта самая блюсторовская оптимизация, поэтому они опять-таки копируют объекты целиком при любой записи… что выливается в 40 иопс на запись (QD=1) в свежий клон даже в NVMe кластере.
- В CephFS ещё одна реализация снапшотов, и там отката нет вообще.

В общем, наговнокодили — мама не горюй…

## 

EC

EC ещё больше снижает iops-ы, так как добавляется цикл Read-Modify-Write. [#RAID WRITE HOLE](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_mobile#RAID_WRITE_HOLE) в цефе закрыт, поэтому при записи все OSD сначала делают вторые копии объекта (по-видимому, виртуальные, через тот же механизм virtual clone bluestore), а потом удаляют старые.

В моём примере на NVMe-шках — write iops с репликацией Q=1 примерно 1500, а с EC — примерно 500. Q=128 — примерно 25000 с репликацией и 10000 с EC.

### Про вероятность потери данных

Смотрите мой калькулятор вероятности потери данных в кластере: [https://yourcmc.ru/afr-calc/](https://yourcmc.ru/afr-calc/)

## 

Контроллеры

- SATA — это нормально, SAS не обязателен от слова «совсем». SATA за счёт того, что «не умничает», достаточно быстрая и точно лучше, чем старые RAID контроллеры.
- Разница в IOPS между RAID и HBA/SATA может быть колоссальна. В производительность не самого нового RAID контроллера легко упереться. Плохо даже не то, что на 1 диск вы получите 48000 iops вместо 60000, хуже то, что при подключении 8 дисков вы получите 6000 iops на каждый диск вместо 60000, так как 48000 поделятся на всех. Также в RAID режиме увеличивается задержка в 1 поток.
- Так что свой RAID контроллер либо переключите в режим passthrough (если он умеет), либо перепрошейте, чтобы умел, либо выкиньте в помойку и купите HBA («RAID без RAID-функционала», например, LSI 9300-8i). Это актуально для всех видов программных хранилок — Ceph, ZFS и т. п.
- Если не выкинули RAID — отключайте все кэши контроллера, чтобы уменьшить влияние прослойки и не страдать при разряде батарейки / перемещении диска в другой сервер... и молитесь :). Наверное, в теории можно выжить и с включенным кэшем, но это стрельба себе в ногу.
- Даже если у вас HBA — имейте в виду, что некоторые HBA (в частности, Adaptec) могут всё равно не сбросить кэш корректно и устроить вам Cloudmouse при отключении питания. Но по крайней мере точно известно, что LSI ведут себя нормально.
- Хороший пост про RAID-кэши в списке рассылки: [http://lists.ceph.com/pipermail/ceph-users-ceph.com/2019-July/036237.html](http://lists.ceph.com/pipermail/ceph-users-ceph.com/2019-July/036237.html) - если вкратце - человек, админивший 6000 OSD, пишет, что никогда больше не свяжется с RAID0-режимами.
- У HBA тоже есть предел IOPS. К примеру, у LSI 9211-8i это ~280000 iops на весь контроллер.
- При подключении через SATA или HBA контроллер не забывайте для **серверных** SATA дисков сделать hdparm -W 0 /dev/sdX, для SAS — sdparm --set WCE=0 /dev/sdX.
- Для SAS и NVMe включайте blk-mq (ну или юзайте свежие ядра, в районе 4.18 оно включается по умолчанию). Но для SATA blk-mq обычно бесполезен или почти бесполезен.
- Фактическая глубина очереди, используемая Ceph OSD при случайной записи, редко больше 10 (посмотреть можно при работе утилитой iostat -xmt 1).

## 

Процессоры

- На SSD Ceph ОЧЕНЬ СИЛЬНО упирается в процессор. Можно сказать, что процессор — основной bottleneck.
- Как сказано в презентации Ника Фиска — Ceph is a Software-Defined Storage **and every piece of Ceph «Software»** will run faster with every GHz of CPU frequency.
- Кроме частоты, на серверных процессорах часто наличествует NUMA (Non-Uniform Memory Access). То есть, часть памяти и оборудования доступна процессору напрямую, а часть — только через другой процессор.
- Для максимизации производительности конфигураций с NUMA лучше избегать, а процессорам с бОльшим числом ядер и меньшей частотой лучше предпочитать бОльшую частоту и меньшее число ядер…
- …но в пределах разумного, так как даже один OSD на серверном SSD под нагрузкой может спокойно выжрать на 100 % ядер 6.
- Под частотой подразумевается номинальная частота, а не Turbo Boost, так как оный актуален только для однопоточных нагрузок.
- Рекомендации по привязке OSD к отдельным CPU (taskset), можно сказать, неактуальны, так как Ceph OSD сильно многопоточные — при записи постоянно активно как минимум 4 потока, и ограничение их несколькими ядрами сильно урезает производительность.
- Есть два параметра, которые регулируют число рабочих потоков OSD — osd_op_num_shards и osd_op_num_threads_per_shard…
- …Но менять их бесполезно, поднять производительность таким образом не получается абсолютно, дефолтные значения (1x5 на HDD и 2x8 на SSD) оптимальны. kv_sync_thread-то всё равно только один.
- Есть одна мера, которая помогает поднять производительность сразу раза в 2-3: отключение экономии энергии процессором:
    - cpupower idle-set -D 0 — отключает C-States (либо опции ядра processor.max_cstate=1 intel_idle.max_cstate=0)
    - cpupower frequency-set -g performance или (старое) for i in $(seq 0 $((`nproc`-1))); do cpufreq-set -c $i -g performance; done — отключает снижение частоты через множитель
- После этих двух команд процессор начинает греться как ПЕЧ, но iops-ы увеличиваются сразу раза в 2 (а то и 3)
- Также жор CPU — одна из причин НЕ делать из Ceph «гиперконвергентное облако» (в котором совмещены узлы хранения и запуска виртуальных машин)
- Ещё можно отключить все mitigation-ы аппаратных уязвимостей: noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier

## 

Сеть

- Разумеется, 10 Гбит/с или быстрее
- MTU 9000: ip l set enp3s0f0 mtu 9000
- Отключить оффлоады: ethtool -K enp3s0f0 gro off gso off tso off lro off sg off
- Отключить объединение прерываний: ethtool -C enp3s0f0 rx-usecs 0
- Самый дешёвый 10G свитч с Ebay: Quanta LB6M / Brocade TurboIron 24X — но говно старое унылое и жрёт под 200 ватт, и греется и жужжит соответственно
- UPD Самый дешёвый свитч с Aliexpress: [TP-LINK TL-ST5008F](https://aliexpress.ru/item/1005004429524441.html). На чипе [Realtek RTL9303-CG](https://www.realtek.com/en/products/communications-network-ics/item/rtl9303-cg)

Если совсем задолбала латенси, как отключить ВСЕ оффлоады?

for i in rx tx tso ufo gso gro lro tx nocache copy sg txvlan rxvlan; do
    /sbin/ethtool -K eth3 $i off 2>&1 > /dev/null;
done

## 

Настройка виртуалок и ФС

С дефолтными опциями qemu подключает RBD, увы, криво.

Криво — это значит, что:

а) используется медленная эмуляция lsi-контроллера

б) неправильно настроен кэш

### Драйвер виртуального диска и ФС

В qemu есть следующие способы эмуляции дисков:

- lsi — самый медленный
- virtio — самый быстрый, но до QEMU 4.0 не умел TRIM. Юзать надо его.
- virtio-scsi — достаточно быстрый. На самом деле, умеет multiqueue и поэтому на быстром хранилище (например, при прямом доступе к локальной NVMe) должен быть быстрее virtio — но в случае с Ceph это не так, так как цеф не настолько быстрый, чтобы multiqueue играл роль
- nvme — тоже достаточно быстрый, но немного медленнее virtio. Принцип работы похожий — и там, и там кольцевые буферы. Можно использовать для тех образцов ПО, которые не умеют virtio, потому что не уметь nvme сейчас совершенно точно не может никто. Например, если хочется потестировать VMWare ESXi с вложенной виртуализацией внутри QEMU, то nvme — для вас!

### cache=writeback

Кэш дисков в qemu регулируется опцией, собственно, cache. Бывает <не указано>, writethrough, writeback, none, unsafe, directsync.

С Ceph RBD эта опция регулирует работу rbd cache, то есть кэша на стороне клиентской библиотеки Ceph (librbd). RBD cache маленький (32 МБ) и является аналогом буфера записи на HDD, то есть, предназначен исключительно для группировки операций записи перед, собственно, отправкой их в хранилище.

Режимы writethrough, <не указано> и directsync с RBD, по сути, эквивалентны и означают отсутствие кэширования записи (каждая операция отправляется сразу в Ceph).

Режим writeback означает «честное» (безопасное) кэширование записи. То есть, операции записи без fsync ложатся в кэш и отправляются оттуда либо раз в rbd_cache_max_dirty_age (по умолчанию 1 сек), либо когда ВМ просит fsync.

Режим unsafe означает «нечестное» (чреватое потерей данных) кэширование записи. Операции записи также ложатся в кэш, но fsync от ВМ игнорируются. Транзакционность в виртуалке отсутствует, но и производительность повышается. Использовать этот режим можно только для виртуалок, не содержащих ценные данные (например, для каких-нибудь тестов или CI).

При среднем применении правильный режим — **cache=writeback**. Грубо говоря, cache=writeback увеличивает результат следующего теста:

fio -name=test -ioengine=libaio -direct=1 -bs=4k -iodepth=1 -rw=randwrite -filename=/dev/vdb   # без -fsync и без -sync

…примерно приводя его к результату того же теста с iodepth=32.

![Note.svg](https://yourcmc.ru/wiki/images/5/5f/Note.svg) ОДНАКО, есть НЮАНСЫ (как всегда с цефом…):

- Если RBD-образ пустой и при этом на нём включён object-map (по умолчанию включён, см. rbd info <pool>/<image>), то сброс кэша становится однопоточным И ФИГ ВЫ ВИДИТЕ улучшение результата fio.
- Если опция rbd_cache_writethrough_until_flush равна true (так по умолчанию), то до первого fsync кэш не работает. То есть, если вы монтируете к виртуалке диск и сразу тестируете его вышеприведённой командой — вы опять-таки не увидите хороших результатов.
- Из-за той же опции, стоящей в true, cache=unsafe не работает вообще. В Proxmox включен патч, который заставляет qemu ставить эту опцию автоматически. Если у вас не Proxmox — опцию нужно прописать в конфиг глобально: rbd_cache_writethrough_until_flush=false.
- Сам кэш может являться тормозом в SSD-кластерах. Что-то там сделано с блокировками, что-то там однопоточное, всё это оптимизируют, но пока не оптимизировали. Например, 4K randwrite Q128 с rbd_cache=false может достигать 20000 iops, а с rbd_cache=true — только 11000 iops. Для говнософта, который пишет на диск абы как, это торможение оправдано, а для, например, СУБД — нет. Поэтому в случае, если у вас SSD и вам нужны в первую очередь random iops, то правильный режим — **cache=none**.

### ФС

А ещё тормозит файловая система! Конкретно, если у вас не включена опция mount -o lazytime, то при каждой мелкой записи ФС обновляет mtime, то есть время модификации inode-а. Так как это метаданные, а ФС журналируемые — это изменение журналируется. Из-за этого при тесте fio -sync=1 -iodepth=1 -direct=1 поверх ФС без lazytime iops-ы уменьшаются в 3-4 раза.

Для lazytime нужны свежие ядра: с ext4 — хотя бы 4.0, с XFS — хотя бы 4.17. Также нужны соответствующие (свежие) util-linux (подсказка: в протухшей 7-й центоси их нет, поставить можно только из исходников).

А если у вас (не дай бог) внутри Oracle, то ему надо обязательно поставить опцию FILESYSTEMIO_OPTIONS=SETALL.

Производительность случайной записи в CephFS почти не отличается от RBD.

Производительность случайной записи в CephFS через mount -t cephfs и через ceph-fuse… при iodepth=1 почти не отличается. А вот при iodepth=128 ядерный клиент ведёт себя нормально, а ceph-fuse выдаёт столько же, сколько при iodepth=1 (то есть на порядок/порядки меньше, чем ядерный клиент).

## 

Оценка производительности кластера

Оценка производительности кластера просто по спецификациям входящих в него дисков — абсолютно неправильна.

Речь о Bluestore. Под iops понимаются iops случайного чтения/записи блоками по 4 кб.

1 HDD (обычный, 7200 rpm, не SMR, без ssd-кэша) — это:

- ~100-120 iops при QD=128
- ~66 iops при QD=1
- ~40 MB/s линейного чтения/записи
- При недостатке памяти показатели будут хуже, так как будут cache miss по метаданным

1 быстрый SSD или NVMe SSD (с конденсаторами, write iops >= 25000):

- ~1000 iops на запись при QD=1, в зависимости от частоты CPU и настроек может быть от 300 до, в самом идеальном случае, ~2500 iops.
- Максимум до ~10000-20000 iops на запись при QD=128 на 1 OSD.
- На чтение показатели примерно в 2-2.5 раза лучше: QD=1 ~2000 iops (максимум до ~4000), QD=128 ~20000, максимум до 50000.
- Естественно, показатель QD=128 не может быть больше, чем показатель самого диска :). Но так как хорошие SSD в параллельном режиме обычно быстрые — этого не замечаешь.
- Создав несколько OSD на одном диске, можно умножить число QD=128 iops на число OSD (пока диск позволяет). Естественно, ценой аналогичного увеличения жора CPU.
- Скорость линейного чтения/записи примерно равна скорости линейного чтения/записи самого диска.
- Кардинальной разницы по iops между SATA SSD и даже NVMe, если у обоих есть конденсаторы — нет. Это не отменяет того, что NVMe лучше, но на случайном доступе это заметить трудно.
- На актуальных SSD чтение QD=1 часто бывает медленнее записи QD=1, так как писать можно в быстрый кэш, а читать можно только из реальной памяти. Разница бывает примерно такая: на чтение при QD=1 8000 iops, а на запись 40000 iops.

Итоговые показатели:

- Линейное чтение из кластера = Число OSD * MB/s одного OSD
- Линейная запись в реплицированный пул = Число OSD / Репликация * MB/s одного OSD
- Линейная запись в EC-пул = Число OSD / (K+M) * K * MB/s одного OSD
- С iops всё сложнее, так как репликация вносит нелинейный эффект в масштабирование. Но, условно говоря:
    - iops QD=1 — усредняются по всем OSD, а iops QD=128 — суммируются
    - При этом на 1 RBD клиента можно получить лишь до ~30000 iops на чтение и ~15000 iops на запись
- Естественно, если что-то упирается в сеть — соответствующая цифра обрезается показателем сети

## 

Картина маслом «Тормозящий кэш»

### O_SYNC vs fsync vs hdparm -W 0

У SATA и SCSI дисков есть два способа сброса кэша: команда FLUSH CACHE и флаг FUA (Force Unit Access) на команде записи. Первый — это явный сброс кэша, второй — это указание записать операцию на диск, минуя кэш. Точнее, у SCSI оно есть, а с SATA ситуация точно не ясна: в спецификации NCQ бит FUA есть, но по факту FUA большинством дисков вроде как не поддерживается и, соответственно, эмулируется ядром/контроллером (если контроллер не кривой).

По всей видимости, fsync() отправляет диску команду FLUSH CACHE, а открытие файла с O_SYNC устанавливает бит FUA на все команды записи.

Есть ли разница? Обычно нет. Но на некоторых контроллерах и/или с некоторыми настройками различия по неустановленным причинам встречаются. И тогда fio -sync=1 и fio -fsync=1 начинают давать разные результаты — возможно, даже на порядки разные результаты.

Кроме того, у дисков есть команда отключения кэша. Когда он отключен, запросы сброса (fsync) Linux диску не отправляет. Казалось бы, такой режим тоже должен быть эквивалентен выполнению fsync и/или O_SYNC после каждой команды. Но и это не всегда так! На SSD с конденсаторами (то есть серверных моделях с Advanced Power Loss Protection) при отключении кэша iops-ы случайной записи часто вырастают на порядок (например, с 5000 до 40000). Но не всегда, так как это, опять-таки, зависит от контроллера.

Почему? По-видимому, потому, что команда FLUSH CACHE трактуется диском как «сбрось все кэши» (включая энергонезависимый), а отключение кэша — как «отключи энергозависимый кэш» (а энергонезависимый можешь оставить включенным). Соответственно, запись со сбросом кэша становится медленнее, чем просто отключённый кэш.

А что с NVMe? В NVMe разнообразие чуть меньше — возможность отключить кэш в спецификации не предусмотрена вообще, но точно так же есть команды FLUSH CACHE и бит FUA. При этом по личным наблюдениям FUA часто игнорируется то ли диском, то ли Linux-ом, и fio -sync=1 выдаёт с NVMe такие же результаты, как и без sync вообще. -fsync=1 при этом ведёт себя как надо и приземляет производительность туда, где ей самое место (на десктопных NVMe — до тех же 1000—2000 iops).

P.S: Bluestore использует fsync. Filestore использует O_SYNC.

### Серверные SSD

Disabling cache is not a joke!

fio -ioengine=libaio -name=test -filename=/dev/sdb -(sync|fsync)=1 -direct=1 -bs=(4k|4M) -iodepth=(1|32|128) -rw=(write|randwrite)

**Micron 5100 Eco 960GB**

**Запись**

|sync или fsync|bs|iodepth|rw|hdparm -W 1|hdparm -W 0|
|---|---|---|---|---|---|
|sync|4k|1|write|612 iops|22200 iops|
|sync|4k|1|randwrite|612 iops|22200 iops|
|sync|4k|32|randwrite|6430 iops|59100 iops|
|sync|4k|128|randwrite|6503 iops|59100 iops|
|sync|4M|32|write|469 MB/s|485 MB/s|
|fsync|4k|1|write|659 iops|25100 iops|
|fsync|4k|1|randwrite|671 iops|25100 iops|
|fsync|4k|32|randwrite|695 iops|59100 iops|
|fsync|4k|128|randwrite|701 iops|59100 iops|
|fsync|4M|32|write|384 MB/s|486 MB/s|

**Чтение**

|bs|iodepth|rw|результат|
|---|---|---|---|
|4k|1|randread|6000 iops|
|4k|4|randread|15900 iops|
|4k|8|randread|18500 iops|
|4k|16|randread|24800 iops|
|4k|32|randread|37400 iops|
|4M|1|read|460 MB/s|
|4M|16|read|514 MB/s|

Результаты по чтению не отличаются на hdparm -W 0 и 1.

**Seagate Nytro 1351 XA3840LE10063**

Диск заполнен почти полностью, на 90-100 %.

**Запись**

|sync или fsync|bs|iodepth|rw|hdparm -W 1|hdparm -W 0|
|---|---|---|---|---|---|
|sync|4k|1|randwrite|18700 iops|18700 iops|
|sync|4k|4|randwrite|49400 iops|54700 iops|
|sync|4k|32|randwrite|51800 iops|65700 iops|
|sync|4M|32|write|516 MB/s|516 MB/s|
|fsync=1|4k|1|randwrite|288 iops|18100 iops|
|fsync=1|4k|4|randwrite|288 iops|52800 iops|
|fsync=4|4k|4|randwrite|1124 iops|53500 iops|
|fsync=1|4k|32|randwrite|288 iops|65700 iops|
|fsync=32|4k|32|randwrite|7802 iops|65700 iops|
|fsync=1|4M|32|write|336 MB/s|516 MB/s|

**Чтение**

|bs|iodepth|rw|результат|
|---|---|---|---|
|4k|1|randread|8600 iops|
|4k|4|randread|21900 iops|
|4k|8|randread|30500 iops|
|4k|16|randread|39200 iops|
|4k|32|randread|50000 iops|
|4M|1|read|508 MB/s|
|4M|16|read|536 MB/s|

Если не хотите 288 иопс — отключайте кэш.

### Ceph HDD+SSD

Дано: 3 компа с 4x 7200rpm SATA HDD, с 1 SSD (десктопным) под систему и ceph-mon и с 1 SSD (старым, но серверным, 25000 iops) под журналы. Не самая быстрая 10-гигабитная сеть — флуд пингом средний RTT (задержка) 0.098ms. Развёрнут Ceph + OpenNebula с KVM. Диски под Ceph отформатированы в Bluestore утилитой ceph-volume (то есть используется LVM). Диски виртуалок лежат в обычном реплицированном ceph pool с size=3.

Создаём Debian-виртуалку (настройки диска kvm по умолчанию — bus=virtio, cache=none), ставим fio, запускаем в ней тест на задержку транзакционной случайной записи: fio -ioengine=libaio -size=10G -sync=1 -direct=1 -name=test -bs=4k -iodepth=1 -rw=randwrite -runtime=60 -filename=./testfile (или можно не случайной, тогда rw=write, но результат идентичный).

1. Настройки по умолчанию — все кэши дисков включены (везде hdparm -W 1, в /sys/block/*/queue/write_cache везде write back) — Ж О П А, iops=59, avg lat = 16.88ms
2. Отключаю кэш записи SSD с журналами: hdparm -W 0 /dev/sdb — остаётся Ж О П А, iops=58, avg lat = 16.99ms
3. Всем LVM-девайсам отключаю кэш записи: for i in /sys/block/dm-*; do echo write through > $i/queue/write_cache; done` — А Ф И Г Е Т Ь, iops=584, avg lat = 1.7ms
4. Обратно включаю кэш SSDшке с журналами: hdparm -W 1 /dev/sdb — остаётся iops=582, avg lat = 1.7ms
5. Откручиваю все отключения кэшей LVM: for i in /sys/block/dm-*; do echo write back > $i/queue/write_cache; done — обратно жопа, 57 iops, avg lat = 17.2ms
6. Опять отключаю кэш журнальным LVM-девайсам: for i in `ls /dev/ceph-journals/lvol*`; do j=readlink $i; echo write through > /sys/block/${j##../}/queue/write_cache; done — никакого улучшения, всё та же жопа (но с ними это точно безопасно, так как они с конденсаторами :))
7. Отключаю кэш HDD LVM-разделам (for i in `ls /dev/ceph-*/osd-block*`; do j=readlink $i; echo write through > /sys/block/${j##../}/queue/write_cache; done) — бинго, iops=603, avg lat = 1.65ms
8. Ага. Простите. Обнаруживаю, что просто писать куда-то write through небезопасно без hdparm -W 0 /dev/sd*, так как [https://www.kernel.org/doc/Documentation/block/queue-sysfs.txt](https://www.kernel.org/doc/Documentation/block/queue-sysfs.txt) - Writing to this file can change the kernels view of the device, but it doesn’t alter the device state. ок, добавляю for i in /dev/sd?; do hdparm -W 0 $i; done (отключаю все кэши) — результат похуже, iops=405, avg lat = 2.47ms — но это всё равно лучше, чем изначальная жопа.

Виртуалку, в которой тестировал — даже не перезапускал между тестами.

![Note.svg](https://yourcmc.ru/wiki/images/5/5f/Note.svg) Мораль: отключайте кэш записи всем дискам!

Частичная разгадка:

1. ~~В жёстких дисках HGST есть Media Cache~~ (энергонезависимый кэш случайной записи прямо на пластинах) — во-первых, там не HGST, во-вторых, в HGST медиакэш включён всегда и не зависит от hdparm -W 0.
2. В жёстких дисках Seagate Enterprise Capacity ST8000NM0055 (коих из общего числа 3) есть встроенный SSD-кэш. И вот он, видимо, действительно включается только при hdparm -W 0.
3. Блюстор блокирует запись в журнал записью на HDD. Когда включен спец.кэш, HDD начинает рандомно писать сильно быстрее, и блокировки при сбросе уходят. Действует кэш, естественно, временно — когда он кончится, производительность случайной записи опять упадёт. Однако плюс в том, что в Ceph-е этого, скорее всего, не произойдёт, так как скорость случайной записи ограничивается, собственно, самим Ceph-ом и распределяется по всем дискам кластера :).
4. Однако, для обычных дисков без SSD-кэша отключение кэша тоже даёт выигрыш… есть гипотеза, что из-за того же тормоза с bluefs (проверю).

Более свежие тесты бенчилкой ceph-gobench на том же самом стенде. Версия Ceph Mimic 13.2.2, Bluestore, журналы на SSD.

osd.1 и osd.3 без выноса журналов на SSD оба показывали 75-80 iops вне зависимости от отключения кэша.

В таблице показаны однопоточные IOPS с глубиной очереди Q=1 без репликации.

|Номер OSD|Патч + кэш|Кэш выкл|Кэш вкл|Модель диска|Номер модели|
|---|---|---|---|---|---|
|osd.0|365|308|226|Seagate Constellation ES.2|ST32000645NS|
|osd.1|322|325|234|Hitachi Ultrastar 7K3000|HUA723020ALA640|
|osd.2|1278|1392|230|Seagate Enterprise Capacity|ST8000NM0055|
|osd.4|198|244|140|Hitachi Ultrastar A7K2000|HUA722020ALA330|
|osd.5|251|185|154|Hitachi Ultrastar A7K2000|HUA722020ALA330|
|osd.7|1351|1129|253|Seagate Enterprise Capacity|ST8000NM0055|
|osd.9|399|315|184|Hitachi Ultrastar 7K3000|HUA723020ALA640|
|osd.13|226|212|142|Hitachi Ultrastar A7K2000|HUA722020ALA330|
|osd.3|393|386|241|Hitachi Ultrastar 7K3000|HUA723020ALA640|
|osd.8|340|323|156|Hitachi Ultrastar A7K2000|HUA722020ALA330|
|osd.10|1461|1319|273|Seagate Enterprise Capacity|ST8000NM0055|
|osd.14|302|229|135|Hitachi Ultrastar A7K2000|HUA722020ALA330|

#### Примечания

Toshiba MG07ACA14TE тоже замечены в подобном поведении, см. обсуждение в списке рассылки: [https://www.spinics.net/lists/ceph-users/msg60753.html](https://www.spinics.net/lists/ceph-users/msg60753.html)

## 

Почему вообще Bluestore такой медленный?

![Note.svg](https://yourcmc.ru/wiki/images/5/5f/Note.svg) Третья редакция hatespeech’а.

Вкратце ситуация такова: После того, как хранилище Ceph переписали с упоротой архитектуры с хранением объектов в ФС XFS и дополнительным журналом, в которой, по идее, был дикий оверхед — быстрее (в смысле random write iops) оно практически не стало. **Логичный ответ на вопрос «какого х#ра» такой: то ли XFS на самом деле написана очень хорошо, то ли Bluestore на самом деле написан очень плохо.** Сразу скажу: оба ответа верны. :-)

Все мы держим в уме, что 1x 7200rpm HDD может выдать примерно 100—120 iops. Дальше нам говорят — ну, там типа журналирование. Ну ок, как мы рассуждаем — ну, типа, есть журнал, есть диск. Значит типа вроде как синхронно записало в журнал, потом асинхронно постепенно перенесло на диск. Значит, берём 100, умножаем на число дисков в кластере, делим на фактор репликации (3), делим на 1.5-2 (данные+журнал), мы же держим в уме, что наверняка там всё асинхронно и оптимизировано… Получаем, скажем, 100 * 9 дисков / 1.5-2 / 3 = 150—200 iops. Запускаем fio iodepth=128 на собранном кластере — ОЙ, 30 iops. Как так?

Отчаиваемся и по советам знатоков прикручиваем туда SSD под wal+db. И думаем: ну, теперь у нас быстрая SSD с конденсаторами под журналом, латенси записи 50 микросекунд, значит должно быть много иопсов — ну, в устоявшемся режиме хотя бы 300 (9 * 100 / 3). Тестируем. В 1 поток получаем ну… 60 иопс. Во много — где-то 200. Опять плохо.

Смысл в том, что собственной реализации журнала у блюстора нет, есть очередь отложенной записи, живущая прямо в RocksDB. RocksDB — это LSM keyvalue база, по сути база-журнал. В принципе, это достаточно разумно, так как всё равно нужно журналировать изменения метаданных, которые там держит блюстор. Когда очередь отложенной записи засунута туда же, изменение можно коммитить одной транзакцией (соответственно, одним fsync-ом).

И в этой схеме есть одно большое отличие от filestore — оно заключается в том, что в filestore журнал работал как буфер для временного повышения нагрузки на запись. Пока в журнале было место, случайная запись была очень быстрой, а журналы обычно делали размеров в несколько гигабайт. В bluestore же «очередь отложенной записи» очень маленькая и сбрасывается через каждые 64 запроса. То есть, bluestore не пишет быстрее, чем в среднем может медленное устройство (HDD).

Плюс к этому на практике (при просмотре strace) оказывается, что fsync-ов на каждую операцию записи делается не 1, а 2. Второй fsync — это лишняя транзакция записи в журнал BlueFS, сводящаяся к обновлению размера лог-файла RocksDB. Это нафиг не нужно, так как в опциях RocksDB в цефе по умолчанию стоит wal_recovery_mode=kTolerateCorruptedTailRecords и recycle_log_number=4, но это так, потому что без этого у них из-за другого бага корраптятся данные при падении OSD. Что на самом деле исправляется легко, я им даже отправил фикс — [https://tracker.ceph.com/issues/38559](https://tracker.ceph.com/issues/38559) [https://github.com/ceph/ceph/pull/26909](https://github.com/ceph/ceph/pull/26909) - и они даже вроде как обещают его влить. С фиксом на HDD ускорение случайной записи при глубине очереди 1 — двукратное (с 33 % до 66 % возможностей самого HDD, обычно как раз с 33 до 66 иопс). При глубине очереди 128 — почти нулевое.

ОК, ладно. В конце концов мы решаем — гулять так гулять и собираем кластер на серверных SSD (или вообще NVMe). Думаем — ну теперь-то?!… Бенчим в 1 поток. 300 иопс. Охреневаем окончательно и идём гуглить эту статью :)

Здесь смысл в том, что в голове у всех сидит мысль «а, ну да, оно медленное, потому что слишком много пишет на диск — диск же относительно медленный, а софт быстрый». А вот хрен. :) оказывается, Ceph довольно сложно разогнать до latency < 1 ms, и виной тому не диски, а сам Ceph. То есть да, Ceph при записи мелкими блоками порождает WA (Write Amplification) 3..5 на каждой OSD — это легко посчитать через тот же strace. Но на хороших SSD это практически не занимает времени, одна операция 4кб записи занимает условно 20 микросекунд. Проблема именно в С++ коде Ceph.

Причём даже не до конца понятно, что конкретно там тормозит — такое ощущение, что всё целиком. Выявить какие-то «горячие точки» при профилировании трудно, просто при записи выполняется много всякой C++ной мелочи, которая суммарно отъедает достаточно много времени. Одно горячее место — вычисление цифровых подписей пакетов (включено по умолчанию, можно отключить), другое — сериализация/десериализация (код обрабатывает каждое поле пакета, чуть ли не каждый байт, отдельным вызовом функции). Дальше идут уже malloc-и, которых тоже происходят тонны. Причём всё это происходит в несколько потоков. На это ещё навёрнута какая-то странная смесь буферизованного и прямого I/O.

RocksDB не виновата — её я пробовал бенчить, она быстрая, ~8000 транзакций в секунду на NVMe в 1 поток она даёт и даже масштабируется до ~120000 tps в 256 потоков. А Ceph OSD даже с максимальным параллелизмом на той же NVMe даёт только 10-20 тысяч iops.

Сеть тоже не виновата — её я пробовал бенчить с помощью nbd (network block device). При прямом доступе диск выдаёт 50000 iops, при пробросе диска с одного сервера на другой через nbd — 8000 iops. То есть, добавленная latency сети — примерно 0.1ms. Это не много.

И даже Bluestore не совсем виноват. На NVMe Bluestore с некоторыми тюнами всё-таки осиливает завершить запись примерно за 0.3мс. И в то же время код самого Ceph сжирает ещё 0.4мс.

По сути, нужно было бы добиться ситуации, в которой Ceph бы отъедал 0.1ms и Bluestore ещё 0.1ms. Сеть съест ещё 0.1ms и тогда на хорошей NVMe получится latency ~ 0.33ms, что в 1 поток соответствует 3000 операциям записи в секунду. До локальной SSD это всё равно не дотянуло бы, но, тем не менее, было бы уже очень-очень неплохо. Тогда, скажем, можно будет бороться за CPU: поставив самолётные CPU по 20000$ каждый, настроив ядро и снизив время Ceph+Bluestore ещё в 2 раза, вы получите уже 0.23ms = ~4350 iops. А допилив поддержку Infiniband, может, получите и все 6000 iops. Пока же код не оптимизирован… всё это — мёртвому припарки.

Авторы сейчас пытаются пилить новую реализацию OSD на асинхронном фреймворке Seastar (Crimson OSD), так что у нас есть теоретические шансы увидеть Ceph, который будет в несколько раз быстрее. Хотя, конечно, там вопрос далеко не только в многопоточности и блокировках — по идее, много съедает именно программная логика. Но так как её они фактически тоже частично переписывают с нуля — она тоже может улучшиться.

## 

DPDK и SPDK

- DPDK = Data Plane Developer Kit, быстрая библиотека от Intel для работы с (в основном) сетевыми устройствами в userspace, без задействования драйверов ядра
- SPDK = Storage Performance Developer Kit, основанная на DPDK библиотека для работы с NVMe SSD, тоже в пространстве пользователя. Ещё есть форк libnvme — SPDK, отвязанный от DPDK
- DPDK включается через ms_type=async+dpdk
- SPDK включается для NVMe-шек передачей в качестве пути девайса spdk:<серийный номер pcie устройства> и ручным созданием OSD по инструкции Manual Deployment
- Это в теории — на практике (проверялся Mimic 13.2.x) НИ ХРЕНА не работает, ни DPDK, ни SPDK
    - С DPDK Ceph «из коробки» даже не собирается — это в общем-то довольно легко исправить, но даже когда добиваешься сборки и запуска — OSD падают после обработки ~50 пакетов
    - С SPDK Ceph собирается и даже собран по умолчанию — но оно опять-таки не работает — вскоре после запуска OSD просто виснет в пространстве
    - Code is there, так что, вероятно, всё это можно исправить, если подебажить подольше
    - Есть сообщения, что SPDK всё-таки работает из коробки, просто не даёт никакого выигрыша производительности. Но мне пока завести его не удалось
- Однако в силу неоптимальной реализации самого Ceph ни от DPDK, ни от RDMA ожидать ускорения не приходится. Задержка Ceph в 10-100 раз выше сетевой задержки, так что, уменьшая сетевую задержку, добиться практически нечего. Один чувак даже проводил эксперимент — отрезал код AsyncMessenger-а от всего остального цефа и пробовал бенчить его отдельно: [https://www.spinics.net/lists/ceph-devel/msg43555.html](https://www.spinics.net/lists/ceph-devel/msg43555.html) — и получил всего лишь ~80000 iops.
- В перспективе SPDK будет на хрен не нужен, так как в ядро приняли штуку под названием io_uring: [https://lore.kernel.org/linux-block/20190116175003.17880-1-axboe@kernel.dk/](https://lore.kernel.org/linux-block/20190116175003.17880-1-axboe@kernel.dk/) - с ней обычный код прокачивает через Optane-ы практически столько же iops, сколько и SPDK, при заметно меньшем объёме геморроя на поддержку работы с SPDK/DPDK

## 

RAID WRITE HOLE

В RAID-е есть один интересный момент: при отказе диска и одновременном отключении питания RAID 5 может кораптить данные.

Суть такая: допустим, есть три диска в рейд5. Есть какая-то пара блоков данных A и B. Соответственно на дисках хранятся: A, B, A xor B.

Теперь представим, что мы пишем в блок B данные B2. Для этого нам надо обновить данные на двух дисках: B -> B2, A+B -> A+B2. Теперь представим, что один из них успел записать, а второй не успел. Тут вырубилось питание и одновременно сдох диск A (или диск сдох от умирания питания, или контроллер повис и ядро в панику упало...). Что мы имеем на дисках?

?, B2, A+B либо ?, B, A+B2.

Теперь при попытке восстановить A мы получим A+B+B2 => опа! Покорраптились данные, которые даже не записывались!

Из-за этого raid всегда делает полный resync после нештатного вырубания питания. И, собственно, такая же потеря данных возможна при отказе диска до завершения resync. mdadm RAID5 в таких ситуациях (когда одновременно потерян диск и массив помечен как грязный) просто отказывается стартовать.

И именно чтоб этого избежать, в цефе сделано полное журналирование всех данных на уровне отдельных дисков (т.е. OSD). Потому что других способов борьбы с этой проблемой НЕТ, а при работе по сети отказы гораздо более вероятны, чем при работе RAID-массива на локальных дисках. Даже write intent bitmap может только сказать вам, потеряли вы какие-то данные или нет, но не может помочь их восстановить, если они потеряны.

Так что Ceph надёжнее RAID-а. :) медленнее (на SSD). Но надёжнее и не требует resync-а.

## 

Краткий экскурс в устройство SSD и флеш-памяти

Особенность NAND флеш-памяти заключается в том, что пишется она мелкими блоками, а стирается большими. Актуальное соотношение для Micron 3D NAND — страница (page) 16 КБ, блок стирания (block) — 16 или 24 МБ (1024 или 1536 страниц, MLC/TLC соответственно). Случайное чтение страницы быстрое. Запись тоже, но писать можно только в предварительно стёртую область — а стирание медленное, да ещё и число стираний каждого блока ограничено — после нескольких тысяч (типичное значение для MLC) блок физически выходит из строя. В более дешёвых и плотных (MLC, TLC, QLC — 2-4 бита на ячейку) чипах лимит стираний меньше, в более дорогих и менее плотных (SLC, один бит на ячейку) — больше. Соответственно, при «тупом» подходе — если при записи каждого блока его просто стирать и перезаписывать — случайная запись во флеш-память, во-первых, будет очень медленной, а во-вторых, она будет быстро выводить её из строя.

Но почему тогда SSD быстрые? А потому, что внутри SSD на самом деле есть очень мощный и умный контроллер (1-2 гигагерца, типично 4 ядра или больше, примерно как процессоры мобильников), и на нём выполняется нечто, называемое Flash Translation Layer — прошивка, которая переназначает каждый мелкий логический сектор в произвольное место диска. FTL всё время поддерживает некоторое количество свободных стёртых блоков и направляет каждую мелкую случайную запись в новое место диска, в заранее стёртую область. Поэтому запись быстрая. Одновременно FTL делает дефрагментацию свободного места и Wear Leveling (распределение износа), направляя запись и перемещая данные так, чтобы все блоки диска стирались примерно одинаковое количество раз. Кроме того, во всех SSD некоторый % реального места зарезервирован под Wear Leveling и не виден пользователю («overprovision»), а в хороших серверных SSD этот процент весьма большой — например, в Micron 5100 Max это +60 % ёмкости (в Micron 5100 Eco — всего лишь +7.5 %, 1.92 ТБ SSD содержит 10 чипов NAND по 1.5 терабита и 2 по 768 гигабит).

Именно из наличия FTL вытекает и проблема с энергонезависимостью и «power loss protection»-ом. Карты отображения секторов — это метаданные, которые при сбросе кэша тоже нужно сбрасывать в постоянную память, и именно этот сброс и вносит торможение в работу настольных SSD с fsync.

Кстати, из размера страницы 16 КБ следует, что когда вы используете десктопную SSD под мелкую транзакционную перезапись, вы ещё и сильно снижаете срок её жизни, так как при перезаписи по 4 КБ с sync-ами write amplification составляет не менее 16 КБ / 4 КБ = 4. _Примечание: в современных SSD распространена такая вещь, как SLC Cache — использование части той же самой флеш-памяти в SLC-режиме для первых X гигабайт записи. При SLC-записи размер той же страницы, вероятно, уменьшается в 3 раза, так как вместо 3 бит в каждой ячейке хранится только 1. С другой стороны, это всё равно та же страница, которая номинально вмещает 16 КБ, так что как тут считать WA, не совсем ясно._

Дополнение: когда я попытался кого-то в списке рассылки полечить на тему, что «все SSD делают fsync», мне в ответ кинули статью: [https://www.usenix.org/system/files/conference/fast13/fast13-final80.pdf](https://www.usenix.org/system/files/conference/fast13/fast13-final80.pdf). В общем, суть статьи в том, что в 2013 году нормой было то, что SSD вообще не сбрасывали метаданные на диск при fsync, и при отключении питания это приводило к разным весёлым вещам вплоть до (!!!) полного отказа SSD.

Есть экземпляры старых SSD без конденсаторов (OCZ Vector/Vertex), которые при этом выдают большие iops на запись с fsync. Как это возможно? Неизвестно, но есть предположение, что суть как раз в небезопасности записи. Принцип работы флеш-памяти за последние годы вроде как не менялся — в SSD как раньше был FTL, так и сейчас FTL. Как достигнуть быстрой записи, если постоянно сбрасывать на диск карты трансляции — хз… наверное, если только сделать некое подобие лог-структурированной ФС внутри — писать всё время вперемешку метаданные и данные. Но при этом, по идее, при старте всё это «добро» придётся сканировать и старт/монтирование станет долгим. А в SSD долгого монтирования вроде как нет.

Ну и, собственно, «power loss protection», видимо, бывает простой, а бывает advanced. Простой означает просто «мы корректно делаем fsync и не сдохнем при отключении питания», а advanced означает наличие конденсаторов и быструю безопасную запись с fsync. Сейчас, в 2018—2019 годах, «обычный» PLP, похоже, всё-таки стал нормой и при отключении питания большая часть SSD терять данные и умирать уже не должна.

### Бонус: USB-флешки

А почему тогда USB-флешки такие медленные? Случайная запись на флешку 512-байтными (или 4 Кб) блоками обычно идёт со скоростью 2-3 iops. А флеш-память там примерно та же, что в SSD — ну, более дешёвые и мелкие чипы с меньшими размерами страницы и блока (часто 4 КБ страница и 4 МБ блок), но принцип тот же и разница в скорости не на порядки. Ответ кроется в том, что на флешках тоже есть FTL (и даже Wear Leveling), но по сравнению с SSD-шным он маленький и тупой. У него слабый процессор и мало памяти. Из-за малого объёма RAM контроллеру флешки, в отличие от контроллера SSD, негде хранить полную таблицу сопоставления виртуальных и реальных секторов — поэтому отображаются не сектора, а крупные блоки где-то по мегабайту или больше, и при записи есть лимит на количество «открытых» блоков. Как это происходит:

- Допустим, вы пишете в сектор X.
- Контроллер отображает блок, которому принадлежит этот сектор, на реальный блок, и «открывает» его — выделяет пустой блок, запоминает, что он «дочерний» для открытого и записывает туда один изменённый вами сектор.
- Таким макаром можно открыть максимум N разных блоков; число N обычно очень маленькое — от 3 до 6.
- Дальше если вы пишете следующий сектор из уже открытого блока — он просто записывается в его дочерний блок (что быстро).
- Если же следующий записываемый сектор принадлежит другому блоку — какой-то из открытых блоков приходится закрывать и «сливать» содержимое дочернего блока с оригинальным.

Для копирования больших файлов на флешку, отформатированную в любую из стандартных файловых систем, двух блоков достаточно: в один открытый блок пишутся данные, во второй — метаданные записываемого файла. Запись последовательная, всё быстро. А вот при случайной записи вы перестаёте попадать в уже «открытые» блоки и каждая операция записи превращается в полное стирание. Тут-то и начинаются тормоза…

## 

Пример теста от Micron

Пример самолётного сетапа от Micron с процами по полляма (2x Xeon Platinum 8168), 2x100-гбит сетью (точнее 2x2x100, так как 2 карты по 2 порта) и 10x топовыми NVMe (с конденсаторами, ага) в каждом узле, 4 узла, репликация 2x: [https://www.micron.com/resource-details/30c00464-e089-479c-8469-5ecb02cfe06f](https://www.micron.com/resource-details/30c00464-e089-479c-8469-5ecb02cfe06f)

Всего 367011 iops на запись в пике на весь кластер, при 100 % загрузке CPU. Казалось бы, довольно много, но если поделить 367000/40 osd — получится 9175 иопс на 1 osd. С учётом репликации на диски нагрузка двойная, выходит, 18350 иопс. Ок, журналы тоже удваивают нагрузку, итого — 36700 iops на запись смог выжать ceph из одной NVMe… которая сама по спеке может 260000 иопс в одиночку. Вот такой вот overhead.

Данных по задержкам в 1 поток нет (а было бы интересно узнать).

Примечание: PDF-ка по ссылке обновлена, новый результат с теми же тюнами, что ниже, составил 479882 iops на запись и 2277453 iops на чтение. Старая [тут](https://yourcmc.ru/wiki/images/c/c0/Micron_9200_ceph_3.0_reference_architecture.pdf "Micron 9200 ceph 3.0 reference architecture.pdf"). Что и подтверждает, что разница между Micron 9200 и 9300 для Ceph незаметна.

### Апдейт

[https://www.micron.com/-/media/client/global/documents/products/other-documents/micron_9300_and_red_hat_ceph_reference_architecture.pdf](https://www.micron.com/-/media/client/global/documents/products/other-documents/micron_9300_and_red_hat_ceph_reference_architecture.pdf)

NVMe обновились до Micron 9300 (максимальной ёмкости 12.8 ТБ). iops-ов такие диски дают даже не 260 тыс., а 310 тыс. Всё остальное осталось прежним. Итого 100 клиентами на запись сняли 477029 iops. Однако надо понимать, что каждому клиенту при этом досталось лишь 4770 iops. 10 клиентами сняли 294000 iops — то есть на 1 клиента 29400 иопс, что всё-таки поприличней.

Почему стало лучше? Предположительно, благодаря тюнингу. По сравнению с прошлым тестом они:

- отключили чексуммы мессенджера (ms_crc_data=false) и чексуммы блюстора (bluestore_csum_type=none)
- затюнили rocksdb: bluestore_rocksdb_options = compression=kNoCompression,max_write_buffer_number=64,min_write_buffer_number_to_merge=32,recycle_log_file_num=64,compaction_style=kCompactionStyleLevel,  
    write_buffer_size=4MB,target_file_size_base=4MB,max_background_compactions=64,level0_file_num_compaction_trigger=64,level0_slowdown_writes_trigger=128,  
    level0_stop_writes_trigger=256,max_bytes_for_level_base=6GB,compaction_threads=32,flusher_threads=8,compaction_readahead_size=2MB
    - 64x32x4 MB memtable (number x merge x size) вместо стандартных 4x1x256 MB. Скорее всего, это и сыграло основную роль. Эффект не совсем очевиден, но, вероятно, это снижает нагрузку на CPU, потому что поиск в 64 маленьких memtable быстрее, чем поиск в 1 (или 4) больших.
    - сильно изменён max_bytes_for_level_base — с 256 мб он поднят до 6 гб!
    - добавлены потоки compaction-а.
- выдали 14 гб RAM каждому OSD
- osd_max_pg_log_entries=osd_min_pg_log_entries=osd_pg_log_dups_tracked=osd_pg_log_trim_min = 10 (хз, по-моему, ничего не даёт)

Также надо отметить, что:

- cephx у них уже был отключён. В этот раз зачем-то добавили и отключение подписей — видимо, читали мою статью. Но это нафиг не надо, при отключенном cephx подписи можно уже не отключать.
- debug objecter = 0/0 и вообще отключенные дебаги у них тоже уже были
- с prefer_deferred_size и min_alloc_size они, видимо, не игрались
- обновлённые диски не играют никакой роли гарантированно. 260000 или 310000 iops — для цефа никакой разницы нет.

### Бонус: висян (vSAN)

[Micron Accelerated All-Flash SATA vSAN 6.7 Solution](https://media-www.micron.com/-/media/client/global/documents/products/other-documents/micron_vsan_6,-d-,7_on_x86_smc_reference_architecture.pdf)

Конфигурация серверов:

- 384 GB RAM 2667 MHz
- 2X Micron 5100 MAX 960 GB (randread: 93k iops, randwrite: 74k iops)
- 8X Micron 5200 ECO 3.84TB (randread: 95k iops, randwrite: 17k iops)
- 2x Xeon Gold 6142 (16c 2.6GHz)
- Mellanox ConnectX-4 Lx
- Connected to 2x Mellanox SN2410 25GbE switches

«Соответствует конфигурации VMWare AF-6, по заявлениям дающей от 50K iops чтения на каждый сервер»

- 2 реплики (аналог size=2 в цефе)
- 4 сервера
- 4 ВМ на каждом сервере
- 8 диска на каждую ВМ
- 4 потока на каждый диск

Суммарный параллелизм ввода/вывода: 512

100%/70%/50%/30%/0% write

- «Baseline» (данные умещаются в кэш): 121k/178k/249k/314k/486k iops
- «Capacity» (не умещаются): 51k/66k/90k/134k/363k
- Задержка равна 1000*512/IOPS миллисекунд во всех тестах (1000мс * параллелизм / iops)
- **Нет тестов задержки с низким параллелизмом**
- **Нет тестов линейного чтения/записи**

Заключение:

- ~3800 iops на запись в пересчёте на каждый диск данных
- ~1600 iops на запись в пересчёте на диск, если данные не влезают в кэш
- ~15000 iops на чтение в пересчёте на каждый диск данных
- ~11400 iops на чтение в пересчёте на диск, если данные не влезают в кэш
- Итого: при параллельной нагрузке в данном тесте vSAN смотрится хуже, чем Ceph
- С другой стороны, vSAN гиперконвергентный, а Ceph, в идеале, нет — или тормозит сильнее, чем мог бы

## 

Модели

- Micron 5100/5200, 9300. Возможно также 5300, 7300
- HGST SN260
- Intel P4500

[https://docs.google.com/spreadsheets/d/1E9-eXjzsKboiCCX-0u0r5fAjjufLKayaut_FOPxYZjc](https://docs.google.com/spreadsheets/d/1E9-eXjzsKboiCCX-0u0r5fAjjufLKayaut_FOPxYZjc)

## 

Резюме

Резюмируя вышесказанное, для random write iops:

- Использовать только SSD с конденсаторами. NVMe это тоже касается. Подсказка: 99 % desktop SSD и NVMe конденсаторов не имеют.
- …и надо отключать этим SSD кэш (hdparm -W 0), если они SATA!
- В случае HDD — полезны HDD со встроенным SSD-кэшем. Например, почти все большие Seagate EXOS таковы, хоть на них это часто и не заявлено.
- …и им тоже бывает полезно отключить кэш (hdparm -W 0). Только проверьте, что это улучшает iops-ы, а не ухудшает.
- SMR HDD не использовать под Ceph никогда.
- Отключить powersave: cpupower frequency-set -g performance, cpupower idle-set -D 0
- Отключить электронные подписи:  
    cephx_require_signatures = false  
    cephx_cluster_require_signatures = false  
    cephx_sign_messages = false  
    (и монтировать rbd map / cephfs ядерным драйвером с опциями -o nocephx_require_signatures,nocephx_sign_messages)
- min_alloc_size=16384 (так и было по умолчанию, в последних версиях поменяли на 4096 и я рекомендовал 4096, а похоже, что зря)
- Актуально для версий до Nautilus включительно — [global] debug objecter = 0/0 (там большой тормоз на клиентской стороне)
- В QEMU юзать virtio
- Если у вас All-flash кластер и вам критичны либо iops-ы случайной _синхронной_ записи (fsync/O_SYNC, например в случае СУБД), либо суммарные iops-ы _параллельной_ случайной записи, то нужно отключить rbd cache (в qemu опция cache=none). Если не критичны или у вас HDD, лучше поставить cache=writeback.
- Чтобы мог работать cache=unsafe, поставить [global] rbd cache writethrough until flush = false
- ~~Для HDD-only или Bad-SSD-Only и версий до Nautilus включительно — снять ручник [https://github.com/ceph/ceph/pull/26909](https://github.com/ceph/ceph/pull/26909)~~ - уже влит
- Внутри ВМ: mount -o lazytime

## 

Примечание

Написанное в статье актуально для версий Ceph, доступных на момент последней правки (см. «История» вверху страницы). Конкретно — 12-15 luminous-octopus. Различия между версиями минимальны, всё пока что актуально. Если вдруг в будущем что-то пофиксят и всё вдруг станет чудесно быстрым — сам побегу обновляться первым и поправлю статью :).

## 

См. также

- [https://www.ixsystems.com/community/resources/list-of-known-smr-drives.141/](https://www.ixsystems.com/community/resources/list-of-known-smr-drives.141/) - список SMR дисков (вероятно, не полный)
- [http://vasilisc.com/bluestore-ceph-2017](http://vasilisc.com/bluestore-ceph-2017) - кое-что про bluestore, местами не совсем верно, но тем не менее
- [https://amarao-san.livejournal.com/3437997.html](https://amarao-san.livejournal.com/3437997.html) - «IOPS не существует» — сказ о latency
    
    _Прим.вред — iops существуют, но с обязательным указанием режима тестирования и параллелизма_
    
- [https://yourcmc.ru/afr-calc/](https://yourcmc.ru/afr-calc/) - мой калькулятор вероятности потери данных в кластере Ceph в зависимости от размера кластера и схемы отказоустойчивости

## 

Советы лучших собаководов

Офлайн балансер:

ceph osd getmap -o om; osdmaptool om --upmap upmap.sh --upmap-deviation 0; bash upmap.sh; rm -f upmap.sh om

[Читать на другом языке](https://yourcmc.ru/wiki/%D0%A1%D0%BB%D1%83%D0%B6%D0%B5%D0%B1%D0%BD%D0%B0%D1%8F:MobileLanguages/%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph)

[Последняя правка сделана 2 года назад](https://yourcmc.ru/wiki/%D0%A1%D0%BB%D1%83%D0%B6%D0%B5%D0%B1%D0%BD%D0%B0%D1%8F:History/%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph) участником [VitaliyFilippov](https://yourcmc.ru/wiki/Special:UserProfile/VitaliyFilippov)

- ## YourcmcWiki
    
     
    - Мобильный
    - [Стационарный](https://yourcmc.ru/wiki/index.php?title=%D0%9F%D1%80%D0%BE%D0%B8%D0%B7%D0%B2%D0%BE%D0%B4%D0%B8%D1%82%D0%B5%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D1%8C_Ceph&mobileaction=toggle_view_desktop)
- Содержимое доступно в соответствии с [CC-BY-SA](http://creativecommons.org/licenses/by-sa/3.0/), если не указано иное.

- [Конфиденциальность](https://yourcmc.ru/wiki/YourcmcWiki:%D0%9F%D0%BE%D0%BB%D0%B8%D1%82%D0%B8%D0%BA%D0%B0_%D0%BA%D0%BE%D0%BD%D1%84%D0%B8%D0%B4%D0%B5%D0%BD%D1%86%D0%B8%D0%B0%D0%BB%D1%8C%D0%BD%D0%BE%D1%81%D1%82%D0%B8 "YourcmcWiki:Политика конфиденциальности")