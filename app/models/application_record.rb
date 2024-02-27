# For backward compatibility with old version of Redmine <= v5.1.
# ApplicationRecord is used as the default parent class for all models.
# ref: https://www.redmine.org/issues/38975
unless defined?(ApplicationRecord)
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
