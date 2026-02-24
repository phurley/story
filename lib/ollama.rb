# frozen_string_literal: true

require 'ollama-ai'

class AITimeout < RuntimeError; end

# singleton wrapper
module Ollama
  # client
  class Client
    attr_accessor :timeout, :num_ctx, :top_p, :top_k, :repeat_penalty, :temperature, :stop

    def initialize(model: 'hf.co/DavidAU/Llama-3.2-8X3B-MOE-Dark-Champion-Instruct-uncensored-abliterated-18.4B-GGUF:Q6_K',
                   address: ENV['OLLAMA_HOST'] || ENV['STORY_HOST'] || 'http://localhost:11434',
                   credentials: { bearer_token: ENV['OPEN_BUTTON_TOKEN'] },
                   # options: { server_sent_events: true, connection: { request: { timeout: 30 } } }, 
                   timeout: 18000,
                   options: { server_sent_events: true, connection: { request: { timeout: timeout } } })
      @client = Ollama.new(
        credentials: { address: address }.merge(credentials),
        options: options
      )
      @model = model
      @timeout = timeout
      @num_ctx = 32 * 1024
      @pid = nil
    end

    def self.chat(messages: {}, options: {}, &block)
      @ai = AI.new if @ai.nil?
      options[:server_sent_events] = true unless options.key?(:server_sent_events)

      @ai.chat(messages: messages, options: options, &block)
    end

    def chat(messages: {}, options: {}, &blk)
      buffer = []
      response = @client.chat({
        model: @model,
        messages: messages,
        options: options
      }) do |msg|
        content = msg.dig("message", "content")
        buffer << content
        blk.call content if blk
        break if stop && stop.any? { |st| content.include?(st) }
      end

      if buffer.empty?
        if response
          puts "Exiting with response"
          response.map { _1.dig("message","content") }.join
        else
          ""
        end
      else
        puts "Exiting with buffer"
        buffer.join
      end
    rescue Ollama::Errors::RequestError
      Model.logger.warn "\nRescue on #{$!}\n"
      puts "Rescue on #{$!}"
      retry
    end
  end
end
