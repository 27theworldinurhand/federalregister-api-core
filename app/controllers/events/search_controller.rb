class Events::SearchController < SearchController
  include Icalendar
  def show
    cache_for 1.day
    respond_to do |wants|
      wants.html
      wants.ics do
        cal = Calendar.new
        
        @search.results.each do |event|
          cal.add_event(event.to_ics)
        end
        
        render :text => cal.to_ical
      end
    end
  end
  
  private
  
  def load_search
    @search ||= EventSearch.new(params)
  end
end