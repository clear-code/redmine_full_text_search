# Full text search plugin

This plugin provides following features:

* Full text search to Redmine.
* Display similar issues on a issue page

## Supported databases

* PostgreSQL with PGroonga 2.0.0 or later
* MySQL(MariaDB) with Mroonga 7.05 or later

## How to use

### Install PGroonga or Mroonga

See [PGroonga document](https://pgroonga.github.io/install/)

See [Mroonga document](http://mroonga.org/docs/install.html)

### Install this plugin

```text
$ cd redmine/plugins
$ git clone https://github.com/clear-code/redmine_full_text_search.git full_text_search
```

### Set up this plugin

```text
$ cd redmine
$ RAILS_ENV=production bin/rake redmine:plugins:migrate
$ RAILS_ENV=production bin/rake full_text_search:synchronize
```

And restart Redmine.

**NOTE** for PGroonga:

If you use normal user for Redmine. You must run following query as
super user before run `RAILS_ENV=production bin/rake
redmine:plugins:migrate`:

1. `CREATE EXTENSION IF NOT EXISTS pgroonga;`

## Authors

  * Kenji Okimoto

  * Kouhei Sutou `<kou@clear-code.com>`

  * Shimadzu Corporation

## License

The MIT License. See [LICENSE](LICENSE) for details.

### Exceptions

  * `asserts/stylesheets/fontawesome*/**/*`
    * Author: [@fontawesome](https://fontawesome.com/)
    * Fonts: SIL OFL 1.1 License
    * Codes: MIT License
    * See `asserts/stylesheets/fontawesome*/LICENSE.txt` for details

## Contributing

1. Fork it ( http://github.com/clear-code/redmine_full_text_search/fork )
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create new Pull Request
