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
- Разрешён входящий TCP-порт `2222` (SSH); остальные входящие соединения запрещены политикой по умолчанию.

## 7. Снимки состояния
- `01-clean-install`; исходный снимок для проверки восстановления.
- `02-keys-configured`; снимок после настройки ключей аутентификации.
- `03-ssh-hardened`; текущий снимок после настройки SSH.
