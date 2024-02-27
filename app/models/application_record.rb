# For backward compatibility with Redmine <= v5.x.
# ApplicationRecord is inherited from ActiveRecord Models instead of ActiveRecord::Base in Redmine > 5.x
# ref: https://www.redmine.org/issues/38975
unless defined?(ApplicationRecord)
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
