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

  def full_chat(messages:, options:, count:)
    resp = @client.chat.completions.create(messages: messages, **options)
    handle_response(resp, messages, options, count)
  end

  def stream_chat(messages:, options:, count:, &block)
    response_chunks = []

    response = @client.chat.completions.create(messages: messages, **options, stream: true) do |chunk, _bytes|
      if chunk['choices']
        delta = chunk['choices'].first.dig('delta', 'content')
        block.call(delta) if delta && block
        response_chunks << delta if delta
      end
    end

    pp response

    response_chunks.join
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
