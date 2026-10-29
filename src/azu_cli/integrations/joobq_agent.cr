# Loaded after the project's boot file; it must configure JoobQ without starting
# workers or a web server. All state mutations use the engine's own operator API.
require "joobq"

module AzuJoobQDashboard
  class RuntimeProvider < Provider
    @previous = {} of String => Int64
    @sampled : Time::Instant?

    def store
      {% if JoobQ.has_constant?("Runtime") %}
        ::JoobQ::Runtime.store
      {% else %}
        ::JoobQ.store
      {% end %}
    end

    def snapshot : JSON::Any
      store.redis.ping if store.responds_to?(:redis)
      now = Time.instant
      elapsed = @sampled.try { |at| (now - at).total_seconds }
      queues = ::JoobQ.config.queue_configs.keys.first(100).map do |name|
        if store.responds_to?(:get_queue_metrics)
          metrics = store.get_queue_metrics(name)
          processed = metrics.processed_count
          previous = @previous[name]?
          rate = previous && elapsed && elapsed > 0 ? Math.max(0_i64, processed - previous) / elapsed : nil
          @previous[name] = processed
          {name: name, pending: metrics.queue_size, processing: metrics.processing_size, processed: processed, rate: rate}
        else
          {name: name, pending: store.queue_size(name), processing: nil, processed: nil, rate: nil}
        end
      end
      @sampled = now
      workers = JSON::Any.new(nil)
      dlq = JSON.parse("[]")
      retries = JSON.parse("[]")
      replay_supported = false
      if store.responds_to?(:redis)
        {% if JoobQ.has_constant?("WorkerRegistry") %}
          workers = JSON.parse(::JoobQ::WorkerRegistry.all(store.redis).first(100).to_json)
        {% end %}
        {% if JoobQ.has_constant?("DeadLetterQueue") %}
          dlq = JSON.parse(::JoobQ::DeadLetterQueue.new(store.redis).page(limit: 100).to_json)
          replay_supported = true
        {% end %}
      end
      if store.responds_to?(:get_retrying_jobs_paginated)
        retries = JSON.parse(store.get_retrying_jobs_paginated(1, 100).map { |json| JSON.parse(json) }.to_json)
      end
      JSON.parse({v: 1, queues: queues, workers: workers, workflows: workflows, dlq: redact(dlq),
                  retries: redact(retries), replay_supported: replay_supported,
                  history: "Runtime workflow store; no PostgreSQL History Store configured"}.to_json)
    end

    def workflows : JSON::Any
      {% if @top_level.has_constant?("JoobQPro") %}
        {% if JoobQPro.has_constant?("Workflows") %}
          history = ::JoobQPro::Workflows::Runtime.store?
          if history
            rows = history.ids(status: ::JoobQPro::Workflows::WorkflowStatus::Running, limit: 50).compact_map do |id|
              loaded = history.load(id)
              next unless loaded
              state = loaded[0]
              definition = history.definition(state.name, state.def_hash)
              steps = if definition
                        definition.steps.first(200).map do |entry|
                          step = state.steps[entry.id]?
                          {id: entry.id, status: step.try(&.status.to_s) || "Pending", attempt: step.try(&.attempt) || 0, depends_on: entry.depends_on}
                        end
                      else
                        state.steps.first(200).map do |name, step|
                          {id: name, status: step.status.to_s, attempt: step.attempt, depends_on: [] of String}
                        end
                      end
              {id: id, name: state.name, status: state.status.to_s, steps: steps}
            end
            return JSON.parse(rows.to_json)
          end
        {% end %}
      {% end %}
      JSON.parse("[]")
    end

    def replay(id : String) : JSON::Any
      raise "invalid job id" if id.empty? || id.bytesize > 256
      {% if JoobQ.has_constant?("DeadLetterQueue") %}
        if store.responds_to?(:redis)
          return JSON.parse(::JoobQ::DeadLetterQueue.new(store.redis).redrive([id]).to_json)
        end
      {% end %}
      raise "This JoobQ version/store has no atomic DLQ replay API"
    end

    private def redact(value : JSON::Any, depth = 0) : JSON::Any
      return JSON::Any.new("[truncated]") if depth > 8
      if fields = value.as_h?
        JSON::Any.new(fields.first(100).to_h do |key, child|
          {key, key.matches?(/password|secret|token|authorization|cookie|private_key/i) ? JSON::Any.new("[FILTERED]") : redact(child, depth + 1)}
        end)
      elsif rows = value.as_a?
        JSON::Any.new(rows.first(100).map { |child| redact(child, depth + 1) })
      elsif text = value.as_s?
        JSON::Any.new(text[0, 4000])
      else
        value
      end
    end
  end
end

provider = AzuJoobQDashboard.provider || AzuJoobQDashboard::RuntimeProvider.new
while line = STDIN.gets('\n', 4097)
  break if line.bytesize > 4096
  begin
    request = JSON.parse(line)
    result = case request["action"].as_s
             when "snapshot" then provider.snapshot
             when "replay"   then provider.replay(request["id"].as_s)
             else                 raise "unknown dashboard action"
             end
    STDOUT.puts "AZU_JOOBQ:#{{ok: true, data: result}.to_json}"
  rescue ex
    # Never send connection URLs, credentials or arbitrary server errors to the HUD.
    STDOUT.puts "AZU_JOOBQ:#{{ok: false, error: "Store operation failed (#{ex.class.name}); inspect the worker configuration"}.to_json}"
  end
  STDOUT.flush
end
