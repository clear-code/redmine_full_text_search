#!/bin/bash

set -exu

options=(--rm -p3306:3306)
if [ $# -ge 1 ]; then
  db_dir=$1
  rm -rf ${db_dir}
  mkdir -p ${db_dir}
  options+=("-v${db_dir}:/var/lib/mysql")
fi

db_conf_dir=/tmp/redmine-full-text-search/my.cnf.d
mkdir -p ${db_conf_dir}
cat <<MY_CNF > ${db_conf_dir}/local.cnf
[mysqld]
max_allowed_packet = 256M
MY_CNF
options+=("-v${db_conf_dir}:/etc/my.cnf.d")

docker run "${options[@]}" groonga/mroonga:latest
