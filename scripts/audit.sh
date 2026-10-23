#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
REMOTE="devops"

# Функция для выполнения команд на удалённом сервере
run_remote() {
    ssh "$REMOTE" "$1" 2>/dev/null
}

check() {
    local desc="$1" expected="$2" actual="$3"
    # Убираем возможные \r (CRLF), если вывод сервера содержит Windows-окончания
    actual=$(echo "$actual" | tr -d '\r')
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"; ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
    fi
}

echo "Аудит конфигурации сервера: $REMOTE, $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" \
    "$(run_remote "sudo sshd -T 2>/dev/null | awk '/^permitrootlogin/{print \$2}'")"
check "Парольная аутентификация отключена" "no" \
    "$(run_remote "sudo sshd -T 2>/dev/null | awk '/^passwordauthentication/{print \$2}'")"
check "Порт SSH отличен от 22" "true" \
    "$(run_remote "port=\$(sudo sshd -T 2>/dev/null | awk '/^port/{print \$2}'); [[ \"\$port\" != '22' ]] && echo true || echo false")"
check "MaxAuthTries равно 3" "3" \
    "$(run_remote "sudo sshd -T 2>/dev/null | awk '/^maxauthtries/{print \$2}'")"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" \
    "$(run_remote "sudo ufw status | awk '/^Status:/{print \$2}'")"
check "Политика по умолчанию для входящего трафика — deny" "deny" \
    "$(run_remote "sudo ufw status verbose | awk '/^Default:/{print \$2}'")"

echo "[3] Учётные записи"
run_remote "awk -F: '\$3>=1000 && \$3<65534 {printf \" %s (uid=%s)\\n\",\$1,\$3}' /etc/passwd"

echo "[4] Веб-сервер"
check "Служба nginx активна" "active" \
    "$(run_remote "systemctl is-active nginx")"
check "Конфигурация nginx синтаксически корректна" "0" \
    "$(run_remote "sudo nginx -t >/dev/null 2>&1; echo \$?")"

CERT_MIN_DAYS="${CERT_MIN_DAYS:-30}"
check "Сертификат истекает не ранее чем через ${CERT_MIN_DAYS} дн." "0" \
    "$(run_remote "openssl x509 -checkend $((CERT_MIN_DAYS * 86400)) -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo \$?")"

check "Нет файлов o+w в каталоге ресурса, права ключа 600" "0:600" \
    "$(run_remote "echo \$(find /var/www/devops-site -perm -o+w 2>/dev/null | wc -l):\$(sudo stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)")"

echo "[5] Контейнеризация"
check "Служба docker активна" "active" \
    "$(run_remote "systemctl is-active docker")"
check "Контейнер СУБД в состоянии healthy" "healthy" \
    "$(run_remote "docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null")"
check "Порты 5000 и 5432 прослушиваются только на 127.0.0.1" "0" \
    "$(run_remote "ss -tlnH 2>/dev/null | awk '\$4 ~ /:(5000|5432)\$/ && \$4 !~ /^127\\.0\\.0\\.1:/ {c++} END{print c+0}'")"
check "Права файла ~/app/.env равны 600" "600" \
    "$(run_remote "stat -c '%a' ~/app/.env 2>/dev/null")"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1