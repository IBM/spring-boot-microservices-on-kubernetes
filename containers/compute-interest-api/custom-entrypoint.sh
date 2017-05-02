#!/bin/bash
if [ -z "$OFFICESPACE_MYSQL_DB_USER" ] || [ -z "$OFFICESPACE_MYSQL_DB_PASSWORD" ] || [ -z "$OFFICESPACE_MYSQL_DB_HOST" ] || [ -z "$OFFICESPACE_MYSQL_DB_PORT" ]
then
    echo "Environment variables not found. Using Local MySQL instead if it has been setup."
else
    mysql -u $OFFICESPACE_MYSQL_DB_USER --password=$OFFICESPACE_MYSQL_DB_PASSWORD --host $OFFICESPACE_MYSQL_DB_HOST --port $OFFICESPACE_MYSQL_DB_PORT < initialize_db.sql
fi

exec "$@"
