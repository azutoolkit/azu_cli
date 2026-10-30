require "./bounded_capture"
require "./scratch_file"

module AzuCLI
  module MCPBridge
    class DatabaseAdapter < Commands::Database
      def execute : Commands::Result
        success
      end

      def header : String
        migrator_script_header
      end
    end

    DATABASE_AGENT = <<-'CRYSTAL'
      request = JSON.parse(STDIN.gets_to_end)
      action = request["action"].as_s
      arguments = request["arguments"].as_a.map(&.as_s)
      applied = migrator.applied_migrations.map(&.version).sort
      pending = migrator.pending_migrations.map(&.version).sort
      state = {action: action, arguments: arguments, applied: applied, pending: pending,
        database_identity: Digest::SHA256.hexdigest(migrator.schema.uri)}
      if request["execute"].as_bool
        raise "Migration state changed; prepare another plan" unless JSON.parse(state.to_json) == request["expected"]
        if migrator.responds_to?(:apply_reviewed)
          rollback = action == "db:rollback" ? arguments.first.to_i64 : nil
          migrator.apply_reviewed(request["expected"]["applied"].as_a.map(&.as_i64), request["expected"]["pending"].as_a.map(&.as_i64), rollback)
        else
          raise "Installed CQL lacks apply_reviewed; upgrade CQL before enabling MCP migration execution"
        end
        puts "AZU_MCP:" + {status: "applied", applied: migrator.applied_migrations.map(&.version).sort}.to_json
      else
        puts "AZU_MCP:" + state.to_json
      end
    CRYSTAL

    JOBS_AGENT = <<-'CRYSTAL'
      request = JSON.parse(STDIN.gets_to_end)
      action = request["action"].as_s
      selected = request["arguments"].as_a.first.as_s
      store = JoobQ.store
      raise "Reviewed job operations require JoobQ::RedisStore" unless store.is_a?(JoobQ::RedisStore)
      endpoint = store.endpoint
      store_identity = Digest::SHA256.hexdigest({host: store.host, port: store.port,
        database: endpoint.try(&.database) || 0, unixsocket: endpoint.try(&.unixsocket),
        user: endpoint.try(&.user), tls: endpoint.try(&.tls?), verify: endpoint.try(&.verify?)}.to_json)
      if action == "jobs:retry"
        dlq = JoobQ::DeadLetterQueue.new(store.redis)
        entry = dlq.find(selected) || raise "Selected job is no longer in the DLQ"
        raise "Job cannot be redriven" unless entry.redrivable?
        state = {action: action, store_identity: store_identity, jid: entry.jid, queue: entry.queue, failed_at: entry.failed_at,
          digest: Digest::SHA256.hexdigest(entry.member)}
        if request["execute"].as_bool
          raise "Job changed; prepare another plan" unless JSON.parse(state.to_json) == request["expected"]
          result = if dlq.responds_to?(:redrive_reviewed)
                     dlq.redrive_reviewed(selected, request["expected"]["digest"].as_s)
                   else
                     raise "Installed JoobQ lacks redrive_reviewed; upgrade JoobQ before enabling MCP replay"
                   end
          raise "Redrive did not succeed; reconcile state before retrying" unless result.succeeded == 1
          puts "AZU_MCP:" + result.to_json
        else
          puts "AZU_MCP:" + state.to_json
        end
      elsif action == "jobs:pause" || action == "jobs:resume"
        raise "Unknown queue" unless JoobQ.queues.has_key?(selected)
        state = {action: action, store_identity: store_identity, queue: selected, paused: store.paused?(selected)}
        if request["execute"].as_bool
          raise "Queue state changed; prepare another plan" unless JSON.parse(state.to_json) == request["expected"]
          if store.responds_to?(:set_paused_reviewed)
            raise "Queue state changed during execution; prepare another plan" unless store.set_paused_reviewed(selected, request["expected"]["paused"].as_bool, action == "jobs:pause")
          else
            raise "Installed JoobQ lacks set_paused_reviewed; upgrade JoobQ before enabling MCP queue operations"
          end
          puts "AZU_MCP:" + {queue: selected, paused: store.paused?(selected)}.to_json
        else
          puts "AZU_MCP:" + state.to_json
        end
      else
        raise "Unsupported jobs action"
      end
    CRYSTAL

    def self.operation(args : Array(String), execute : Bool) : JSON::Any
      action = args.shift? || raise "Action required"
      raise "Unsupported action" unless %w(db:migrate db:rollback jobs:retry jobs:pause jobs:resume).includes?(action)
      if action == "db:migrate"
        raise "No arguments accepted" unless args.empty?
      else
        raise "One explicit selection required" unless args.size == 1 && args.first.matches?(/\A[\w:.-]{1,128}\z/)
      end
      DotEnv.load_all(Dir.current)
      expected = execute ? JSON.parse(STDIN.gets('\0', MAX_BYTES + 1) || "") : JSON::Any.new(nil)
      header = if action.starts_with?("db:")
                 DatabaseAdapter.new.header
               else
                 raise "JoobQ initializer missing" unless File.file?("src/initializers/joobq.cr")
                 "require \"./src/initializers/joobq.cr\"\n"
               end
      script = "require \"json\"\nrequire \"digest/sha256\"\n" + header + (action.starts_with?("db:") ? DATABASE_AGENT : JOBS_AGENT)
      input = {action: action, arguments: args, execute: execute, expected: expected}.to_json
      ScratchFile.with(".azu_mcp_operator_", script) do |path|
        binary = path + ".bin"
        begin
          status = Process.run("crystal", ["build", path, "-o", binary], output: STDERR, error: STDERR)
          raise "Application operation adapter failed to compile; check installed shard compatibility" unless status.success?
          output = BoundedCapture.new(MAX_BYTES)
          status = Process.run(binary, input: IO::Memory.new(input), output: output, error: STDERR)
          raise "Operation failed; inspect diagnostics and reconcile state" unless status.success? && !output.truncated?
          line = output.text.lines.find(&.starts_with?("AZU_MCP:")) || raise "Adapter returned no structured result"
          JSON.parse(line.lchop("AZU_MCP:"))
        ensure
          File.delete?(binary)
        end
      end
    end
  end
end
