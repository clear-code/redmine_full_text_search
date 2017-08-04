# Redmine FullTextSearch

## 0.5.0 - 2017-08-04

Totally rewrite to use Groonga features such as drilldown and so on.
This version is not compatible with 0.4.x or earlier.

This version supports Redmine 3.4.x.

You can upgrade this plugin by following sequence:

1. Stop your Redmine
1. Back up your database
1. Install new version of this plugin under plugins directory
1. Run `bin/rails redmine:plugins:migrate RAILS_ENV=production`
1. Restart your Redmine

