#!/bin/bash

set -exu

full_text_search_plugin_dir="$(dirname $(dirname $0))"

if [ ! -e plugins/full_text_search ]; then
  (cd plugins && \
     ln -fs \
        "../${full_text_search_plugin_dir}" \
        full_text_search)
fi

redmine_version=$(basename $PWD | cut -d- -f2)
case $(basename $PWD | cut -d- -f3) in
  mroonga)
    rdbms=mysql
    ;;
  pgroonga)
    rdbms=postgresql
    ;;
esac

if [ ! -e config/database.yml ]; then
  (cd config && \
     ln -fs \
        ../plugins/full_text_search/config/database.yml.example.${redmine_version}.${rdbms} \
        database.yml)
fi

if [ ! -e config/initializers/schema_format.rb ]; then
  (cd config/initializers && \
     ln -fs \
        ../../plugins/full_text_search/config/initializers/schema_format.rb \
        ./)
fi
