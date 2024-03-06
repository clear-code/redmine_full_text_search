# For backward compatibility with Redmine < 6.
# ApplicationRecord is inherited from ActiveRecord Models instead of ActiveRecord::Base in Redmine >= 6.
# ref: https://www.redmine.org/issues/38975
unless defined?(ApplicationRecord)
  ApplicationRecord = ActiveRecord::Base
end
