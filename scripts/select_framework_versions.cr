# Test-only dependency selection shared by generated-app compatibility gates.
require "yaml"
path = ARGV.first? || "shard.yml"
document = YAML.parse(File.read(path))
dependencies = document["dependencies"]?
if dependencies
  {"azu", "cql"}.each do |name|
    next unless dependency = dependencies[name]?
    choices = {"version", "commit", "branch"}.compact_map do |kind|
      ENV["E2E_#{name.upcase}_#{kind.upcase}"]?.try { |value| {kind, value} unless value.empty? }
    end
    abort "Choose only one version, commit or branch for #{name}" if choices.size > 1
    if selected = choices.first?
      {"version", "commit", "branch", "tag"}.each { |key| dependency.as_h.delete(YAML::Any.new(key)) }
      dependency.as_h[YAML::Any.new(selected[0])] = YAML::Any.new(selected[1])
    end
    puts "#{name}: #{dependency}"
  end
  File.write(path, document.to_yaml)
end
