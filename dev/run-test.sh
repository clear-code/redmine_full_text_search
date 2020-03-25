#!/bin/bash

set -exu

env \
  PSQLRC=/tmp/nonexistent \
  RAILS_ENV=test \
    ${RUBY:-ruby} bin/rails redmine:plugins:test "$@"
