module DevagnosElasticsearch
  module Models

    class IndexingMappingProxy
      def initialize(mapping, attributes, &block)
        @mapping = mapping

        @json_stack = [
          {:only => [], :include => {}}
        ]

        process(attributes)
        instance_exec(&block) if block_given?
      end

      def method_missing(m, *args, &block)
        @mapping.send(m, *args, &block)
      end

      def indexes(*args, &block)
        attribute = args.first

        if block_given?
          # klass.assign_touch_to_association(k)
          current[:include][attribute] = {:only => [], :include => {}}
          @json_stack << current[:include][attribute]
          @mapping.indexes(*args) do
            block.call
          end
          @json_stack.pop
        else
          current[:only] << attribute
          @mapping.indexes(*args)
        end
      end

      def as_indexed_json_attributes
        @json_stack.first
      end

      def process(attributes)
        Array(attributes).each do |attribute|
          if attribute.is_a? Hash
            attribute.each do |k, v|
              this = self
              indexes(k) { this.process(v) }
            end
          else
            indexes attribute
          end
        end
      end

      def current
        @json_stack.last
      end

    end

    extend ActiveSupport::Concern

    SETTINGS = {
      analysis: {
        analyzer: {
          default: {
            tokenizer: 'standard',
            filter: ['snowball', 'lowercase', 'asciifolding', 'stopwords', 'elision', 'worddelimiter'],
            char_filter: ['html_strip']
          }
        },
        filter: {
          snowball: {
            type: 'snowball',
            language: 'French'
          },
          elision: {
            type: 'elision',
            articles: %w{l m t qu n s j d}
          },
          stopwords: {
            type: 'stop',
            stopwords: '_french_',
            ignore_case: true
          },
          worddelimiter: {
            type: 'word_delimiter'
          }
        }
      }
    }

    module ClassMethods

      # def touch_parent_association(association)
      #   after_update { Array(self.send(association)).each(&:touch) }
      # end
      #
      # def assign_touch_to_association(association)
      #   reflection = self.reflections[association.to_s]
      #   raise "impossible de trouver la relation #{self.name}##{association}" unless reflection
      #   inverse_name = ActiveSupport::Inflector.underscore(reflection.options[:as] || name.demodulize).to_sym
      #   raise "impossible de trouver la relation #{reflection.klass}##{inverse_name}" unless reflection.klass.reflections[inverse_name.to_s]
      #   reflection.klass.touch_parent_association(inverse_name)
      # end

      def search_index(*args, &block)
        send :include, Elasticsearch::Model

        options = args.extract_options!
        attributes = args.flatten

        # __elasticsearch__.update_document ne gère pas les relations
        # la solution proposée par elasticsearch-model est de faire un touch sur le model parent
        # assign_touch_to_association permet d'injecter l'appel au touch dans les classes enfants
        # quand on sauvegarde et qu'on modifie plusieurs enfants, le touch est appelé plusieurs fois
        # donc plusieurs indexation successives sont appelées (__elasticsearch__.index_document)

        # send :include, Elasticsearch::Model::Callbacks
        # after_touch(lambda do
        #   puts "touch #{self.class.name}##{self.id}"
        #   __elasticsearch__.index_document
        # end)

        option_if_unless = lambda do |_options|
          if _options[:if]
            if _options[:if].respond_to?(:call)
              _options[:if].call
            else
              send(_options[:if])
            end
          elsif _options[:unless]
            !instance_exec(:if => _options[:unless], &option_if_unless)
          else
            true
          end
        end

        after_commit(lambda do
          if instance_exec(options, &option_if_unless)
            __elasticsearch__.index_document
          end
        end, on: :create)

        after_commit(lambda do
          if instance_exec(options, &option_if_unless)
            __elasticsearch__.index_document
          end
        end, on: :update)

        after_commit(lambda do
          begin
            __elasticsearch__.delete_document
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end, on: :destroy)

        index_name_method = 'index_name'
        if respond_to?(:translations_table_name)
          send :include, Elasticsearch::Model::Globalize::OneIndexPerLanguage
          index_name_method += '_base'
        end

        # options[:index_name] ||= self.model_name.collection.gsub(/\//, '-')
        options[:index_name] ||= 'main'
        options[:index_name] = if Rails.application.nil?
          "#{Rails.env}:#{options[:index_name]}"
        elsif Gem::Version.new(Rails.version) < Gem::Version.new('4')
          "#{Rails.env}:#{Rails.application.config.settings.name.parameterize}:#{options[:index_name]}"
        else
          "#{Rails.env}:#{app_settings!('application_id')}:#{options[:index_name]}"
        end
        send index_name_method, options[:index_name]

        options[:document_type] ||= self.model_name.element
        document_type options[:document_type]

        proxy = nil
        settings SETTINGS do
          mapping do
            proxy = IndexingMappingProxy.new(self, attributes, &block)
          end
        end

        define_method :as_indexed_json_attributes do
          proxy.as_indexed_json_attributes
        end

        class << self
          def inherited(subclass)
            super(subclass)
            if subclass.respond_to?(:translations_table_name)
              Elasticsearch::Model::Globalize::OneIndexPerLanguage.included(subclass)
              subclass.index_name_base(index_name_base)
            else
              subclass.index_name(index_name)
            end
            subclass.document_type(document_type)
          end
        end
      end

      def simple_query(q)
        DevagnosElasticsearch::Search.simple_query(self, q)
      end

    end

    def as_indexed_json(options = {})
      as_json(as_indexed_json_attributes)
    end

  end
end