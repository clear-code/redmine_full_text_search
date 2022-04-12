#!/bin/bash

set -exu

rails_version_major=$(grep "^gem 'rails'" Gemfile | grep -o '[0-9]*' | head -n1)
if [ ${rails_version_major} -ge 6 ]; then
  env \
    PSQLRC=/tmp/nonexistent \
    RAILS_ENV=test \
      ${RUBY:-ruby} bin/rails test "plugins/*/test/**/*_test.rb" "$@"
else
  env \
    PSQLRC=/tmp/nonexistent \
    RAILS_ENV=test \
      ${RUBY:-ruby} bin/rails redmine:plugins:test "$@"
fi
