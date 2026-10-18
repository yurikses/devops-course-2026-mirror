# Конфигурация виртуальной машины devops-vm
## 1. Параметры машины
- Гипервизор: Oracle VirtualBox, имя ВМ: `devops` (Ubuntu 24.10, x86_64).
- Память: 2048 Мб; видеопамять: 16 Мб.
- Количество ядер: 2.
- Диск: один SATA диск, 25 Гб.

## 2. Сетевые интерфейсы
- Адаптер 1, VirtualBox NAT, IPv4 `10.0.2.15/24`, шлюз `10.0.2.2`; основной выход в сеть.
- Адаптер 2, VirtualBox Host-only (`VirtualBox Host-Only Ethernet Adapter`), IPv4 `192.168.56.102/24`; доступ с хоста/из host-only сети.

## 3. Правило проброса портов
- VirtualBox NAT: TCP `127.0.0.1:2222` хоста -> `10.0.2.15:2222` (SSH гостя).
- В конфигурации VirtualBox: `ssh,tcp,127.0.0.1,2222,,2222`.
- Проверка с хоста: `ssh -p 2222 devops@127.0.0.1`.

## 4. Учётные записи
- `devops` группа `devops` группы `sudo`, `users`, вход по SSH-ключу `/home/devops/.ssh/authorized_keys`, парольная SSH-аутентификация отключена.
- `student`  группа `student`, ввод пароля.

## 5. Служба SSH
- Служба: `ssh.service`, конфигурация: `/etc/ssh/sshd_config`; дополнительные настройки: `/etc/ssh/sshd_config.d/99-hardening.conf`.
- `Port 2222`; `PermitRootLogin no`; `PasswordAuthentication no`; `PubkeyAuthentication yes`; `PermitEmptyPasswords no`.
- `MaxAuthTries 3`; `LoginGraceTime 30`; `AllowUsers devops`; `X11Forwarding no`.
- `ClientAliveInterval 300`; `ClientAliveCountMax 2`; `KbdInteractiveAuthentication no`; `UsePAM yes`.
- Восстановление: записать перечисленные директивы в `99-hardening.conf`, затем выполнить `sshd -t && systemctl restart ssh`.

## 6. Правила межсетевого экрана
- UFW активен (`Status: active`), IPv6 включён.
- Политики по умолчанию: входящий трафик `deny`/`DROP`, исходящий `allow`/`ACCEPT`, forwarding `deny`/`DROP`.
- Разрешены входящие TCP-порты `80` (HTTP) и `443` (HTTPS).
- Разрешён входящий TCP-порт `2222` (SSH); остальные входящие соединения запрещены политикой по умолчанию.

## 7. Снимки состояния
- `01-clean-install`; исходный снимок для проверки восстановления.
- `02-keys-configured`; снимок после настройки ключей аутентификации.
- `03-ssh-hardened`; снимок после настройки SSH.
- `04-nginx-https`; снимок после настройки Nginx, перевода на HTTPS и публикации ресурса.

## 8. Веб-сервер
- Устанавливаемый пакет: `nginx` (Ubuntu 24.10, версия 1.24.0).
- Установка: `sudo apt update && sudo apt install -y nginx`.
- Служба: `nginx.service`; команды управления: `systemctl status nginx`, `systemctl reload nginx` (без разрыва соединений), `systemctl restart nginx` (с остановкой).
- Синтаксическая проверка конфигурации: `sudo nginx -t`.
- Основной конфигурационный файл: `/etc/nginx/nginx.conf`.
- Каталог активных конфигураций: `/etc/nginx/sites-enabled/` (символические ссылки).
- Каталог всех конфигураций: `/etc/nginx/sites-available/`.
- Стандартный ресурс Nginx отключён: удалена ссылка `/etc/nginx/sites-enabled/default`, конфигурация сохранена.

### Каталог ресурса
- Путь: `/var/www/devops-site`.
- Владелец и группа: `devops:devops` (рекурсивно).
- Права: каталоги `755` (`drwxr-xr-x`), файлы `644` (`-rw-r--r--`).
- Команды создания: `sudo mkdir -p /var/www/devops-site`, `sudo chown -R devops:devops /var/www/devops-site`

### Конфигурация ресурса
- Путь: `/etc/nginx/sites-available/devops-site` (символическая ссылка `/etc/nginx/sites-enabled/devops-site`).
- Доменное имя (`server_name`): `devops.local`.
- Порты: `80` (HTTP, блок перенаправления на HTTPS) и `443` (HTTPS с TLSv1.2/TLSv1.3).
- Директивы: `root /var/www/devops-site; index index.html; try_files $uri $uri/ =404; error_page 404 /404.html;`.
- Журналы: `/var/log/nginx/devops-site.access.log` и `/var/log/nginx/devops-site.error.log`.
- Применение конфигурации: `sudo nginx -t && sudo systemctl reload nginx`.

### TLS-сертификат (самоподписанный)
- Путь к сертификату: `/etc/ssl/certs/devops.crt`, права `644`, владелец `root:root`.
- Путь к закрытому ключу: `/etc/ssl/private/devops.key`, права `600`, владелец `root:root` (доступен только главному процессу Nginx, запущенному от `root`).
- Срок действия: 365 дней.
- Субъект: `CN=devops.local`.
- Расширение SAN: `DNS:devops.local` (имя ресурса проверяется клиентами именно по SAN, CN не учитывается).
- Команда формирования: `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048`
    `-keyout /etc/ssl/private/devops.key`
    `-out /etc/ssl/certs/devops.crt`
    `-subj "/CN=devops.local"`
    `-addext "subjectAltName=DNS:devops.local"`
- Примечание: параметр `-nodes` оставляет ключ незашифрованным (без запроса пароля при запуске службы); IP-адрес в SAN не включается, так как адрес Host-only сегмента назначается по DHCP и может измениться.



