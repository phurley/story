# frozen_string_literal: true

require 'openai'

module OpenAPI
  # client stuff
  class Client
    def initialize(model: 'qwen3-32b-awq', access_token: ENV['API_KEY'], uri_base: ENV['API_URL'])
      @model = model
      @client = OpenAI::Client.new(api_key: access_token, base_url: uri_base) do |f|
        f.request = :json
        f.response :logger, Logger.new($stdout), bodies: true
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def chat(messages: [], options: {})
      resp = @client.chat.completions.create(
        messages: messages,
        **options
      )

      resp.choices.first.message.content
    end
  end
end
