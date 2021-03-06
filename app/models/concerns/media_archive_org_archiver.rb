module MediaArchiveOrgArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_org', [/^.*$/], :only)
  end

  def archive_to_archive_org
    key_id = self.key ? self.key.id : nil
    self.class.send_to_archive_org_in_background(self.url, key_id)
  end

  module ClassMethods
    def send_to_archive_org_in_background(url, key_id)
      self.delay_for(15.seconds).send_to_archive_org(url, key_id)
    end

    def send_to_archive_org(url, key_id, attempts = 1, response = nil, _supported = nil)
      Media.give_up('archive_org', url, key_id, attempts, response) and return

      handle_archiving_exceptions('archive_org', 24.hours, { url: url, key_id: key_id, attempts: attempts }) do
        encoded_uri = URI.encode(URI.decode(url))
        uri = URI.parse("https://web.archive.org/save/#{encoded_uri}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[archive_org] Sent URL to archive', url: url, code: response.code, response: response.message

        location = response['content-location'] || response['location']
        if location
          address = 'https://web.archive.org'
          location = address + location unless location.starts_with?(address)
          data = { location: location }
          Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
        else
          retry_archiving_after_failure('ARCHIVER_FAILURE', 'archive_org', 3.minutes, { url: url, key_id: key_id, attempts: attempts, code: response.code, message: response.message })
        end
      end
    end
  end
end
