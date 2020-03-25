#!/bin/bash

set -exu

test_svn_repository="tmp/test/subversion_repository"
if [ ! -d "${test_svn_repository}" ]; then
  svnadmin create "${test_svn_repository}"
  zcat test/fixtures/repositories/subversion_repository.dump.gz | \
    svnadmin load "${test_svn_repository}"
fi

test_git_repository="tmp/test/git_repository"
if [ ! -d "${test_git_repository}" ]; then
  tar xf test/fixtures/repositories/git_repository.tar.gz \
    -C "$(dirname ${test_git_repository})"
fi

${RUBY:-ruby} bin/rails db:drop || true
${RUBY:-ruby} bin/rails generate_secret_token
${RUBY:-ruby} bin/rails db:create
${RUBY:-ruby} bin/rails db:migrate
${RUBY:-ruby} bin/rails redmine:load_default_data REDMINE_LANG=en
${RUBY:-ruby} bin/rails redmine:plugins:migrate
${RUBY:-ruby} bin/rails db:structure:dump
${RUBY:-ruby} bin/rails runner '
u = User.find(1)
u.password = u.password_confirmation = "adminadmin"
u.must_change_passwd = false
u.save!
'

