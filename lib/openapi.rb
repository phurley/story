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

    def old_chat(messages: [], options: {}, count: 0)
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

    def chat(messages: [], options: {}, count: 0, &block)
      options_with_model = options.merge(model: @model) if @model && !options.key?(:model)
      with_retries do
        if block_given?
          stream_chat(messages: messages, options: options_with_model, count: count, &block)
        else
          full_chat(messages: messages, options: options_with_model, count: count)
        end
      end
    end

    private

    def stream_chat(messages:, options:, count:, &block)
      response_buffer = +''

      response = @client.chat.completions.stream_raw(
        parameters: { messages: messages, **options }
      ) do |event, _chunk, _bytes|
        case event
        when /^data: (.*)$/
          json = Regexp.last_match(1)
          next if json.strip == '[DONE]'

          begin
            data = JSON.parse(json)
            delta = data.dig('choices', 0, 'delta', 'content')
            if delta
              block.call(delta)
              response_buffer << delta
            end
          rescue JSON::ParserError
            warn "⚠️ Stream parse error: #{json.inspect}"
          end
        end
      end

      pp response

      response_buffer
    end

    def handle_response(resp, messages, options, count)
      choice = resp.choices.first
      content = choice.message.content
      finish_reason = choice.finish_reason&.to_sym

      if finish_reason == :length && count < 2
        continue_message = messages + [content.to_assistant, "Continue".to_user]
        content + chat(messages: continue_message, options: options, count: count + 1)
      else
        content
      end
    end

    def with_retries(max_retries = 3)
      attempts = 0
      begin
        yield
      rescue OpenAI::Errors::AuthenticationError, OpenAI::Errors::InvalidRequestError => e
        # These are not transient — don’t retry
        logger.error("OpenAI unrecoverable error: #{e.class} - #{e.message}")
        raise
      rescue OpenAI::Error::Errors, Faraday::Error, Timeout::Error, SocketError => e
        attempts += 1
        if attempts <= max_retries
          warn "Retry #{attempts}/#{max_retries} after error: #{e.class} - #{e.message}"
          sleep(1.5 * attempts)
          retry
        else
          warn "Failed on #{attempts} attempts after error: #{e.class} - #{e.message}"
          raise
        end
      end
    end 
  end
end
