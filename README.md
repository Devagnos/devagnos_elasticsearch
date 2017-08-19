# Devagnos Elasticsearch

## Escaping

Slash in query cause "Failed to parse query" error.

	Elasticsearch::API::Utils.__escape(q)

## Model

Gestion automatique de la méthode `as_indexed_json`.

	search_index([:label, :blocks => [:title, :content, :legend]])

Gestion par défaut du mapping : les attributs doivent être ajoutés à la méthode `as_indexed_json`.

	search_index([:label, :blocks => [:title, :content, :legend]]) do
	  indexes :published_start_at, :type => :date
	  indexes :published_end_at, :type => :date
	end
	
	search_index([:content]) do
	  indexes :user do
	    indexes :firstname
	  end
	  indexes :product do
	    indexes :label
	  end
	end
	
	# surcharge de as_indexed_json_attributes n'est plus nécessaire
	def as_indexed_json_attributes_with_more
	  json = as_indexed_json_attributes_without_more
	  json[:only] += [:published_start_at, :published_end_at]
	  json
	end
	alias_method_chain :as_indexed_json_attributes, :more

## Seeds

	# create_index! et import
	ActiveRecord::Base.init_indexes(Rails.env.development?)
	
	Page.seed(:name) do |p|
	  p.name = 'home'
	  p.label = 'Accueil'
	end

## Controller

L'utilisation de `DevagnosElasticsearch::Search.search` est équivalente à celle de `Elasticsearch::Model.search`.

	if params[:q].present?
	  @search_results = DevagnosElasticsearch::Search.search(params[:q], [Page, DevagnosBlog::Article]).page(params[:page]).per_page(5).records
	end

L'utilisation de `DevagnosElasticsearch::Search.search_dsl` permet d'utiliser `Elasticsearch::DSL`.

	if params[:q].present?
	  q = Elasticsearch::API::Utils.__escape(params[:q])
 	  search_results = DevagnosElasticsearch::Search.search_dsl([Page, LgdPage, DevagnosBlog::Article]) do
	    search do
	      query do
	        bool do
	          must do
	            query_string do
	              default_field '_all'
	              query q
	            end
	          end
	          # must do
	          #   simple_query_string do
	          #     query q
	          #   end
	          # end
	
	          must do
	            filtered do
	              filter do
	                _or do
	                  missing field: 'published_start_at'
	                  range :published_start_at do
	                    lte 'now/d'
	                  end
	                end
	                # _or do
	                #   missing field: 'published'
	                #   term published: true
	                # end
	                # _or do
	                #   missing field: 'type'
	                #   terms type: %w(content faq home resource)
	                # end
	              end
	            end
	          end
	
	          must do
	            filtered do
	              filter do
	                _or do
	                  missing field: 'published_end_at'
	                  range :published_end_at do
	                    gte 'now/d'
	                  end
	                end
	              end
	            end
	          end
	        end
	      end
	    end
	  end
	
	  @search_results = search_results.page(params[:page]).per_page(5).records
	  # result_ids = search_results.collect(&:id).collect(&:to_i)
	end

## View

	.container
	  = form_tag new_front_search_path, :method => :get do
	    = text_field_tag 'q', params[:q]
	    = button_tag 'Rechercher'
	
	  - if @search_results
	    = pluralize(@search_results.count, 'résultat')
	
	    ul
	      - @search_results.each do |result|
	        li
	          - path_part = result.class.name.demodulize.downcase
	          = link_to result.label, send("front_#{path_part}_path", :id => result.slug)
	
	    = will_paginate @search_results