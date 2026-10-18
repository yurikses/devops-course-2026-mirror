#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"; ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
# TODO 1: значение параметра port отлично от 22
check "Порт SSH отличен от 22" "true" \
    "$( [[ "$(sudo sshd -T | awk '/^port/{print $2}')" != "22" ]] && echo true || echo false )"
# TODO 2: значение параметра maxauthtries равно 3
check "MaxAuthTries равно 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
# TODO 3: политика по умолчанию для входящего трафика равна deny
check "Политика по умолчанию для входящего трафика — deny" "deny" \
    "$(sudo ufw status verbose | awk '/^Default:/{print $2}')"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# а) служба nginx активна
check "Служба nginx активна" "active" "$(systemctl is-active nginx)"
# б) конфигурация синтаксически корректна
check "Конфигурация nginx синтаксически корректна" "0" \
    "$(sudo nginx -t >/dev/null 2>&1; echo $?)"
# в) сертификат истекает не ранее чем через 30 дней (порог переопределяется для проверки)
CERT_MIN_DAYS="${CERT_MIN_DAYS:-30}"
check "Сертификат истекает не ранее чем через ${CERT_MIN_DAYS} дн." "0" \
    "$(openssl x509 -checkend $((CERT_MIN_DAYS * 86400)) -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo $?)"
# г) нет файлов с записью для всех + права ключа 600
check "Нет файлов o+w в каталоге ресурса, права ключа 600" "0:600" \
    "$(find /var/www/devops-site -perm -o+w | wc -l):$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1