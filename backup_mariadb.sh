#!/bin/bash

set -o pipefail

# Configurações
DB_HOST=""
DB_PORT="3306"
DB_USER=""
DB_PASS=""

BACKUP_BASE_DIR="/home/higorcos/backups/mariadb"
LOG_FILE="$BACKUP_BASE_DIR/backup_mariadb.log"
KEEP_LAST=7

mkdir -p "$BACKUP_BASE_DIR"

NOW=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$NOW] Buscando lista de bancos..." >> "$LOG_FILE"

DATABASES=$(mysql \
  -h "$DB_HOST" \
  -P "$DB_PORT" \
  -u "$DB_USER" \
  -p"$DB_PASS" \
  -N -e "SHOW DATABASES;" | grep -Ev "^(information_schema|performance_schema|mysql|sys)$")

if [ -z "$DATABASES" ]; then
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$NOW] ERRO: Nenhum banco encontrado ou falha ao conectar no MariaDB." >> "$LOG_FILE"
  exit 1
fi

for DB_NAME in $DATABASES; do
  DATE=$(date +"%Y-%m-%d_%H-%M-%S")
  NOW=$(date +"%Y-%m-%d %H:%M:%S")

  BACKUP_DIR="$BACKUP_BASE_DIR/$DB_NAME"
  BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_backup_$DATE.sql.gz"

  mkdir -p "$BACKUP_DIR"

  echo "[$NOW] Iniciando backup do banco $DB_NAME..." >> "$LOG_FILE"

  mysqldump \
    -h "$DB_HOST" \
    -P "$DB_PORT" \
    -u "$DB_USER" \
    -p"$DB_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    "$DB_NAME" 2>> "$LOG_FILE" | gzip > "$BACKUP_FILE"

  if [ $? -eq 0 ] && [ -s "$BACKUP_FILE" ]; then
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] Backup concluído com sucesso: $BACKUP_FILE" >> "$LOG_FILE"

    ls -1t "$BACKUP_DIR"/"${DB_NAME}"_backup_*.sql.gz 2>/dev/null \
      | tail -n +$((KEEP_LAST + 1)) \
      | xargs -r rm -f

    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] Limpeza concluída. Mantendo os últimos $KEEP_LAST backups de $DB_NAME." >> "$LOG_FILE"
  else
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] ERRO ao realizar backup do banco $DB_NAME" >> "$LOG_FILE"
    rm -f "$BACKUP_FILE"
  fi

  echo "--------------------------------------------------" >> "$LOG_FILE"
done
