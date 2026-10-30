#!/bin/sh
# Requires an isolated Redis supplied by REDIS_HOST / REDIS_PORT (CI service).
# Compiles the exact embedded adapter against the supported upstream release.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export AZU_ADAPTER_CHECK_ID="azu-hud-check-$$"
cd "$WORK"
cat > shard.yml <<'YAML'
name: dashboard_adapter_check
version: 0.1.0
dependencies:
  joobq:
    github: azutoolkit/joobq
    version: 0.4.2
YAML
if [ "${JOOBQ_REF:-0.4.2}" = 0.5.1 ]; then
  sed -i "s/version: 0.4.2/version: 0.5.1/" shard.yml
elif [ "${JOOBQ_REF:-0.4.2}" != 0.4.2 ]; then
  sed -i "s/version: 0.4.2/commit: $JOOBQ_REF/" shard.yml
fi
shards install
cat "$ROOT/src/azu_cli/integrations/joobq_protocol.cr" > agent.cr
cat >> agent.cr <<'CR'
require "joobq"
id = ENV["AZU_ADAPTER_CHECK_ID"]
JoobQ.config.queue_configs[id] = {job_class_name: "Unused", workers: 1, throttle: nil}
{% if JoobQ.has_constant?("DeadLetterQueue") %}
member = {jid: id, queue: id, password: "must-not-be-exported", error: {message: "fixture failure"}}.to_json
JoobQ::DeadLetterQueue.add(JoobQ.store.redis, Time.utc.to_unix_ms, [member])
{% end %}
CR
cat "$ROOT/src/azu_cli/integrations/joobq_agent.cr" >> agent.cr
crystal build agent.cr -o agent --error-trace
python3 - <<'PY'
import json, os, subprocess
job_id = os.environ['AZU_ADAPTER_CHECK_ID']
requests = [{'action':'snapshot'}, {'action':'replay','id':job_id}, {'action':'replay','id':job_id}, {'action':'snapshot'}]
output = subprocess.run(['./agent'], input=''.join(json.dumps(r)+'\n' for r in requests), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30, check=True).stdout
rows = [json.loads(line[len('AZU_JOOBQ:'):]) for line in output.splitlines() if line.startswith('AZU_JOOBQ:')]
assert len(rows)==4 and rows[0]['ok'] and rows[3]['ok'], rows
if rows[0]['data']['replay_supported']:
 assert all(row['ok'] for row in rows), rows
 assert 'must-not-be-exported' not in json.dumps(rows)
 assert '[FILTERED]' in json.dumps(rows[0])
 assert rows[1]['data']['succeeded']==1, rows[1]
 assert rows[2]['data']['succeeded']==0, rows[2]
 queue = next(q for q in rows[3]['data']['queues'] if q['name']==job_id)
 assert queue['pending']==1, queue
 assert not any(job['jid']==job_id for job in rows[3]['data']['dlq'])
 print('Live JoobQ adapter: redaction, atomic replay and duplicate replay checks passed')
else:
 assert not rows[1]['ok'] and not rows[2]['ok'], rows
 assert len(rows[0]['data']['queues'])==1
 print('Released JoobQ adapter: queue snapshot and explicit unsupported replay checks passed')
PY

# Compile the CLI operator without any application job types. This catches
# NoReturn inference failures hidden by concrete jobs in the normal fixture.
if [ "${JOOBQ_REF:-}" = "0.5.1" ]; then
  cp "$ROOT/src/azu_cli/integrations/jobs_operator.cr" empty_operator.cr
  crystal build empty_operator.cr -o empty_operator --error-trace
  python3 - <<'PY_CHECK'
import json, subprocess
request = '{"all_queues":true}'
status = subprocess.run(['./empty_operator', 'status'], input=request, text=True, capture_output=True, timeout=15, check=True)
rows = [json.loads(line.removeprefix('AZU_JOBS:')) for line in status.stdout.splitlines() if line.startswith('AZU_JOBS:')]
assert len(rows) == 1 and rows[0]['queues'] == [], status.stdout
worker = subprocess.run(['./empty_operator', 'worker'], input=request, text=True, capture_output=True, timeout=15)
assert worker.returncode == 2 and 'No queues configured' in worker.stderr, worker
print('Empty operator compiles; status works and worker reports an actionable error')
PY_CHECK
fi
