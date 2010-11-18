class EntrySearch < ApplicationSearch
  class CFR < Struct.new(:title,:part)
    def citation
      "#{title} CFR #{part}"
    end
    
    def sphinx_citation
      title.to_i * 100000 + part.to_i
    end
  end
  
  TYPES = [
    ['Rule',                  'RULE'    ], 
    ['Proposed Rule',         'PRORULE' ], 
    ['Notice',                'NOTICE'  ], 
    ['Presidential Document', 'PRESDOCU'], 
    ['Sunshine Act Document', 'SUNSHINE']
  ]
  include Geokit::Geocoders
  
  attr_reader :type
  attr_accessor :type, :regulation_id_number
  
  define_filter :regulation_id_number, :label => "Unified Agenda", :phrase => true do |regulation_id_number|
    reg = RegulatoryPlan.find_by_regulation_id_number(regulation_id_number)
    ["RIN #{regulation_id_number}", reg.try(:title)].join(' - ')
  end
  
  define_filter :agency_ids,  :sphinx_type => :with
  define_filter :section_ids, :sphinx_type => :with_all do |section_id|
    Section.find_by_id(section_id).try(:title)
  end
  define_filter :topic_ids,   :sphinx_type => :with_all
  define_filter :type,        :sphinx_type => :with, :crc32_encode => true do |types|
    types.map{|type| Entry::ENTRY_TYPES[type]}.to_sentence(:two_words_connector => ' or ', :last_word_connector => ', or ')
  end
  
  define_filter :docket_id, :phrase => true, :label => "Agency Docket" do |docket|
    docket
  end
  
  define_filter :significant, :sphinx_type => :with, :label => "Signficance" do 
    "Associated Unified Agenda Deemed Significant by OIRA"
  end
  
  define_place_filter :place_ids
  define_date_filter :publication_date, :label => "Publication Date"
  define_date_filter :effective_date, :label => "Effective Date"
  
  attr_reader :cfr
  
  def cfr=(hsh)
    if hsh.present? && hsh.values.present?
      @cfr = CFR.new(hsh[:title], hsh[:part])
      
      # TODO: error handling
      if @cfr.title.present? && @cfr.part.present?
        add_filter(
          :value => @cfr.sphinx_citation,
          :name => @cfr.citation,
          :sphinx_attribute => :cfr_affected_parts,
          :label => "Affected CFR Part",
          :sphinx_type => :with
        )
      end
    end
  end
  
  def model
    Entry
  end
  
  def find_options
    {
      :select => "id, title, publication_date, document_number, document_file_path, abstract",
      :include => :agencies,
    }
  end
  
  def supported_orders
    %w(Relevant Newest Oldest)
  end
  
  def order_clause
    case @order
    when 'newest'
      "publication_date DESC, @relevance DESC"
    when 'oldest'
      "publication_date ASC, @relevance DESC"
    else
      "@relevance DESC, publication_date DESC"
    end
  end
  
  def agency_facets
    FacetCalculator.new(:search => self, :model => Agency, :facet_name => :agency_ids).all
  end
  memoize :agency_facets
  
  def section_facets
    FacetCalculator.new(:search => self, :model => Section, :facet_name => :section_ids, :name_attribute => :title).all
  end
  memoize :section_facets
  
  def topic_facets
    FacetCalculator.new(:search => self, :model => Topic, :facet_name => :topic_ids).all
  end
  memoize :topic_facets
  
  def type_facets
    raw_facets = Entry.facets(term,
      :with => with,
      :with_all => with_all,
      :conditions => sphinx_conditions,
      :match_mode => :extended,
      :facets => [:type]
    )[:type]
    
    search_value_for_this_facet = self.type
    facets = raw_facets.to_a.reverse.reject{|id, count| id == 'UNKNOWN'}.map do |id, count|
      Facet.new(
        :value      => id, 
        :name       => Entry::ENTRY_TYPES[id],
        :count      => count,
        :on         => id.to_s == search_value_for_this_facet.to_s,
        :condition  => :type
      )
    end
  end
  memoize :type_facets
  
  def date_distribution
    sphinx_search = ThinkingSphinx::Search.new(term,
      :with => with,
      :with_all => with_all,
      :conditions => sphinx_conditions,
      :match_mode => :extended
    )
    
    client = sphinx_search.send(:client)
    client.group_function = :month
    client.group_by = "publication_date"
    client.limit = 5000
    
    query = sphinx_search.send(:query)
    dist = {}
    client.query(query, '*')[:matches].each{|m| dist[m[:attributes]["@groupby"].to_s] = m[:attributes]["@count"] }
    
    (1994..Time.current.to_date.year).each do |year|
      (1..12).each do |month|
        dist[sprintf("%d%02d",year, month)] ||= 0
      end
    end
    
    dist
  end
  
  def count_in_last_n_days(n)
    model.search_count(@term,
      :with => with.merge(:publication_date => n.days.ago.to_time.midnight .. Time.current.midnight),
      :with_all => with_all,
      :conditions => sphinx_conditions,
      :match_mode => :extended
    )
  end
  
  def date_facets
    [30,90,365].map do |n|
      value = n.days.ago.to_date.to_s
      Facet.new(
        :value      => {:gte => value},
        :name       => "Past #{n} days",
        :count      => count_in_last_n_days(n),
        :condition  => :publication_date
      )
    end
  end
  memoize :date_facets
  
  def regulatory_plan
    if @regulation_id_number
      RegulatoryPlan.find_by_regulation_id_number(@regulation_id_number)
    end
  end
  memoize :regulatory_plan
  
  def matching_entry_citation
    if term.present?
      term.scan(/^\s*(\d+)\s*F\.?R\.?\s*(\d+)\s*$/) do |volume, page|
        return Citation.new(:citation_type => "FR", :part_1 => volume.to_i, :part_2 => page.to_i)
      end
    end
    
    return nil
  end
  
  def entry_with_document_number
    if term.present?
      return Entry.find_by_document_number(term)
    end
  end
  
  private
  
  def set_defaults(options)
    @within = '25'
    @order = options[:order] || 'relevant'
  end
end