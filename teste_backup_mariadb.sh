#!/bin/bash

set -o pipefail

# MariaDB onde o teste será feito
# Idealmente, use um banco local ou servidor separado de teste
TEST_DB_HOST="127.0.0.1"
TEST_DB_PORT="3306"
TEST_DB_USER="root"
TEST_DB_PASS="root"

BACKUP_BASE_DIR="/home/higorcos/backups/mariadb"
LOG_FILE="$BACKUP_BASE_DIR/teste_backup_mariadb.log"

mkdir -p "$BACKUP_BASE_DIR"

NOW=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$NOW] Iniciando teste de restauração usando pastas de backup..." >> "$LOG_FILE"

for BACKUP_DIR in "$BACKUP_BASE_DIR"/*; do
  if [ ! -d "$BACKUP_DIR" ]; then
    continue
  fi

  DB_NAME=$(basename "$BACKUP_DIR")

  # Ignora pastas que não devem ser testadas, se necessário
  if [[ "$DB_NAME" == "logs" ]]; then
    continue
  fi

  LAST_BACKUP=$(ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -n 1)

  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$NOW] Verificando pasta $BACKUP_DIR..." >> "$LOG_FILE"

  if [ -z "$LAST_BACKUP" ]; then
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] AVISO: Nenhum arquivo .sql.gz encontrado em $BACKUP_DIR" >> "$LOG_FILE"
    echo "--------------------------------------------------" >> "$LOG_FILE"
    continue
  fi

  if [ ! -s "$LAST_BACKUP" ]; then
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] ERRO: Backup vazio: $LAST_BACKUP" >> "$LOG_FILE"
    echo "--------------------------------------------------" >> "$LOG_FILE"
    continue
  fi

  gzip -t "$LAST_BACKUP" 2>> "$LOG_FILE"

  if [ $? -ne 0 ]; then
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] ERRO: Arquivo gzip inválido ou corrompido: $LAST_BACKUP" >> "$LOG_FILE"
    echo "--------------------------------------------------" >> "$LOG_FILE"
    continue
  fi

  TEST_DB="teste_restore_${DB_NAME}"

  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$NOW] Criando banco temporário $TEST_DB..." >> "$LOG_FILE"

  mysql \
    -h "$TEST_DB_HOST" \
    -P "$TEST_DB_PORT" \
    -u "$TEST_DB_USER" \
    -p"$TEST_DB_PASS" \
    -e "DROP DATABASE IF EXISTS \`$TEST_DB\`; CREATE DATABASE \`$TEST_DB\`;" 2>> "$LOG_FILE"

  if [ $? -ne 0 ]; then
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] ERRO: Não foi possível criar banco temporário $TEST_DB" >> "$LOG_FILE"
    echo "--------------------------------------------------" >> "$LOG_FILE"
    continue
  fi

  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$NOW] Restaurando backup $LAST_BACKUP em $TEST_DB..." >> "$LOG_FILE"

  gunzip -c "$LAST_BACKUP" | mysql \
    -h "$TEST_DB_HOST" \
    -P "$TEST_DB_PORT" \
    -u "$TEST_DB_USER" \
    -p"$TEST_DB_PASS" \
    "$TEST_DB" 2>> "$LOG_FILE"

  if [ $? -eq 0 ]; then
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] OK: Restore validado com sucesso para $DB_NAME usando $LAST_BACKUP" >> "$LOG_FILE"
  else
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$NOW] ERRO: Falha ao restaurar backup $LAST_BACKUP" >> "$LOG_FILE"
  fi

  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$NOW] Removendo banco temporário $TEST_DB..." >> "$LOG_FILE"

  mysql \
    -h "$TEST_DB_HOST" \
    -P "$TEST_DB_PORT" \
    -u "$TEST_DB_USER" \
    -p"$TEST_DB_PASS" \
    -e "DROP DATABASE IF EXISTS \`$TEST_DB\`;" 2>> "$LOG_FILE"

  echo "--------------------------------------------------" >> "$LOG_FILE"
done

NOW=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$NOW] Teste de restauração finalizado." >> "$LOG_FILE"
echo "==================================================" >> "$LOG_FILE"
