# This is just for running test.
# This isn't used normal use case.
# Redmine doesn't use plugins/*/config/initializers/*.rb
active_record = ActiveRecord.respond_to?(:schema_format=) ? ActiveRecord : ActiveRecord::Base
active_record.schema_format = :sql
