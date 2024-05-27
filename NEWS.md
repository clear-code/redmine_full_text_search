# Redmine FullTextSearch

## 2.0.1 - 2024-05-27

### Improvements

  * Supported specifying update targets in `full_text_search:target:reload`.

## 2.0.0 - 2024-05-27

### Improvements

  * Dropped support for Redmine 4.

  * Wiki Extensions plugin tag data to be synchronized with `full_text_search:synchronize`.

### Fixed

  * Suppress errors when plugins use `Attachment`.

    * Skipped because of unknown `container_type` causing an error.

  * Fixed an error in Wiki Extensions plugin tag import.

## 1.0.4 - 2024-05-16

Because it has been a long time since the last release, please excuse this list of commit logs.

  * Search by tags in Wiki Extensions (#137)
  * Support Redmine v5.1 (#123)
  * Enable sort function by registered time on the search page (#119)
  * Add support for Redmine X UX plugin (#112)
  * Add missing icon classes for search options (#110)
  * Add support for destroying a custom field (#109)
  * project custom_field: fix a bug that orphan custom values may be remained
  * issue custom_field: fix a bug that orphan custom values may be remained
  * Drop support for Redmine 4.1
  * Add support for redmica_s3
  * Add support for Redmine 5.0
  * Drop support for Redmine 4.0
  * mroogna: fix Mroonga version check
  * Use ActiveModel::Type::Value
  * Use Int64 for fts_targets.tag_ids
  * Add an option whether include `search_id` and `search_n` in URL. (#88)
  * Fix a bug that project related targets aren't found for normal users

## 1.0.3 - 2019-08-23

### Improvements

  * Dropped support for Redmine 3.

  * Changed to use separated job queue.

  * Changed to use job for real time update.

  * Decreased priority for batch upsert jobs.

  * Discarded "record not found" jobs immediately.

  * Improved the number of records in tabs.
    [GitHub#69][Reported by ryouma-nagare]

  * Added support for query expansion.

### Fixed

  * Fixed a bug that search result order labels are missing.
    [GitHub#68][Reported by ryouma-nagare]

  * Fixed a bug that link URL for "change" is wrong.
    [Reported by Shimadzu Corporation]

  * Fixed a bug that pagination is broken.
    [GitHub#70][Reported by a9zawa]

  * Fixed a bug that extracted text that includes null character can't
    be inserted.
    [GitHub#71][Reported by a9zawa]

### Thanks

  * ryouma-nagare

  * Shimadzu Corporation

  * a9zawa

## 1.0.2 - 2019-07-09

### Improvements

  * Improved search UI.

  * Improved performance.

  * Made similar issue search optional.

  * Removed archived projects from search targets.

  * Changed task name to `full_text_search:truncate` from
    `full_text_search:destroy`.

  * Changed to use low priority for jobs.

### Fixed

  * `indexing`: Fixed a bug that sub path content in Subversion
    repository can't be processed.

  * Fixed wrong drilldown count.

  * Fixed a bug that it doesn't work with PGroonga.
    [GitHub#66][Reported by ryouma-nagare]

  * Fixed a bug that uninstalling is failed.
    [GitHub#67][Reported by ryouma-nagare]

### Thanks

  * ryouma-nagare

## 1.0.1 - 2019-06-13

### Improvements

  * `indexing`: Added more unexpected case check.

  * `indexing`: Reduced synchronize targets.

  * `analyze-log`: Added support for reporting summary.

  * `mroonga`: Changed to use Zstandard.

  * `mroonga`: Changed to use `NormalizerNFKC121`.

  * `indexing`: Improved support for text extraction timeout.

## 1.0.0 - 2019-06-10

The first major release!

### Improvements

  * Reconstructed search UI.

  * Added support for full text search against repository contents.

  * Required Groonga 9.0.1 or later.

  * Required PGroonga 2.2.0 or later.

## 0.8.1 - 2019-03-29

Wiki related bug fix release of 0.8.1.

### Fixes

  * Fixed a Wiki page index bug.

## 0.8.0 - 2019-03-29

Redmine 4.0 support and attachment content search support release.

### Improvements

  * Resolved plugin conflict.
    [GitHub#55][Reported by yassan][Looked into by Akiko Takano]
    [GitHub#57][Reported by yassan]

  * Added support for installing to not `plugins/full_text_search`
    directory.
    [GitHub#58][Reported by Olexandr Minzak]

  * Added support for Redmine 4.0.

  * Added support for attachment content search.

### Fixes

  * [Similar issue search]
    Fixed a bug that garbage record is created on error

  * Fixed broken links for messages in search result page.
    [GitHub#59][Patch by Tatsuya Saito]

  * Fixed a bug that custom field search shows issues in other
    projects.
    [GitHub#60][Patch by Tatsuya Saito]

  * Fixed a bug that garbage string is shown on no snippet record.

  * Fixed a migration bug for custom values.
    [GitHub#62][Reported by Okojo]

### Thanks

  * yassan

  * Akiko Takano

  * Olexandr Minzak

  * Tatsuya Saito

  * Okojo

## 0.7.3 - 2018-06-25

Bug fix release for 0.7.2

* Search attachments by default
* Display search options by default
* Fix bug that single quotes in query causes an internal server error #50

## 0.7.2 - 2018-03-20

Bug fix release for 0.7.1.

* Fix bug that handle original_type for CustomValue and WikiPage properly #48

## 0.7.1 - 2018-03-12

Fix bugs as following

* Add missing parenthesis to search result same as Redmine
* Ensure removing existing records before copying data in migration
* Display `original_updated_on` in search result if `original_type` is Issue
* Sort search result properly when sort by updated_on
* Handle normalized `original_type` properly when backend is PGroonga

## 0.7.0 - 2017-11-22

Squash migrations to use PGroonga 2.x by default and drop PGroonga 1.x support.
Also drop Mroonga 7.04 or earlier support.

How to upgrade from 0.6.3 or earlier.

1. Stop your Redmine
1. Backup your database
1. Upgrade to 0.6.3
1. Rollback all migrations: `bin/rake redmine:plugins:migrate RAILS_ENV=production NAME=full_text_search VERSION=0`
   * You can not rollback all migrations using 0.6.2 or earlier
1. Upgrade to 0.7.0 and apply all migrations `bin/rake redmine:plugins:migrate RAILS_ENV=production NAME=full_text_search`
1. Restart your Redmine

## 0.6.3 - 2017-09-11

Fix migration related errors. We can reset migration.
Fix callback error for Changeset.

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

