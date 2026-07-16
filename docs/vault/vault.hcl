storage "file" { # Указываем что храним секреты в файле, а не БД
  path = "/mnt/vault/data" # Путь до файла с данным
}
listener "tcp" { # Указываем какой сервер слушаем
  address     = "0.0.0.0:8200" 
  # tls_cert_file = "/etc/vault/vault-cert.pem"
  # tls_key_file  = "/etc/vault/vault-key.pem"
  tls_disable = 1 # Отключение https://
}
ui = true # Включить UI
disable_mlock = true