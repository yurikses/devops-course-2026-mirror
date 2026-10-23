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


## 9. Контейнер

### Установка Docker Engine
- Docker Engine установлен из официального репозитория Docker (пакет `docker-ce`); пакет `docker.io` из репозитория Ubuntu не используется.
- Порядок установки: добавление GPG-ключа и репозитория Docker, затем `sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`.
- Версия: `docker version` — раздел `Server` присутствует; на момент настройки — Docker Engine 28.x (точное значение фиксируется выводом команды).
- Плагин Compose: `docker compose version` (Docker Compose v2).
- Служба: `docker.service` — `active (running)`, включена в автозапуск (`systemctl enable docker`).

### Учётная запись и группа docker
- Учётная запись `devops` добавлена в группу `docker`: `sudo usermod -aG docker devops`; изменения применены в новой SSH-сессии.
- Участники группы `docker`: `devops`. Другие учётные записи в группу не включены: членство в группе `docker` фактически эквивалентно правам root (возможность смонтировать каталог `/` хоста в контейнер с записью).
- Проверка: `docker run --rm hello-world` без `sudo` — успешно.

### Расположение проекта
- Каталог проекта на сервере: `/home/devops/app`.
- Доставка с хостовой системы: `rsync -avz --delete --exclude=.env app/ devops:app/`. Параметр `--exclude=.env` обязателен: файл `.env` создаётся только на сервере, и без исключения `--delete` удалил бы его при следующей доставке.
- Состав каталога: `Dockerfile`, `.dockerignore`, `app.py`, `requirements.txt`, `docker-compose.yml`, `.env`, `.env.example`.
- Файл `.env` в репозиторий не включается (`.gitignore`).

### Файл .env
- Путь: `/home/devops/app/.env`.
- Права: `600` (`-rw-------`), владелец `devops:devops`.
- Содержимое: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` (случайное значение, `openssl rand -hex 16`), `DB_HOST=db`.
- Шаблон `.env.example` содержит только имена переменных и заглушки; секреты в репозиторий не попадают.
- Команды формирования: `cp .env.example .env`, `chmod 600 .env`, `sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 16)/" .env`.

### Публикуемые порты и адреса
- Сервис `app`: публикация `127.0.0.1:5000:5000` — порт 5000 доступен только на loopback-интерфейсе сервера; из сети и с хостовой системы напрямую недоступен.
- Сервис `db`: порт не публикуется; приложение обращается к СУБД по имени `db` через сеть проекта `backend` (встроенный DNS Docker Compose).
- Проверка: `sudo ss -tlnp | grep -E ':(5000|5432)\b'` — единственный прослушиваемый сокет `127.0.0.1:5000`; порт 5432 не прослушивается.
- Порт 5000 не разрешён в UFW, но публикация на `127.0.0.1` исключает доступ извне. Публикация на `0.0.0.0` обошла бы UFW через цепочки iptables Docker, поэтому используется только адрес loopback.

### Именованные тома
- Том: `app_db_data` (объявлен как `db_data` в `docker-compose.yml`), монтируется в `/var/lib/postgresql/data` сервиса `db`.
- Том сохраняется при `docker compose down` и удаляется только при `docker compose down -v`.
- Тег образа СУБД: `postgres:16-alpine` (фиксированная основная версия; формат данных несовместим между основными версиями PostgreSQL).

### Обратный прокси-сервер
- Nginx из практической работы № 6 (`/etc/nginx/sites-available/devops-site`) дополнен блоком `location /app/` в секции HTTPS (`server` с `listen 443 ssl`).
- Конфигурация (отступ 4 пробела — это блок кода в Markdown):

    location /app/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

- Завершающий `/` в `proxy_pass` заменяет префикс `/app/` на `/`: запрос `/app/health` передаётся приложению как `/health`.
- Проверка и применение: `sudo nginx -t && sudo systemctl reload nginx`.
- Доступ: `https://devops.local/app/` и `https://devops.local/app/health`; статический ресурс `https://devops.local/` сохраняется.
- При остановленном контейнере приложения Nginx возвращает `502 Bad Gateway`; в `/var/log/nginx/devops-site.error.log` — запись `connect() failed (111: Connection refused) while connecting to upstream`.

### Снимок состояния
- `05-docker-compose` — снимок после запуска проекта (`docker compose up -d --build`), проверки состояния `db` (healthy) и сохранности данных.

### Проверка
- `docker compose ps` — сервис `db` в состоянии `(healthy)`, сервис `app` — `Up`.
- `scripts/audit.sh`, раздел `[5] Контейнеризация` — проверки: активность `docker.service`; состояние `healthy` контейнера СУБД; отсутствие прослушивания портов 5000 и 5432 на адресах, кроме `127.0.0.1`; права `600` на `~/app/.env`.
