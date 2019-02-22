module FullTextSearch
  class << self
    def resolver
      @resolver ||= Resolver.new
    end

    def attach
      resolver
    end
  end
end
