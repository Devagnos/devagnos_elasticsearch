namespace :devagnos_elasticsearch do

  desc 'devagnos_elasticsearch init_indexes'
  task :init_indexes => :environment do
    ActiveRecord::Base.init_indexes
  end

end