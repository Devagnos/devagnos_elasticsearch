module DevagnosElasticsearch
  extend ActiveSupport::Autoload

  autoload :Models
  autoload :Search
  autoload :Seeds
end

require 'globalize'
require 'will_paginate'
require 'will_paginate/collection'
require 'elasticsearch/model'
require 'elasticsearch/model/globalize'
require 'elasticsearch/rails'

require 'devagnos_elasticsearch/railtie'
