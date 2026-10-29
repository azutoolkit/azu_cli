# Render the actual screens with illustrative fixtures; no app or store is contacted.
# Run from the repository root: crystal run scripts/render_terminal_screens.cr
require "cadmium_inflector"
require "../src/azu_cli/logger"
require "../src/azu_cli/utils"
require "../src/azu_cli/dev_server/changes"
require "../src/azu_cli/dev_server/hud"
require "../src/azu_cli/joobq/screen"

alias UI = AzuCLI::UI
alias Dev = AzuCLI::DevServer
alias Jobs = AzuCLI::JoobQDashboard

OUTPUT = "docs/assets/terminal-ui/new-screens"
Dir.mkdir_p(OUTPUT)

def press(screen, char : Char)
  screen.update(UI::Key.new(UI::KeyCode::Char, char))
end

def capture(screen, name : String, width = 136, height = 40)
  styles = UI::StyleTable.new(UI::Theme.new(UI::ColorDepth::TrueColor), UI::Token::Backplate)
  frame = UI::Frame.new(width, height, styles)
  screen.view(frame)
  File.write("#{OUTPUT}/#{name}.txt", frame.to_text)
  File.open("#{OUTPUT}/#{name}.ansi", "w") { |io| UI::FullScreenRenderer.new(io).flush(frame) }
end

queues = [
  {name: "critical", pending: 12, processing: 8, processed: 18452, rate: 42.8},
  {name: "payments", pending: 38, processing: 12, processed: 92640, rate: 86.4},
  {name: "mailers", pending: 124, processing: 16, processed: 342891, rate: 214.6},
  {name: "reports", pending: 7, processing: 4, processed: 4812, rate: 3.2},
  {name: "webhooks", pending: 26, processing: 8, processed: 20834, rate: 58.9},
]
workers = (1..8).map do |i|
  {id: "worker-#{i.to_s.rjust(2, '0')}", queues: ["critical", "payments", "mailers"], status: "running", fibers_active: i + 2, concurrency: 16}
end
workflows = (1..24).map do |i|
  {id: "order-2026-#{1840 + i}", name: "OrderFulfillment", status: "Running", steps: [
    {id: "validate_order", status: "Completed", attempt: 1, depends_on: [] of String},
    {id: "reserve_inventory", status: "Completed", attempt: 1, depends_on: ["validate_order"]},
    {id: "charge_payment", status: "Completed", attempt: 2, depends_on: ["reserve_inventory"]},
    {id: "create_shipment", status: "Running", attempt: 1, depends_on: ["charge_payment"]},
    {id: "send_confirmation", status: "Pending", attempt: 0, depends_on: ["create_shipment"]},
  ]}
end
dlq = (1..38).map do |i|
  {jid: "job-#{9200 + i}", queue: "webhooks", error: "HTTP 503: upstream unavailable", failed_at: "14:32:08",
   job: {event: "order.shipped", order_id: "order-2026-1841", url: "https://partner.example/hooks/orders",
         attempt: 5, token: "[FILTERED]", retry_history: ["14:30:12 timeout", "14:30:45 HTTP 503", "14:31:20 HTTP 503", "14:32:08 exhausted"]}}
end
jobs = Jobs::Screen.new
jobs.update(Jobs::Snapshot.new(JSON.parse({v: 1, queues: queues, workers: workers, workflows: workflows, dlq: dlq,
                                           retries: [{jid: "retry-714", queue: "payments", next_at: "14:35:00"}], replay_supported: true,
                                           history: "Illustrative data · Redis workflow provider · PostgreSQL history not configured"}.to_json)))
capture(jobs, "joobq-queues")
press(jobs, '2')
capture(jobs, "joobq-workflows")
press(jobs, '3')
press(jobs, 'r')
capture(jobs, "joobq-dlq")

errors = (1..36).map do |i|
  {id: "err-#{i}", at: "14:32:#{(58 - i).to_s.rjust(2, '0')}", route: "POST /orders", class: i == 1 ? "PaymentGatewayError" : "ValidationError",
   message: i == 1 ? "Payment provider did not respond within 2 seconds" : "Order validation failed",
   problem: {type: "about:blank", title: "Bad Gateway", status: 502, detail: "Payment provider did not respond within 2 seconds", instance: "/orders", error_id: "err-#{i}"},
   params: {order_id: "ord_1841", amount: "129.00", currency: "USD", authorization: "[FILTERED]"},
   frames: ["src/services/payments/charge_service.cr:82:9 in 'call'", "src/services/orders/create_service.cr:46:11 in 'call'", "src/endpoints/orders/create_endpoint.cr:19:7 in 'call'"] +
     Array.new(30) { |n| "lib/azu/src/azu/handler/endpoint.cr:#{120 + n}:5 in 'call'" }}
end
queries = (1..42).map do |i|
  {id: 1000 + i, at: "14:33:#{(59 - i).to_s.rjust(2, '0')}", ms: i == 1 ? 18.42 : (0.4 + i * 0.17).round(2), caller: "order_repository.cr:#{40 + i}", model: "orders",
   endpoint: "Orders::IndexEndpoint", pool_wait_ms: 0.12,
   sql: i == 1 ? "SELECT orders.id, orders.total, customers.email FROM orders JOIN customers ON customers.id = orders.customer_id WHERE orders.status = ? ORDER BY orders.created_at DESC LIMIT ?" : "SELECT * FROM order_items WHERE order_id = ?"}
end
buckets = [{label: "<1", count: 620, bar: 12}, {label: "1–5", count: 344, bar: 7}, {label: "5–10", count: 139, bar: 3},
           {label: "10–50", count: 84, bar: 2}, {label: "50–100", count: 12, bar: 1}, {label: "≥100", count: 1, bar: 1}]
telemetry = JSON.parse({v: 1, errors: errors, sql: {total: 1200, avg_ms: 3.62, slow: 13, pool: {in_flight: 8, max: 24, idle: 16},
                                                    recent: queries, histogram: buckets, n_plus_one: [{sql: "SELECT * FROM order_items WHERE order_id = ?", count: 24,
                                                                                                       caller: "src/endpoints/orders/index_endpoint.cr:31", endpoint: "Orders::IndexEndpoint", suggestion: "Preload order_items for this collection before iterating."}]}}.to_json)
hud = Dev::Hud.new("storefront", "4000", "development", "Illustrative telemetry", directory: "~/projects/storefront", commands: [] of Dev::Control::Command)
hud.update(Dev::Events::AppStarted.new(48231_i64))
hud.update(Dev::Events::Telemetry.new(telemetry))
press(hud, '9')
capture(hud, "dev-errors")
hud.update(UI::Key.new(UI::KeyCode::Tab))
hud.update(UI::Key.new(UI::KeyCode::End))
capture(hud, "dev-errors-stack")
press(hud, '5')
capture(hud, "dev-sql")
hud.update(UI::Key.new(UI::KeyCode::End))
capture(hud, "dev-sql-n-plus-one")
puts "Rendered seven terminal frames to #{OUTPUT}"
