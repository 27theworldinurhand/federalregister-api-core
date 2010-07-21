class PagesController < ApplicationController
  def show
    cache_for 1.day
    template = "pages/#{params[:path].gsub(/-/,'_')}.html.erb"
    if template_exists?(template)
      render :template => template
    else
      raise ActiveRecord::RecordNotFound
    end
  end
end