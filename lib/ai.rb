# frozen_string_literal: true

require 'ollama-ai'

class AITimeout < RuntimeError; end

# singleton wrapper
class AI
  attr_accessor :timeout, :num_ctx, :top_p, :top_k, :repeat_penalty, :temperature

  def initialize(model: 'dolphin-mixtral:latest',
                 address: ENV['OLLAMA_HOST'] || 'http://localhost:11434',
                 credentials: {},
                 options: { server_sent_events: true }, timeout: 180)
    @client = Ollama.new(
      credentials: { address: address }.merge(credentials),
      options: options
    )
    @model = model
    @timeout = timeout
    @num_ctx = 32 * 1024
    @pid = nil
  end

  def self.configure(model: 'dolphin-mixtral:latest', address: ENV['OLLAMA_HOST'] || 'http://localhost:11434', credentials: {}, options: { server_sent_events: true }, timeout: 12000)
    @ai = AI.new(model: models, address: address, credentials: credentials, options: options, timeout: timeout)
  end

  def self.chat(messages: {}, options: {})
    @ai = AI.new if @ai.nil?
    options[:server_sent_events] = true unless options.key?(:server_sent_events)

    @ai.chat(messages: messages, options: options)
  end

  def chat(messages: {}, options: {}, &blk)
    @client.chat({
                   model: @model,
                   messages: messages,
                   options: options
                 }, &blk)
  end
end
