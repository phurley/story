# frozen_string_literal: true

require 'logger'
require_relative './ai'

# Model DSL
class Model
  attr_accessor :logger

  DEFAULT_SYSTEM = "You are a story teller. \
      Carefully examine all of the information provided, it is your background information. \
      When finally provided a prompt, create a story incorporating the prompt and exploring it. \
      Stop and wait for additional prompts once fully explored."

  def initialize(&block)
    set_defaults
    setup_logging

    instance_eval(&block)

    @ai = AI.new(model: @name)
    Model.current_model = self
  end

  def set_defaults
    @system = DEFAULT_SYSTEM
    @max_responses = 5
  end

  def setup_logging
    @logger = Logger.new('story.log')
    begin
      @logger.level = Logger.const_get(ENV['LOGLEVEL'])
    rescue NameError
      @logger.level = Logger::INFO
    end
    @logger.formatter = proc { |_, _, _, msg| msg }
  end

  def model(name)
    @name = name
  end

  def system(prompt)
    @system = prompt
  end

  def temperature(temp)
    @temperature = temp
  end

  def top_p(value)
    @top_p = value
  end

  def top_k(value)
    @top_k = value
  end

  def repeat_penalty(value)
    @repeat_penalty = value
  end

  def max_responses(count = nil)
    @max_responses = count if count
    @max_responses
  end

  def options
    {
      temperature: @temperature, top_p: @top_p, top_k: @top_k,
      repeat_penalty: @repeat_penalty, seed: @seed,
      num_predict: @num_predict, repeat_last_n: @repeat_last_n,
      min_p: @min_p, tfs_z: @tfs_z,
      typical_p: @typical_p, presence_penalty: @presence_penalty,
      frequency_penalty: @frequency_penalty, mirostat: @mirostat,
      mirostat_tau: @mirostat_tau,
      mirostat_eta: @mirostat_eta
    }.reject { |_, v| v.nil? }
  end

  def add_system(messages)
    return messages if messages.any? { |entry| entry[:role] == 'system' }

    [{ role: 'system', content: @system }] + messages
  end

  def chat(messages)
    messages = add_system(messages)

    logger.debug "\n#{messages.inspect}\n\n"
    result = @ai.chat(messages: messages, options: options) do |resp, raw|
      puts resp.inspect
      puts raw.inspect
      resp = resp['choices'].first if resp['choices']
      logger.info(resp['message']['content'])
    end
    logger.info("\n\n")

    puts result.inspect
    result = result['choices'].first if result['choices']
    result.map { |rec| rec['message']['content'] }.join
  end

  class << self
    def current_model=(model)
      @model = model
    end

    def chat(messages)
      @model.chat(messages)
    end

    def max_responses
      @model.max_responses
    end
  end
end
