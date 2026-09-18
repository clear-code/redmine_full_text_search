ActiveRecord::SchemaDumper.ignore_tables |= [
  /\Afts_targets_(?:past|default|\d{4})\z/,
]
