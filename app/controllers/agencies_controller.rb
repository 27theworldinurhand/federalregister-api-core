class AgenciesController < ApplicationController
  def index
    cache_for 1.day
    @agencies  = Agency.all(:order => 'name ASC', :include => :children)
  end
  
  def show
    cache_for 1.day
    @agency = Agency.find_by_slug!(params[:id])
    respond_to do |wants|
      wants.html do
        @entries = EntrySearch.new(:conditions => {:agency_ids => [@agency.id]}, :order => "newest", :per_page => 50).results
        @most_cited_entries = @agency.entries.all(:conditions => "citing_entries_count > 0", :order => "citing_entries_count DESC, publication_date DESC", :limit => 50, :group => "entries.id")
        @significant_entries = @agency.entries.significant.all(:conditions => {:publication_date => (3.month.ago .. Time.current.to_date)}, :group => "entries.id")
        
        # Entry types
        @entry_type_labels = []
        @entry_type_values = []
        
        by_entry_type = Entry.all(
          :select => 'granule_class, count(*) AS count',
          :conditions => {:agency_assignments => {:assignable_id => @agency.id, :assignable_type => "Entry"}},
          :joins => :agency_assignments,
          :group => 'granule_class',
          :order => 'count DESC'
        )
        by_entry_type.each do |summary|
          @entry_type_labels << summary.entry_type
          @entry_type_values << summary.count.to_i
        end
      end
      
      wants.rss do
        @entries = @agency.entries.most_recent(20).preload(:topics, :agencies)
        @feed_name = "Federal Register: #{@agency.name}"
        @feed_description = "Recent Federal Register articles from #{@agency.name}."
        render :template => 'entries/index.rss.builder'
      end
    end
    
  end
  
  def significant_entries
    cache_for 1.day
    @agency = Agency.find_by_slug!(params[:id])
    
    respond_to do |wants|
      wants.rss do
        @entries = @agency.entries.significant.most_recent(20).preload(:topics, :agencies)
        @feed_name = "Federal Register: #{@agency.name} Significant Articles"
        @feed_description = "Recent Federal Register articles from #{@agency.name} on significant regulations."
        render :template => 'entries/index.rss.builder'
      end
    end
  end
end