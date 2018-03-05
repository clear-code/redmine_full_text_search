FROM debian:stretch

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales && \
    localedef -i ja_JP -c -f UTF-8 -A /usr/share/locale/locale.alias ja_JP.UTF-8
ENV LANG ja_JP.UTF-8

RUN apt update && apt upgrade -y && apt install -y apt-transport-https && \
    echo "deb https://packages.groonga.org/debian/ stretch main" > /etc/apt/sources.list.d/pgroonga.list && \
    apt update --allow-insecure-repositories && apt install -y --allow-unauthenticated groonga-keyring &&  \
    apt update && apt install -y postgresql-all postgresql-9.6-pgroonga groonga-tokenizer-mecab && \
    sed -i -e '1,$ s/C.UTF-8/ja_JP.UTF-8/g' /etc/postgresql/9.6/main/postgresql.conf

ENV PATH $PATH:/usr/lib/postgresql/9.6/bin
COPY dockerfiles/pgroonga/docker-entrypoint.sh /usr/local/bin/
USER postgres

ENV LANG ja_JP.UTF-8
RUN pg_dropcluster 9.6 main && pg_createcluster 9.6 main

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 5432
CMD ["pg_ctlcluster", "--foreground", "9.6", "main", "start"]
