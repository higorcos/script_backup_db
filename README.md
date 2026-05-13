# Backup MariaDB com teste de restauração

Este conjunto de scripts foi criado para fazer backup automático de bancos MariaDB/MySQL e também testar se os backups realmente conseguem ser restaurados.

A ideia é simples:

- fazer backup de todos os bancos disponíveis;
- salvar cada banco em sua própria pasta;
- manter apenas os últimos 7 backups de cada banco;
- registrar tudo em um único arquivo de log;
- testar os backups restaurando em um banco temporário;
- apagar o banco temporário depois do teste.
