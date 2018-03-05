FROM debian:stretch

RUN apt-get update && apt-get install -y locales && \
    localedef -i ja_JP -c -f UTF-8 -A /usr/share/locale/locale.alias ja_JP.UTF-8
ENV LANG ja_JP.UTF-8

RUN apt update && apt upgrade -y && apt install -y apt-transport-https && \
    echo "deb https://packages.groonga.org/debian/ stretch main" > /etc/apt/sources.list.d/pgroonga.list && \
    apt update --allow-insecure-repositories && apt install -y --allow-unauthenticated groonga-keyring &&  \
    apt update && apt install -y mariadb-server mariadb-client mariadb-server-mroonga

COPY dockerfiles/mroonga/docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["mysqld"]
