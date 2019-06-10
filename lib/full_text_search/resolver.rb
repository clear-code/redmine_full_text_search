module FullTextSearch
  class Resolver
    include Enumerable

    def initialize
      @redmine_to_mapper = {}
      @name_to_mapper = {}
      @mapper_to_redmine = {}
    end

    def register(redmine_class, mapper_class)
      @redmine_to_mapper[redmine_class] = mapper_class
      @name_to_mapper[normalize_name(redmine_class.name)] = mapper_class
      @mapper_to_redmine[mapper_class] = redmine_class
    end

    def resolve(key)
      case key
      when Target
        name = Type.find(key.source_type_id).name
        mapper = @name_to_mapper[normalize_name(name)]
        mapper.fts_mapper(key)
      when Class
        if key <= Mapper
          @mapper_to_redmine[key]
        else
          @redmine_to_mapper[key]
        end
      when ActiveRecord::Base
        mapper = @redmine_to_mapper[key]
        mapper.redmine_mapper(key)
      when String
        @name_to_mapper[normalize_name(key)]
      else
        message = "must be FullTextSearch::Target, Redmine model class, "
        message << "Redmine model instance, String or "
        message << "FullTextSearch::Mapper: #{key.inspect}"
        raise ArgumentError, message
      end
    end

    def each(&block)
      return to_enum(__method__) unless block_given?
      targets_need_text_extraction = []
      @redmine_to_mapper.each do |redmine_class, mapper_class|
        if mapper_class.need_text_extraction?
          targets_need_text_extraction << [redmine_class, mapper_class]
        else
          yield(redmine_class, mapper_class)
        end
      end
      targets_need_text_extraction.each(&block)
    end

    private
    def normalize_name(name)
      name.downcase
    end
  end
end
