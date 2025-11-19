#!/bin/bash

DB_USER="user"
DB_PASS="Pass"
DB_NAME="foodpi-demo"
BACKUP_DIR="/home/htdocs/resources"

if [ -f "$BACKUP_DIR/$DB_NAME-cronjob-copy.sql" ]; then
    echo "Deleting old -copy backup: $BACKUP_DIR/$DB_NAME-cronjob-copy.sql"
    rm -f "$BACKUP_DIR/$DB_NAME-cronjob-copy.sql"
fi

if [ -f "$BACKUP_DIR/$DB_NAME-cronjob.sql" ]; then
    echo "Renaming existing backup to -copy: $BACKUP_DIR/$DB_NAME-cronjob.sql"
    mv "$BACKUP_DIR/$DB_NAME-cronjob.sql" "$BACKUP_DIR/$DB_NAME-cronjob-copy.sql"
fi

mysqldump -u $DB_USER -p$DB_PASS --routines --triggers --add-drop-table --disable-keys --add-drop-database --databases $DB_NAME --set-gtid-purged=OFF > $BACKUP_DIR/$DB_NAME-cronjob.sql

if [ $? -eq 0 ]; then
    echo "New backup created successfully: $BACKUP_DIR/$DB_NAME-cronjob.sql"
else
    echo "Error creating the new backup. Please check the script or database credentials."
fi

mysql -u$DB_USER --password="$DB_PASS" $DB_NAME < $BACKUP_DIR/$DB_NAME-cronjob.sql
