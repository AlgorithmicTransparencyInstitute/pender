module MediaPermaCcArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('perma_cc', [/^.*$/], :only, CONFIG.dig('perma_cc_key').present?)
  end

  def archive_to_perma_cc
    key_id = self.key ? self.key.id : nil
    self.class.send_to_perma_cc_in_background(self.url, key_id)
  end

  module ClassMethods
    def send_to_perma_cc_in_background(url, key_id)
      self.delay_for(15.seconds).send_to_perma_cc(url, key_id)
    end

    def send_to_perma_cc(url, key_id, attempts = 1, response = nil, _supported = nil)
      return if notify_already_archived_on_perma_cc(url, key_id)
      Media.give_up('perma_cc', url, key_id, attempts, response) and return

      handle_archiving_exceptions('perma_cc', 24.hours, { url: url, key_id: key_id, attempts: attempts }) do
        encoded_uri = URI.encode(URI.decode(url))
        uri = URI.parse("https://api.perma.cc/v1/archives/?api_key=#{CONFIG['perma_cc_key']}")
        headers = { 'Content-Type': 'application/json' }
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = { url: encoded_uri }.to_json
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[perma_cc] Sent URL to archive', url: url, code: response.code, response: response.message

        if !response.nil? && response.code == '201' && !response.body.blank?
          body = JSON.parse(response.body)
          data = { location: 'http://perma.cc/' + body['guid'] }
          Media.notify_webhook_and_update_cache('perma_cc', url, data, key_id)
        else
          retry_archiving_after_failure('ARCHIVER_FAILURE', 'perma_cc', 3.minutes, { url: url, key_id: key_id, attempts: attempts, code: response.code, message: response.message })
        end
      end
    end

    def notify_already_archived_on_perma_cc(url, key_id)
      id = Media.get_id(url)
      data = Pender::Store.read(id, :json)
      return if data.nil? || data.dig(:archives, :perma_cc).nil?
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook('perma_cc', url, data, settings)
    end

  end
end
