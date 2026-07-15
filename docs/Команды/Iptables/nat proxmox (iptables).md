#comand #linux #iptables
```
iptables -A FORWARD -i eth1(внутрений) -o eth0(внешний) -j ACCEPT  
```
```
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT  
```
```
iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -o eth1 -j SNAT --to-source 84.201.168.122
```
