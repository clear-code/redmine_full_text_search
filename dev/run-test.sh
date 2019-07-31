#!/bin/bash

set -exu

env \
  PSQLRC=/tmp/nonexistent \
  RAILS_ENV=test \
    bin/rails redmine:plugins:test "$@"
