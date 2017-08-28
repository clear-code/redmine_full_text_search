# Redmine FullTextSearch

## 0.6.2 - 2017-08-28

Fix a bug that non-admin user cannot search issues.

## 0.6.1 - 2017-08-28

Fix migration errors. See #36

## 0.6.0 - 2017-08-23

Add the feature to display similar issues on a issue page.
This version is compatible with 0.5.0.

This version supports Redmine 3.4.x.

## 0.5.0 - 2017-08-04

Totally rewrite to use Groonga features such as drilldown and so on.
This version is not compatible with 0.4.x or earlier.

This version supports Redmine 3.4.x.

You can upgrade this plugin by following sequence:

1. Stop your Redmine
1. Back up your database
1. Install new version of this plugin under plugins directory
1. Run `bundle install`
1. Run `bin/rake redmine:plugins:migrate RAILS_ENV=production`
1. Restart your Redmine

