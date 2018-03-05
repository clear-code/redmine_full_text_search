#! /usr/bin/env bash

if [ -d /var/lib/postgresql/9.6/main ]; then
    echo "/var/lib/postgresql/9.6/main exists"
else
    echo "/var/lib/postgresql/9.6/main does not exist"
    pg_dropcluster 9.6 main
    pg_createcluster 9.6 main
fi

pg_ctlcluster 9.6 main start

psql=( psql -v ON_ERROR_STOP=1 )

for f in /docker-entrypoint-initdb.d/*; do
    case "$f" in
        *.sh)
            echo "$0: running $f"
            . $f
            ;;
        *.sql)
            echo "$0: running $f"
            "${psql[@]}" -f "$f"
            echo
            ;;
        *.sql.gz)
            echo "$0: running $f"
            gunzip -c "$f" | "${psql[@]}"
            echo
            ;;
        *)
            echo "$0: ignoring $f"
            ;;
    esac
done

pg_ctlcluster -m fast 9.6 main stop

exec "$@"

