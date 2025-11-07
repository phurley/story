# frozen_string_literal: true

require 'faraday'
require 'json'

module KoboldCPP
  class Client
    def initialize(_model)
      @host = ENV['API_URL']
    end

    def chat(messages: [], options: {}, count: 0, &block)
      conn = Faraday.new(url: @host) do |f|
        f.adapter :net_http
      end

      payload = {
        messages: messages,
        stream: true,
        **options
      }

      result = []
      conn.post('/v1/chat/completions', JSON.dump(payload), { 'Content-Type' => 'application/json' }) do |req|
        req.options.on_data = proc do |chunk, _size|
          chunk.each_line do |line|
            next unless line.start_with?('data:')

            data = line.sub('data:', '').strip
            next if data == '[DONE]' || data.empty?

            begin
              json = JSON.parse(data)
              delta = json.dig('choices', 0, 'delta', 'content')
              result << delta
              yield delta if block_given?
            rescue JSON::ParserError
              warn "Bad JSON chunk: #{data}"
            end
          end
        end
      end

      result.join
    end
  end
end
