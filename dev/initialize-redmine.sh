#!/bin/bash

set -exu

rails_major_version=$(grep 'gem "rails"' Gemfile | grep -o '[0-9]*' | head -n 1)

if [ "${rails_major_version}" = "4" ]; then
  task_runner="bin/rake"
else
  task_runner="bin/rails"
fi

${task_runner} db:drop || true
${task_runner} generate_secret_token
${task_runner} db:create
${task_runner} db:migrate
${task_runner} redmine:load_default_data REDMINE_LANG=en
${task_runner} redmine:plugins:migrate
${task_runner} db:structure:dump
bin/rails runner '
u = User.find(1)
u.password = u.password_confirmation = "adminadmin"
u.must_change_passwd = false
u.save!
'

