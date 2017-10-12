#!/bin/bash
if [ -z "$MYSQL_DB_USER" ] || [ -z "$MYSQL_DB_PASSWORD" ] || [ -z "$MYSQL_DB_HOST" ] || [ -z "$MYSQL_DB_PORT" ]
then
    echo "Environment variables not found. Using default credentials (user michaelbolton, password password, host account-database, port 3306) instead if it has been setup."
else
    mysql -u "$MYSQL_DB_USER" --password="$MYSQL_DB_PASSWORD" --host "$MYSQL_DB_HOST" --port "$MYSQL_DB_PORT" < initialize_db.sql
fi

exec "$@"
