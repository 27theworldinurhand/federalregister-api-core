class Entries::SearchController < SearchController
  def show
    cache_for 1.day
    respond_to do |wants|
      wants.html
      wants.rss do
        @feed_name = "Federal Register: Search Results"
        @feed_description = "Federal Register: Search Results"
        @entries = @search.results
        render :template => 'entries/index.rss.builder'
      end
    end
  end
  
  private
  
  def load_search
    @search ||= EntrySearch.new(params)
  end
end