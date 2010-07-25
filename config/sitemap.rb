# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "http://fr2.criticaljuncture.org"

SitemapGenerator::Sitemap.add_links do |sitemap|
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: sitemap.add path, options
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly', 
  #           :lastmod => Time.now, :host => default_host
  
  # SECTIONS
  Section.find_each do |section|
    sitemap.add section_path(section)
    sitemap.add about_section_path(section)
  end
  
  # ENTRIES
  Entry.find_each do |entry|
    sitemap.add entry_path(entry)
  end
  
  Entry.connection.select_values("SELECT DISTINCT(publication_date) FROM entries").each do |date|
    sitemap.add entries_by_date_path(Date.parse(date))
  end
  
  # TOPICS
  ('a' .. 'z').each do |letter|
    sitemap.add topics_by_letter_path(letter), :priority => 0.25
  end
  
  Topic.find_each do |topic|
    sitemap.add topic_path(topic)
  end
  
  # AGENCIES
  sitemap.add agencies_path
  Agency.find_each do |agency|
    sitemap.add agency_path(agency)
  end
  
  # REGULATIONS
  RegulatoryPlan.find_each do |regulatory_plan|
    sitemap.add regulatory_plan_path(regulatory_plan)
  end
  
  # PLACES
  Place.find_each do |place|
    sitemap.add place_path(place), :priority => 0.25
  end
end
