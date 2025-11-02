# frozen_string_literal: true

require 'openai'

module OpenAPI
  # client stuff
  class Client
    def initialize(model: 'qwen3-32b-awq', access_token: ENV['API_KEY'], uri_base: ENV['API_URL'])
      @model = model
      @client = OpenAI::Client.new(access_token: access_token, uri_base: uri_base)
    end

    def chat(messages: [], options: {})
      @client.chat.completions.create(
        model: @model,
        messages: messages,
        **options
      )
    end
  end
end
