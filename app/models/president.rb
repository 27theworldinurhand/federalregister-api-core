class President < ActiveHash::Base
  self.data = [
    {
      :identifier => 'clinton',
      :full_name => "William J. Clinton",
      :starts_on => Date.new(1994,1,1),
      :ends_on => Date.new(2001,1,19)
    },
    {
      :identifier => 'bush',
      :full_name => "George W. Bush",
      :starts_on => Date.new(2001,1,20),
      :ends_on => Date.new(2009,1,19)
    },
    {
      :identifier => 'obama',
      :full_name => "Barack Obama",
      :starts_on => Date.new(2009,1,20),
      :ends_on => Date.new(2013,1,19)
    }
  ]

  def year_ranges
    return @year_ranges if @year_ranges

    @year_ranges = {}

    @year_ranges[starts_on.year] = starts_on .. starts_on.end_of_year
    (starts_on.year+1 .. ends_on.year-1).each do |year|
      @year_ranges[year] = Date.new(year,1,1) .. Date.new(year,12,31)
    end
    @year_ranges[ends_on.year] = ends_on.beginning_of_year .. ends_on
    @year_ranges
  end

  def ends_on
    if self[:ends_on] > Date.current
      Date.current
    else
      self[:ends_on]
    end
  end

end
