# Full text search plugin

This plugin provides full text search to Redmine.

## Supported databases

* PostgreSQL with Pgroonga
* MySQL(MariaDB) with Mroonga

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
