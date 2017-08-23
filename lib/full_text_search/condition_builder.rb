module FullTextSearch
  module ConditionBuilder
    def build_condition(operator, *conditions)
      operator = " #{operator} "
      "(#{conditions.compact.join(operator)})"
    end
  end
end
