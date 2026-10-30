# Compiled inside the application so management uses its own JoobQ APIs.
require "joobq"
require "json"

begin
  request = JSON.parse(STDIN.gets_to_end)
  action = ARGV.first
  store = JoobQ.store
  queues = JoobQ.queues
  selected = request["queues"]?.try(&.as_a.map(&.as_s)) || [request["queue"]?.try(&.as_s) || "default"]
  selected = queues.keys if request["all_queues"]?.try(&.as_bool)
  unknown = selected.reject { |name| queues.has_key?(name) }
  raise ArgumentError.new("Unknown queues: #{unknown.join(", ")}; configure queue_configs or the queue DSL") unless unknown.empty?
  dry_run = request["dry_run"]?.try(&.as_bool) || false
  result = case action
           when "worker"
             raise "No queues configured" if selected.empty?
             queues.reject! { |name, _| !selected.includes?(name) }
             if workers = request["workers"]?.try(&.as_i?)
               queues.each_value { |queue| queue.apply_concurrency(workers) }
             end
             JoobQ.config.rest_api_enabled = request["api"]?.try(&.as_bool) || false
             STDERR.puts "Starting queues: #{queues.keys.join(", ")} (#{queues.values.sum(&.total_workers)} workers)"
             JoobQ.forge(shutdown_timeout: (request["shutdown_timeout"]?.try(&.as_i) || 25).seconds)
             "null"
           when "status"
             rows = selected.map do |name|
               {name: name, pending: store.queue_size(name), processing: store.processing_queue_size(name),
                completed: store.redis.hget("joobq:stats:completed", name).try(&.to_i64) || 0_i64,
                dlq: JoobQ::DeadLetterQueue.new(store.redis).count(name), paused: store.paused?(name)}
             end
             {queues: rows, workers: JoobQ::WorkerRegistry.all(store.redis)}.to_json
           when "pause", "resume"
             selected.each { |name| store.set_paused(name, action == "pause") } unless dry_run
             {queues: selected, paused: action == "pause", dry_run: dry_run}.to_json
           when "clear"
             if request["failed"].as_bool
               dlq = JoobQ::DeadLetterQueue.new(store.redis)
               count = selected.sum { |name| dry_run ? dlq.count(name) : dlq.purge_all(name).to_i64 }
             else
               count = selected.sum { |name| store.queue_size(name) }
               selected.each { |name| store.clear_queue(name) } unless dry_run
             end
             {queues: selected, jobs: count, dry_run: dry_run, processing_untouched: true}.to_json
           when "dlq", "retry"
             dlq = JoobQ::DeadLetterQueue.new(store.redis)
             queue = selected.first
             limit = request["limit"].as_i
             if request["all"]?.try(&.as_bool)
               count = dlq.count(queue)
               raise "More than 1000 DLQ entries; use --limit for bounded batches" if count > 1000
               limit = count.to_i
             end
             entries = dlq.page(offset: request["offset"]?.try(&.as_i) || 0, limit: limit, queue: queue)
             if action == "dlq" || dry_run
               # Do not print job arguments, exception payloads or secrets by default.
               {queue: queue, dry_run: dry_run, entries: entries.map { |entry| {jid: entry.jid, queue: entry.queue, failed_at: entry.failed_at, redrivable: entry.redrivable?} }}.to_json
             else
               dlq.redrive(entries.map(&.jid)).to_json
             end
           else
             raise "Unknown operator action"
           end
  STDOUT.puts "AZU_JOBS:#{result}" unless action == "worker"
rescue ex
  STDERR.puts "JoobQ operation failed (#{ex.class}); verify queue configuration, credentials and server availability"
  exit 1
end
