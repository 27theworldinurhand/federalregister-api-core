namespace :data do
  task :daily => :environment do
    Content::ImportDriver.new.perform
  end
  
  namespace :daily do 
    task :basic => %w(
      content:section_highlights:clone
      content:entries:import
      content:entries:import:graphics
      data:extract:places
    )
    
    task :quick => %w(
      data:daily:basic
      content:issues:mark_complete
    )
    task :catch_up => %w(
      data:daily:basic
      content:entries:html:compile:all
      content:issues:mark_complete
    )
    
    task :full => %w(
      data:daily:basic
      content:entries:html:compile:all
      content:entries:import:regulations_dot_gov:tardy
      content:issues:mark_complete
      varnish:expire:everything
      sitemap:refresh
    )
  end
end