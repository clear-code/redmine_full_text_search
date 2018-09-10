#!/bin/bash

set -eu

if [ $# != 2 ]; then
  echo "Usage: $0 REDMINE_VERSION RDB"
  echo " e.g.: $0 3.4.6 postgresql"
fi

redmine_version=$1
rdb=$2

export DEBIAN_FRONTEND=noninteractive

sudo apt update
sudo apt install -V -y software-properties-common
sudo add-apt-repository -y universe
sudo add-apt-repository -y ppa:groonga/ppa
sudo apt update

redmine_base_name=redmine-${redmine_version}
redmine_tar_gz=${redmine_base_name}.tar.gz
wget https://www.redmine.org/releases/${redmine_tar_gz}
tar xf ${redmine_tar_gz}
cd ${redmine_base_name}

sudo apt install -V -y \
     libmagickwand-dev \
     pkg-config \
     ruby \
     ruby-dev
sudo gem install bundler

if [ "$rdb" = "postgresql" ]; then
  sudo apt install -y -V \
       libpq-dev \
       postgresql-10-pgroonga \
       groonga-tokenizer-mecab

  sudo -u postgres -H psql \
       -c "CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD 'password' NOINHERIT VALID UNTIL 'infinity'"
  sudo -u postgres -H createdb \
       --template=template0 \
       --locale=C.UTF-8 \
       --encoding=UTF-8 \
       --owner=redmine redmine
  sudo -u postgres -H psql redmine \
       -c "CREATE EXTENSION pgroonga"

  cat <<CONFIG > config/database.yml
production:
  adapter: postgresql
  database: redmine
  host: localhost
  username: redmine
  password: password
  encoding: utf8
CONFIG

  bundle install --without development test
fi

export RAILS_ENV=production

bin/rake generate_secret_token
bin/rake db:migrate
echo | bin/rake redmine:load_default_data

ln -fs /vagrant plugins/full_text_search
bundle install
bin/rake redmine:plugins:migrate
