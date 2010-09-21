class Content::EntryImporter::ModsFile
  class DownloadError < StandardError; end
  
  extend ActiveSupport::Memoizable
  
  def initialize(date)
    @date = date.is_a?(String) ? Date.parse(date) : date
  end
  
  def document_numbers
    document.xpath('//xmlns:frDocNumber').map{|n| n.content()}
  end
  
  def url
    "http://www.gpo.gov:80/fdsys/pkg/FR-#{@date.to_s(:db)}/mods.xml"
  end

  def file_path
    "#{Rails.root}/data/mods/#{@date.to_s(:db)}.xml"
  end

  def document
    Curl::Easy.download(url, file_path) unless File.exists?(file_path)
    doc = Nokogiri::XML(open(file_path))
    
    publication_date = doc.root.xpath('./xmlns:originInfo/xmlns:dateIssued').first.try(:content) if doc.root
    
    if !publication_date
      File.delete(file_path)
      raise Content::EntryImporter::ModsFile::DownloadError
    end

    doc.root
  end
  memoize :document
  
  def volume
    document.css('volume').first.try(:content)
  end
  memoize :volume
  
  def find_entry_node_by_document_number(document_number)
    document.xpath("./xmlns:relatedItem[@ID='id-#{document_number}']").first
  end
end