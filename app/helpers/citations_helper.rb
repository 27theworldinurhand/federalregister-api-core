module CitationsHelper
  def add_citation_links(text)
    if text.present?
      text = add_usc_links(text)
      text = add_cfr_links(text)
      text = add_federal_register_links(text)
      text = add_regulatory_plan_links(text)
      text = add_public_law_links(text)
      text = add_patent_links(text)
      
      text
    else
      text
    end 
  end
  
  def add_usc_links(text)
    text.gsub(/(\d+)\s+U\.?S\.?C\.?\s+(\d+)/) do |str|
      title = $1
      part = $2
      content_tag :a, str,
          :href => "http://frwebgate.access.gpo.gov/cgi-bin/getdoc.cgi?dbname=browse_usc&docid=Cite:+#{title}USC#{part}",
          :class => "usc external",
          :target => "_blank"
    end
  end
  
  def add_cfr_links(text)
    text.gsub(/(\d+)\s+(?:CFR|C\.F\.R\.)\s+(?:[Pp]arts?|[Ss]ections?|[Ss]ec\.|&#xA7;|&#xA7;\s*&#xA7;)?\s*(\d+)(?:\.(\d+)(?:\(([a-z])\))?)?/) do |str|
      title = $1
      part = $2
      section = $3
      subpart = $4
      content_tag :a, str,
        :href => "http://frwebgate.access.gpo.gov/cgi-bin/get-cfr.cgi?YEAR=current&TITLE=#{title}&PART=#{part}&SECTION=#{section}&SUBPART=#{subpart}&TYPE=TEXT",
        :class => "cfr external",
        :target => "_blank"
    end
  end
  
  def add_federal_register_links(text)
    text.gsub(/(\d+)\s+FR\s+(\d+)/) do |str|
      issue = $1
      page = $2
      if issue.to_i >= 59
        content_tag(:a, str, :href => "/citation/#{issue}/#{page}")
      else
        str
      end
    end
  end
  
  def add_regulatory_plan_links(text)
    text.gsub(/RIN (\w{4}-\w{4})/) do |str|
      content_tag :a, str, :href => short_regulatory_plan_path(:regulation_id_number => $1)
    end
  end
  
  def add_public_law_links(text)
    text.gsub(/(?:Public Law|Pub\. Law|Pub\. L.|P\.L\.)\s+(\d+)-(\d+)/) do |str|
      congress = $1
      law = $2
      if congress.to_i >= 104
        content_tag :a, str, :href => "http://frwebgate.access.gpo.gov/cgi-bin/getdoc.cgi?dbname=#{congress}_cong_public_laws&docid=f:publ#{sprintf("%03d",law.to_i)}.#{congress}", :class => "publ external", :target => "_blank"
      else
        $1
      end
    end
  end
  
  def add_patent_links(text)
    text = text.gsub(/Patent Number ([0-9,]+)/) do |str|
      number = $1
      content_tag :a, str, :href => patent_url(number), :class => "patent external", :target => "_blank"
    end
  end
  
  def add_date_links(entry, text)
    entry.referenced_dates.each do |date|
      next if date.string.blank?
      text.gsub!(/#{Regexp.escape(date.string)}/, content_tag(:a, date.string, :href => events_path(date)) )
    end
    text
  end
  
  private
  
  def patent_url(number_possibly_with_commas)
    number = number_possibly_with_commas.gsub(/,/,'')
    "http://patft.uspto.gov/netacgi/nph-Parser?Sect2=PTO1&Sect2=HITOFF&p=1&u=/netahtml/PTO/search-bool.html&r=1&f=G&l=50&d=PALL&RefSrch=yes&Query=PN/#{number}"
  end
  
  # def patent_application_url(number_possibly_with_commas)
  #   number = number_possibly_with_commas.gsub(/,/,'')
  #   "http://appft.uspto.gov/netacgi/nph-Parser?Sect1=PTO2&Sect2=HITOFF&p=1&u=/netahtml/PTO/search-adv.html&r=2&f=G&l=50&d=PG01&S1=(%22268,404%22.APN.)&OS=APN/%22#{number}%22"
  # end
end
