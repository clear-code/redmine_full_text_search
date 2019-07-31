#!/bin/bash

set -exu

options=(--rm -p3306:3306)
if [ $# -ge 1 ]; then
  db_base_dir=$1
  rm -rf ${db_base_dir}
  mkdir -p ${db_base_dir}/mysql
  mkdir -p ${db_base_dir}/log
  chmod +t ${db_base_dir}/log
  chmod go+wx ${db_base_dir}/log
  options+=("-v${db_base_dir}/mysql:/var/lib/mysql")
  options+=("-v${db_base_dir}/log:/var/log")
fi

db_conf_dir=/tmp/redmine-full-text-search/my.cnf.d
mkdir -p ${db_conf_dir}
cat <<MY_CNF > ${db_conf_dir}/local.cnf
[mysqld]
max_allowed_packet = 256M
MY_CNF
options+=("-v${db_conf_dir}:/etc/my.cnf.d")

docker run "${options[@]}" groonga/mroonga:latest
