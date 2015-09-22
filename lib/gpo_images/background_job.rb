module GpoImages
  class BackgroundJob
    include GpoImages::ImageIdentifierNormalizer
    @queue = :gpo_image_import

    attr_reader :eps_filename, :zipped_filename, :ftp_transfer_date,
                :compressed_image_bundles_path, :uncompressed_eps_images_path,
                :temp_image_files_path, :bucketed_zip_filename, :mark_public

    def initialize(eps_filename, bucketed_zip_filename, ftp_transfer_date)
      @eps_filename = eps_filename
      @bucketed_zip_filename = bucketed_zip_filename
      @zipped_filename = File.basename(@bucketed_zip_filename) #BC TODO: Change this to base_filename
      @ftp_transfer_date = ftp_transfer_date.is_a?(Date) ? ftp_transfer_date : Date.parse(ftp_transfer_date)
      @compressed_image_bundles_path = GpoImages::FileLocationManager.compressed_image_bundles_path
      @uncompressed_eps_images_path = GpoImages::FileLocationManager.uncompressed_eps_images_path
    end

    def self.perform(eps_filename, zipped_filename, ftp_transfer_date)
      new(eps_filename, zipped_filename, ftp_transfer_date).perform
    end

    def perform
      gpo_graphic = find_or_create_gpo_graphic
      if gpo_graphic.save
        gpo_graphic.move_to_public_bucket if mark_public
        remove_from_redis_key
        remove_local_image
        if redis_file_queue_empty?
          mark_zipfile_as_converted
          remove_zip_file
        end
      else
        Honeybadger.notify(
          :error_class   => "GpoGraphic failed to save",
          :error_message => gpo_graphic.errors.full_messages.to_sentence,
          :parameters    => {:identifier => identifier}
        )
      end
    end

    private

    def find_or_create_gpo_graphic
      gpo_graphic = GpoGraphic.find_by_identifier(identifier)
      if gpo_graphic
        @mark_public = true
      else
        gpo_graphic = GpoGraphic.new(:identifier => identifier)
      end
      gpo_graphic.graphic = image
      gpo_graphic
    end

    def image
      @image ||= File.open(File.join(uncompressed_eps_images_path, eps_filename))
    end

    def identifier
      normalize_image_identifier(File.basename(eps_filename, File.extname(eps_filename)))
    end

    def redis
      Redis.new
    end

    def remove_from_redis_key
      redis.srem(redis_key, eps_filename)
    end

    def mark_zipfile_as_converted
      GpoImages::ImagePackage.new(ftp_transfer_date, bucketed_zip_filename).mark_as_completed!
    end

    def redis_file_queue_empty?
      redis.scard(redis_key) == 0
    end

    def redis_key
      "images_left_to_convert:#{zipped_filename}"
    end

    def remove_local_image
      FileUtils.rm(File.join(uncompressed_eps_images_path, eps_filename))
    end

    def remove_zip_file
      FileUtils.rm(File.join(compressed_image_bundles_path, zipped_filename), :force => true)
    end

  end
end
