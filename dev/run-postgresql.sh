#!/bin/bash

set -exu

options=(--rm -p5432:5432 -ePOSTGRES_HOST_AUTH_METHOD=trust)
if [ $# -ge 1 ]; then
  db_dir=$1
  rm -rf ${db_dir}
  mkdir -p ${db_dir}
  options+=("-v${db_dir}:/var/lib/postgresql")
fi

docker run "${options[@]}" groonga/pgroonga:latest-debian-12
