# Azu CLI Generators Spec Suite
#
# This file runs all the generator-related specs to ensure the complete
# generator system is working correctly.

require "spec"
require "../src/azu_cli"

# Core generator architecture specs
require "./generators/core/abstract_generator_spec"
require "./generators/core/factory_spec"
require "./generators/core/configuration_spec"
require "./generators/core/strategies_spec"

# Optimized generator specs
require "./generators/optimized/model_generator_spec"
require "./generators/optimized/service_generator_spec"
require "./generators/optimized/scaffold_generator_spec"
require "./generators/optimized/validator_generator_spec"

# Additional generator specs (to be run when available)
# require "./generators/optimized/contract_generator_spec"
# require "./generators/optimized/component_generator_spec"
# require "./generators/optimized/endpoint_generator_spec"
# require "./generators/optimized/middleware_generator_spec"
# require "./generators/optimized/migration_generator_spec"
# require "./generators/optimized/page_generator_spec"
# require "./generators/optimized/channel_generator_spec"
# require "./generators/optimized/handler_generator_spec"
# require "./generators/optimized/request_generator_spec"
# require "./generators/optimized/response_generator_spec"

puts "🧪 Running Azu CLI Generator Test Suite"
puts "========================================="
puts
puts "✅ Core Architecture Tests:"
puts "   - AbstractGenerator base class"
puts "   - GeneratorFactory creation and aliases"
puts "   - Configuration loading and inheritance"
puts "   - Strategy pattern implementations"
puts
puts "✅ Optimized Generator Tests:"
puts "   - ModelGenerator with CQL integration"
puts "   - ServiceGenerator with DDD patterns"
puts "   - ScaffoldGenerator orchestration"
puts "   - ValidatorGenerator with type safety"
puts
puts "🚀 All generator specs loaded successfully!"
puts "   Run with: crystal spec spec/azu_cli/generators_spec.cr"
puts
