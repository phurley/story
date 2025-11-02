# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'json'

module Runpod
  # Client class
  class Client
    API_BASE = 'https://api.runpod.ai/v2'

    attr_reader :endpoint_id

    def initialize(api_key:, endpoint_id:)
      @endpoint_id = endpoint_id
      @conn = Faraday.new(url: API_BASE) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.response :raise_error
        f.headers['Authorization'] = "Bearer #{api_key}"
        f.headers['Content-Type'] = 'application/json'
        f.adapter Faraday.default_adapter
      end
    end

    # --- Public API ---------------------------------------------------------
    def chat(messages: {}, options: {})
    end

    def stream(job_id:, interval: 1.0, timeout: 120)
      path = "/#{endpoint_id}/stream"
      params = { job_id: job_id }

      start_time = Time.now
      loop do
        response = @conn.get(path, params)
        body = response.body
        status = body["status"]
        chunks = body["stream"] || []

        chunks.each do |chunk|
          yield chunk
        end

        break if status == "COMPLETED" || status == "FAILED"
        raise Runpod::Error, "Timeout reached" if Time.now - start_time > timeout

        sleep interval
      end
    end

    # Synchronous call
    # @param input [Hash] model-specific parameters
    # @param wait_ms [Integer, nil] optional wait timeout (ms)
    # @return [Hash] JSON-decoded result
    def run_sync(input:, wait_ms: nil)
      path = "/#{endpoint_id}/runsync"
      params = wait_ms ? { wait: wait_ms } : {}
      response = @conn.post(path, { input: input }, params)
      response.body
    rescue Faraday::Error => e
      raise Runpod::Error, "RunSync failed: #{e.message}"
    end

    # Asynchronous call
    # @return [Hash] job metadata (contains 'id')
    def run_async(input:)
      response = @conn.post("/#{endpoint_id}/run", { input: input })
      response.body
    rescue Faraday::Error => e
      raise Runpod::Error, "RunAsync failed: #{e.message}"
    end

    # Poll job status
    def status(job_id:)
      response = @conn.get("/#{endpoint_id}/status", { job_id: job_id })
      response.body
    rescue Faraday::Error => e
      raise Runpod::Error, "Status failed: #{e.message}"
    end
  end

  class Error < StandardError; end
end

# --- Example usage ---------------------------------------------------------
if $PROGRAM_NAME == __FILE__
  api_key     = ENV.fetch('RUNPOD_API_KEY')
  endpoint_id = ENV.fetch('RUNPOD_ENDPOINT_ID')

  client = Runpod::Client.new(api_key: api_key, endpoint_id: endpoint_id)

  input = {
    prompt: 'A futuristic robot building a sandcastle on Mars',
    width: 512,
    height: 512,
    guidance: 7.5
  }

  result = client.run_sync(input: input, wait_ms: 120_000)
  puts JSON.pretty_generate(result)
end
