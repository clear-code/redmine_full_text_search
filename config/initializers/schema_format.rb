# This is just for running test.
# This isn't used normal use case.
# Redmine doesn't use plugins/*/config/initializers/*.rb
if ActiveRecord.respond_to?(:schema_format=)
  # For Rails >= 7
  ActiveRecord.schema_format = :sql
else
  ActiveRecord::Base.schema_format = :sql
end
