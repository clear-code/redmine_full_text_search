#!/bin/bash

set -exu

env \
  PSQLRC=/tmp/nonexistent \
  RAILS_ENV=test \
    ${RUBY:-ruby} bin/rails test "plugins/*/test/**/*_test.rb" "$@"
