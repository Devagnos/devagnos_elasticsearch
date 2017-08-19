module DevagnosElasticsearch
  module Seeds

    extend ActiveSupport::Concern

    module ClassMethods

      def init_indexes(force_create = true)
        eager_load = if Rails.application.nil?
          true
        elsif Gem::Version.new(Rails.version) < Gem::Version.new('4')
          Rails.application.config.cache_classes
        else
          Rails.application.config.eager_load
        end

        unless eager_load
          Rails.application.eager_load!
          Rails::Engine.subclasses.map(&:instance).each {|e| e.eager_load! }
        end

        created_indexes = []
        ActiveRecord::Base.descendants.each do |klass|
          if klass.respond_to?(:__elasticsearch__) && !klass.superclass.respond_to?(:__elasticsearch__)
            I18n.available_locales.each do |locale|
              Globalize.with_locale(locale) do
                index_name = klass.__elasticsearch__.index_name
                unless created_indexes.include?(index_name)
                  klass.__elasticsearch__.create_index!(:force => force_create)
                  created_indexes << klass.__elasticsearch__.index_name
                end
              end
            end
            klass.import
          end
        end
      end

    end

  end
end