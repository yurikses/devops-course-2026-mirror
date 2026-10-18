#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"


DRY_RUN_FLAG=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN_FLAG="--dry-run"
elif [[ $# -gt 0 ]]; then
    echo "Неизвестный аргумент: $1" >&2
    echo "Использование: $0 [--dry-run]" >&2
    exit 1
fi


if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует. Доставка отменена." >&2
    exit 1
fi


if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения. Доставка отменена." >&2
    exit 1
fi


SSH_OPTS="ssh -o BatchMode=yes -o ConnectTimeout=5"

RSYNC_ARGS=(
    -avz
    --delete
    --chmod=D755,F644
    -e "$SSH_OPTS"
)

if [[ -n "$DRY_RUN_FLAG" ]]; then
    RSYNC_ARGS+=("--dry-run")
fi

RSYNC_ARGS+=("${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/")

if ! rsync "${RSYNC_ARGS[@]}"; then
    echo "Ошибка синхронизации файлов." >&2
    exit 1
fi


if [[ -n "$DRY_RUN_FLAG" ]]; then
    echo "План операций выведен. Состояние сервера не изменено."
    exit 0
fi

if ! curl -f -s -o /dev/null --cacert "$CA_CERT" "$SITE_URL"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен или сертификат не прошёл проверку." >&2
    exit 1
fi


COMMIT_HASH="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
echo "Деплой успешно завершён. Хеш коммита: ${COMMIT_HASH}"
exit 0