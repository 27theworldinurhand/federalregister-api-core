class ApiController < ApplicationController
  private
  def render_json_or_jsonp(data, options = {})
    callback = params[:callback].to_s
    if callback =~ /^\w+$/
      render({:text => "#{callback}(" + data.to_json + ")"}.merge(options))
    else
      render({:json => data.to_json}.merge(options))
    end
  end
  
  rescue_from Exception, :with => :server_error if RAILS_ENV != 'development'
  def server_error(exception)
    notify_hoptoad(exception)
    render :json => {:status => 500, :message => "Internal Server Error"}, :status => 500
  end
  
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found if RAILS_ENV != 'development'
  def record_not_found
    render :json => {:status => 404, :message => "Record Not Found"}, :status => 404
  end
  
  rescue_from ActionController::MethodNotAllowed, :with => :method_not_allowed if RAILS_ENV != 'development'
  def method_not_allowed
    render :json => {:status => 405, :message => "Method Not Allowed"}, :status => 405
  end
end
