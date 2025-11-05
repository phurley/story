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

    def chat(messages: [], options: {}, count: 0)
      resp = @client.chat.completions.create(
        messages: messages,
        **options
      )

      choice = resp.choices.first
      content = choice.message.content

      if choice.finish_reason == :length && count < 2
        continue_message = messages + [content.to_assistant, "Continue".to_user]
        content + chat(messages: continue_message, count: count + 1)
      else
        content
      end
    end
  end
end
