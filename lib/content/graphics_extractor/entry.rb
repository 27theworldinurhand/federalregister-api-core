module Content
  class GraphicsExtractor
    class Entry
      extend ActiveSupport::Memoizable
      
      attr_reader :entry
      def initialize(document_number, options)
        @entry = ::Entry.find_by_document_number!(document_number)
        @base_dir = options[:base_dir]
      end
      
      def pdf_file_path
        file_loc = "#{@base_dir}/#{entry.document_number}.pdf"
        Curl::Easy.download(entry.source_url(:pdf), file_loc) unless File.exists?(file_loc)
        file_loc
      end
      
      def pdf_images_by_page
        pdf = Stevedore::Pdf.new(pdf_file_path)
        
        pdf_images_by_page = Hash.new{ Array.new }
        pdf.images(@base_dir).each do |pdf_image|
          pdf_images_by_page[pdf_image.page_number] += [pdf_image]
        end
        
        pdf_images_by_page
      end
      memoize :pdf_images_by_page
      
      def associate_image(image)
        puts "Processing #{image.identifier} (##{image.num_prior_images_on_page + 1} on page #{image.page_number}) for #{entry.document_number} [#{pdf_file_path}]"
        graphic = Graphic.find_by_identifier(image.identifier)
        if graphic.nil?
          pdf_image = pdf_images_by_page[(image.page_number - image.entry_start_page)][ image.num_prior_images_on_page ]
          if pdf_image
            graphic = Graphic.new(:graphic => File.open(pdf_image.file_path), :identifier => image.identifier)
          else
            puts "\timage not extracted! #{pdf_images_by_page.inspect}"
            return
          end
        end
        
        graphic.entries << entry unless graphic.entry_ids.include?(entry.id)
        graphic.save!
      end
    end
  end
end