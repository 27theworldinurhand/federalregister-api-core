module SearchHelper
  PLURAL_FILTERS = [:topic_ids, :agency_ids]
  
  def search_adding_filter(condition,value)
    conditions = params.dup[:conditions] || {}
    
    if PLURAL_FILTERS.include?(condition)
      conditions[condition] ||= []
      conditions[condition] << value
    else
      conditions[condition] = value
    end
    params.except(:quiet).recursive_merge(:page => nil, :action => :show, :conditions => conditions)
  end
  
  def search_removing_filter(condition, value)
    conditions = params.dup[:conditions] || {}
    
    if PLURAL_FILTERS.include?(condition)
      conditions[condition] ||= []
      conditions[condition] = conditions[condition] - [value.to_s]
    else
      conditions[condition] = nil
    end
    params.except(:quiet).recursive_merge(:page => nil, :action => :show, :conditions => conditions)
  end
end