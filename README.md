# Full text search plugin

This plugin provides the following features:

* Fast and rich full text search to Redmine
* Display similar issues on an issue page

## Requirements

* [Mroonga](http://mroonga.org/) or
  [PGroonga](https://pgroonga.github.io/): RDBMS plugins for full text search.

If you're using MySQL or MariaDB, you need Mroonga 9.03 or later.

If you're using PostgreSQL, you need PGroonga 2.2.0 or later.

Mroonga and PGroonga uses Groonga as full text search engine. You need
Groonga 9.0.3 or later.

### Optional requirements

* ChupaText server: Text extractor server.

## How to use

### Install PGroonga or Mroonga

See [PGroonga document](https://pgroonga.github.io/install/)

See [Mroonga document](http://mroonga.org/docs/install.html)

### Install ChupaText server (optional)

You can choose one of them to install ChupaText:

1. Use [chupa-text-docker](https://github.com/ranguba/chupa-text-docker)
2. Use [chupa-text-vagrant](https://github.com/ranguba/chupa-text-vagrant)
3. Use [chupa-text-http-server](https://github.com/ranguba/chupa-text-http-server)

chupa-text-docker is recommended. See [chupa-text-docker
document](https://github.com/ranguba/chupa-text-docker/blob/master/README.md)
to install chupa-text-docker.

See [chupa-text-vagrant
document](https://github.com/ranguba/chupa-text-vagrant/blob/master/README.md)
to install chupa-text-vagrant.

chupa-text-http-server is a normal [Ruby on
Rails](https://rubyonrails.org/) application like Redmine itself. You
can deploy chupa-text-http-server as a normal Ruby on Rails
application.

### Install this plugin

```console
$ cd redmine
$ git clone https://github.com/clear-code/redmine_full_text_search.git plugins/full_text_search
$ bundle install
$ RAILS_ENV=production bin/rails redmine:plugins:migrate
```

Restart Redmine.

**NOTE** for PGroonga:

If you use normal user for Redmine. You must run the following query
as a super user before run `RAILS_ENV=production bin/rails
redmine:plugins:migrate`:

```sql
CREATE EXTENSION IF NOT EXISTS pgroonga;
```

### Configure this plugin

Open https://YOUR_REDMINE_SERVER/settings/plugin/full_text_search and
configure items in the page. If you install ChupaText server, you must
configure "ChupaText server URL". If you install your ChupaText server
by chupa-text-docker or chupa-text-vagrant on the same host, it's
`http://127.0.0.1:20080/extraction.json`.

### Synchronize data

You need to create index for existing data. You need to run
`full_text_search:synchronize` task until no more synchronize target
data.

```console
$ cd redmine
$ RAILS_ENV=production bin/rails full_text_search:synchronize
$ RAILS_ENV=production bin/rails full_text_search:synchronize
$ RAILS_ENV=production bin/rails full_text_search:synchronize
...
```

### Synchronize query expansion list

This plugin supports query expansion. You can use this feature to
implement synonym search.

You can administrate query expansion list by Web UI in administration
page or data file.

You can use the following format for data file:

  * CSV
  * JSON

If you use CSV, use the following format:

```csv
SOURCE1,DESTINATION1
SOURCE2,DESTINATION2
...
```

Example:

```csv
MySQL,MySQL
MySQL,MariaDB
MariaDB,MySQL
MariaDB,MariaDB
```

If you use JSON, use one of the following formats:

```json
[
["SOURCE1", "DESTINATION1"],
["SOURCE2", "DESTINATION2"],
...
]
```

```json
[
{"source": "SOURCE1", "destination": "DESTINATION1"},
{"source": "SOURCE2", "destination": "DESTINATION2"},
...
]
```

Examples:

```json
[
["MySQL",   "MySQL"],
["MySQL",   "MariaDB"],
["MariaDB", "MySQL"],
["MariaDB", "MariaDB"]
]
```

```json
[
{"source": "MySQL",   "destination": "MySQL"},
{"source": "MySQL",   "destination": "MariaDB"},
{"source": "MariaDB", "destination": "MySQL"},
{"source": "MariaDB", "destination": "MariaDB"}
]
```

You can synchronize query expansion list with the data file by the
following command:

```console
$ cd redmine
$ RAILS_ENV=production bin/rails full_text_search:query_expansion:synchronize INPUT=query-expansion.csv
```

You can confirm the current query expansion list in administration
page.

## How to recover broken database

### Mroonga

Mroonga isn't crash safe. If MySQL is crashed while updating data in
Mroonga, Mroonga data may be broken.

Here is the instruction to recover from broken Mroonga data.

If you're using [Redmine plugin Delayed
Job](https://gitlab.com/clear-code/redmine-plugin-delayed-job), you
need to stop workers and delete jobs for this plugin:

```console
$ sudo -H systemctl stop redmine-delayed-job@0.service
$ cd redmine
$ RAILS_ENV=production bin/rails runner 'Delayed::Job.where(queue: "full_text_search").delete_all'
```

Stop MySQL:

```console
$ sudo -H systemctl stop mysqld
```

Remove Mroonga related files:

```console
$ cd redmine
$ database_name=$(RAILS_ENV=production bin/rails runner 'puts ActiveRecord::Base.configurations[Rails.env]["database"]')
$ sudo -H sh -c "rm -rf /var/lib/mysql/${database_name}.mrn*"
```

Start MySQL:

```console
$ sudo -H systemctl start mysqld
```

Check that Mroonga has been properly installed based on [the Mroonga
manual](https://mroonga.org/docs/tutorial/installation_check.html). If
Mroonga isn't installed, install Mroonga like the following:

```console
$ mysql -u root -p < /usr/share/mroonga/install.sql
```

Destruct tables explictly for this plugin:

```console
$ mysql -u root -p ${database_name}
> DROP TABLE IF EXISTS fts_query_expansions;
> DROP TABLE IF EXISTS fts_targets;
> DROP TABLE IF EXISTS fts_tags;
> DROP TABLE IF EXISTS fts_tag_types;
> DROP TABLE IF EXISTS fts_types;
```

Recreate schema for this plugin:

```console
$ cd redmine
$ RAILS_ENV=production bin/rails redmine:plugins:migrate NAME=full_text_search VERSION=0
$ RAILS_ENV=production bin/rails redmine:plugins:migrate NAME=full_text_search
```

If you're using [Redmine plugin Delayed
Job](https://gitlab.com/clear-code/redmine-plugin-delayed-job), you
need to start workers:

```console
$ sudo -H systemctl start redmine-delayed-job@0.service
```

Synchronize:

```console
$ cd redmine
$ RAILS_ENV=production bin/rails full_text_search:synchronize UPSERT=later
```

## How to develop

### Preparation

Here are some useful tools to prepare:

  * `dev/run-mysql.sh` and `dev/run-postgresql.sh`: Run new RDBMS
    instance by Docker.
  * `dev/initialize-redmine.sh`: Initialize Redmine.
  * `dev/run-test.sh`: Run tests for the full text search plugin.

Clone source codes. This is required only once.

```console
$ git clone https://github.com/redmine/redmine.git
$ cd redmine
$ git checkout 4.1-stable # or something
$ git clone git@github.com:${YOUR_FORK}/redmine_full_text_search.git plugins/full_text_search
```

You can add more plugins to `plugins/`.

Choose suitable database configuration:

```console
$ ln -fs ../plugins/full_text_search/config/database.yml.example.${REDMINE_VERSION}.${RDBMS} config/database.yml
```

Here is an example to use Redmine 4.1 and MySQL:

```console
$ ln -fs ../plugins/full_text_search/config/database.yml.example.4.1.mysql config/database.yml
```

Run RDBMS.

For MySQL:

```console
$ plugins/full_text_search/dev/run-mysql.sh /tmp/mysql
```

For PostgreSQL:

```console
$ plugins/full_text_search/dev/run-postgresql.sh /tmp/postgresql
```

Initialize Redmine:

```console
$ plugins/full_text_search/dev/initialize-redmine.sh
```

Run tests:

```console
$ plugins/full_text_search/dev/run-test.sh
```

### How to add a new search target

You need to create mapper classes for each search target. See
`lib/full_text_search/*_mapper.rb` for details.

You need to add `require_dependency "full_text_search/XXX_mapper` to
`init.rb` to load these new mapper classes.

You can confirm your changes by usual Redmine development ways.

For example, here is a command line to run Redmine:

```console
$ bin/rails server
```

You need to add tests to the following files:

  * `test/unit/full_text_search/XXX_test.rb`
  * `test/functional/full_text_search/search_controller_test.rb`

Here is a command line to run tests:

```console
$ plugins/full_text_search/dev/run-test.sh
```

You can specify test options by `TESTOPTS`:

```console
$ plugins/full_text_search/dev/run-test.sh TESTOPTS="-n/test_XXX/"
```

You can see all test options by `TESTOPTS=--help`:

```console
$ plugins/full_text_search/dev/run-test.sh TESTOPTS=--help
```

## Authors

  * Kenji Okimoto

  * Sutou Kouhei `<kou@clear-code.com>`

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
