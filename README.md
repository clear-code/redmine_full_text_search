# Full text search plugin

This plugin provides following features:

* Full text search to Redmine.
* Display similar issues on a issue page

## Supported databases

* PostgreSQL with Pgroonga 2.0.0 or later
* MySQL(MariaDB) with Mroonga
  * We strongly recommend Mroonga 7.05 or later
  * If you use Mroonga 7.04 or earlier, you cannot see similar issues
  * We will drop old Mroonga support in future release

## How to use

### Install PGroonga or Mroonga

See [PGroonga document](https://pgroonga.github.io/install/)

See [Mroonga document](http://mroonga.org/docs/install.html)

### Install this plugin

```text
$ cd redmine/plugins
$ git clone https://github.com/okkez/redmine_full_text_search.git full_text_search
```

### Set up this plugin

```text
$ cd redmine
$ ./bin/rake redmine:plugins:migrate RAILS_ENV=production
```

And restart Redmine.

**NOTE** for PGroonga:

If you use normal user for Redmine. You must run following query as
super user before run `./bin/rake redmine:plugins:migrate RAILS_ENV=production`:

1. `CREATE EXTENSION IF NOT EXISTS pgroonga;`
1. `GRANT USAGE ON SCHEMA pgroonga TO <user>;`

See https://pgroonga.github.io/reference/grant-usage-on-schema-pgroonga.html

# Contributing

1. Fork it ( http://github.com/okkez/redmine_full_text_search/fork )
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create new Pull Request
