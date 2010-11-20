class RegulatoryPlansController < ApplicationController
  def show
    cache_for 1.day
    @regulatory_plan = RegulatoryPlan.find_by_regulation_id_number!(params[:regulation_id_number], :order => "issue DESC")

    if @regulatory_plan.slug != params[:slug]
      redirect_to regulatory_plan_path(@regulatory_plan), :status => :moved_permanently
    else
      respond_to do |wants|
        wants.html do
          @entry_count = EntrySearch.new(:conditions => {:regulation_id_number => @regulatory_plan.regulation_id_number}).count
        end
      
        wants.rss do
          @feed_name = "Federal Register: Recent articles about RIN #{@regulatory_plan.regulation_id_number}"
          @feed_description = "Significant Federal Register articles about RIN #{@regulatory_plan.regulation_id_number}."
          @entries = @regulatory_plan.entries.most_recent(20).preload(:topics, :agencies)
          render :template => 'entries/index.rss.builder'
        end
      end
    end
  end
  
  def timeline
    cache_for 1.day
    @regulatory_plan = RegulatoryPlan.find_by_regulation_id_number(params[:regulation_id_number], :order => "issue DESC")
    render :layout => false
  end
  
  def tiny_url
    regulatory_plan = RegulatoryPlan.find_by_regulation_id_number!(params[:regulation_id_number], :order => "issue DESC")
    redirect_to regulatory_plan_path(regulatory_plan), :status=>:moved_permanently
  end
end