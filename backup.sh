#!/usr/bin/env bash
# Резервная копия базы рецептов: дамп PostgreSQL + архив настроек. Правило 3-2-1: 3 копии, 2 носителя, 1 вне сервера.
# В базе проверенные рецепты и карты клиентов (медицинские данные): храните копии закрытыми. Не удаляйте оригиналы, пока восстановление не проверено.
# Ночной запуск по cron (пример): 30 3 * * * cd /opt/optical-rx && bash backup.sh >> backup.log 2>&1
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "нет файла .env рядом со скриптом"; exit 1; }
set -a; . ./.env; set +a
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="${BACKUP_DIR:-./backups}"
mkdir -p "$OUT"
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$OUT/db_${STAMP}.sql.gz"
tar czf "$OUT/config_${STAMP}.tar.gz" .env docker-compose.yml init.sql
find "$OUT" -name 'db_*.sql.gz' -mtime +14 -print   # только показывает копии старше 14 дней; удаляйте вручную после проверки восстановления
ls -lh "$OUT"/*"${STAMP}"*
echo "Готово. Скопируйте файлы из $OUT на второй носитель и вне сервера, затем проверьте восстановление на тестовой машине."
