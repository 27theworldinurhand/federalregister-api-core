# == Schema Information
#
# Table name: section_assignments
#
#  id         :integer(4)      not null, primary key
#  entry_id   :integer(4)
#  section_id :integer(4)
#

class SectionAssignment < ApplicationModel
  belongs_to :entry
  belongs_to :section
end
