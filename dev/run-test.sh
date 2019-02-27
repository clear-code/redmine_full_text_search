#!/bin/bash

set -exu

rails_major_version=$(grep 'gem "rails"' Gemfile | grep -o '[0-9]*' | head -n 1)

if [ "${rails_major_version}" = "4" ]; then
  task_runner="bin/rake"
else
  task_runner="bin/rails"
fi

env \
  PSQLRC=/tmp/nonexistent \
  RAILS_ENV=test \
    ${task_runner} redmine:plugins:test
