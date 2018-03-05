#!/usr/bin/env bash

if [ -d /var/lib/mysql ]; then
    echo "/var/lib/mysql exists"
else
    echo "/var/lib/mysql does not exist"
fi

exec "$@"
