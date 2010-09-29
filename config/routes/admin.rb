ActionController::Routing::Routes.draw do |map|
  map.namespace :admin do |admin|
    admin.home '', :controller => "special", :action => "home", :conditions => {:method => :get}
    admin.resources :agencies
    admin.resources :agency_names, :collection => {:unprocessed => :get}
    
    admin.resources :events
    
    admin.resources :topics
    admin.resources :topic_names, :collection => {:unprocessed => :get}
    
    admin.resources :photo_candidates, :only => :show
    admin.resources :sections
    admin.resources :agency_highlights
    
    admin.resources :issues, :member => {:preview => :get} do |issue|
      issue.resource :approval, :controller => "issues/approvals"
      issue.resources :entries, :controller => "issues/entries"
      issue.resources :eventful_entries, :controller => "issues/eventful_entries" do |entry|
        entry.resources :events, :controller => "issues/eventful_entries/events"
      end
      issue.resources :sections, :controller => "issues/sections", :member => {:preview => :get} do |section|
        section.resources :highlights, :controller => "issues/sections/highlights"
      end
    end
    
    admin.resources :password_resets
    admin.resources :users do |user|
      user.resource :password, :controller => "users/passwords"
    end
    
    admin.resource :user_session
    admin.login  'login',  :controller => "user_sessions", :action => "new", :conditions => {:method => :get}
    admin.logout 'logout', :controller => "user_sessions", :action => "destroy", :conditions => {:method => :get}
  end
end