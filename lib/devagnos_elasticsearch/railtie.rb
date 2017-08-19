require 'rails'

module DevagnosElasticsearch
  class Railtie < Rails::Railtie

    initializer 'devagnos_elasticsearch.active_record' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send :include, DevagnosElasticsearch::Models
        ActiveRecord::Base.send :include, DevagnosElasticsearch::Seeds
      end
    end

    rake_tasks do
      load 'devagnos_elasticsearch/tasks/init_indexes.rake'
    end


  end
end
