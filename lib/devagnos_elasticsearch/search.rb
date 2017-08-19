require 'elasticsearch/dsl'

module DevagnosElasticsearch
  module Search

    class SearchDslObject
      include Elasticsearch::DSL
    end

    module_function

    def search(query_or_payload, models = [], options = {})
      Elasticsearch::Model.search(query_or_payload, Array(models), options)
    end

    def search_dsl(models = [], options = {}, &block)
      search_dsl = SearchDslObject.new
      definition = search_dsl.instance_exec(&block)
      search(definition, models, options)
    end

    def simple_query(models = [], q)
      q, models = models, [] if !models.is_a?(Class) && !models.is_a?(Array)

      search_dsl(models) do
        search do
          query do
            bool do
              # must do
              #   query_string do
              #     default_field '_all'
              #     query q
              #   end
              # end
              must do
                simple_query_string do
                  query q
                end
              end
            end
          end
        end
      end
    end

  end
end