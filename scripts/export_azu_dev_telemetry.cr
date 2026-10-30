# Run against an installed Azu checkout via CRYSTAL_PATH; outputs a real v1
# snapshot for the CLI contract test. No HTTP listener or database is needed.
require "azu/dev"

config = Azu::Configuration.new
config.env = Azu::Environment::Development
config.performance_enabled = true
Azu.with_config(config) do
  metrics = Azu::Dev.metrics || raise "Dev.metrics missing with monitoring enabled"
  monitor = config.performance_monitor || raise "Configured performance monitor missing"
  raise "Dev.metrics must share the application's monitor" unless metrics.same?(monitor.metrics)
  metrics.record_request("Products::Index", "GET", "/products?password=private-request-value", 2.5, 0_i64, 0_i64, 200)
  metrics.record_request("Sessions::Create", "POST", "/login", 4.5, 0_i64, 0_i64, 303)
end
store = Azu::QueryStore.instance
store.clear
5.times do
  store.record_query("SELECT * FROM products WHERE id = 1", ["private-bound-value"], 2.5, 1_i64,
    nil, "product_repository.cr:41", nil, "request-1", "Products::Index", "GET", "/products", 1_u64)
end
Azu::ErrorStore.instance.clear
context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/broken?password=private-error-value"), HTTP::Server::Response.new(IO::Memory.new))
rescuer = Azu::Handler::Rescuer.new
rescuer.next = ->(_context : HTTP::Server::Context) { raise "shared telemetry integration failure" }
Azu.with_config(config) { rescuer.call(context) }
# Exercise the real exporter's default metrics lookup, not a separate metrics
# instance injected into snapshot. Both paths must read the configured monitor.
Azu.with_config(config) do
  snapshot = Azu::Dev::Telemetry.snapshot(config)
  raise "Shared Dev.metrics requests were not exported" unless snapshot[:requests].try(&.[:total]) == 2
  File.write(ENV.fetch("AZU_SNAPSHOT_OUTPUT"), snapshot.to_json)
end
disabled = Azu::Configuration.new
disabled.performance_enabled = false
Azu.with_config(disabled) { raise "Dev.metrics should be nil when disabled" unless Azu::Dev.metrics.nil? }
