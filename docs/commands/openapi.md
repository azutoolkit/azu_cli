# OpenAPI Commands

The Azu CLI provides comprehensive OpenAPI 3.1 support with bidirectional code generation capabilities.

## Commands

### `azu openapi:generate`

Generate Crystal code from an OpenAPI specification file.

**Usage:**
```bash
azu openapi:generate <spec_path> [options]
```

**Arguments:**
- `<spec_path>` - Path to OpenAPI specification file (YAML or JSON)

**Options:**
- `--spec PATH` - Path to OpenAPI specification file
- `--force` - Overwrite existing files without prompting
- `--models-only` - Generate only models from schemas
- `--endpoints-only` - Generate only endpoints from paths
- `--help` - Show help message

**Examples:**
```bash
# Generate all code from OpenAPI spec
azu openapi:generate openapi.yaml

# Generate from JSON spec with force overwrite
azu openapi:generate api-spec.json --force

# Generate only models
azu openapi:generate openapi.yaml --models-only

# Generate only endpoints
azu openapi:generate openapi.yaml --endpoints-only
```

**What Gets Generated:**
- **Models** in `src/models/` from component schemas
- **Endpoints** in `src/endpoints/` from paths
- **Request classes** in `src/requests/` from request bodies
- **Response classes** in `src/pages/` from responses

### `azu openapi:export`

Export an OpenAPI specification from your existing Crystal code.

**Usage:**
```bash
azu openapi:export [options]
```

**Options:**
- `--output PATH` - Output file path (default: `openapi.yaml`)
- `--format FORMAT` - Output format: `yaml` or `json` (default: `yaml`)
- `--project NAME` - Project name (auto-detected from `shard.yml`)
- `--version VERSION` - API version (default: `1.0.0`)
- `--help` - Show help message

**Examples:**
```bash
# Export to default openapi.yaml
azu openapi:export

# Export to JSON format
azu openapi:export --output api-spec.json --format json

# Export with custom version
azu openapi:export --output docs/openapi.yaml --version 2.0.0
```

**What Gets Analyzed:**
- Endpoints in `src/endpoints/`
- Models in `src/models/`
- Request classes in `src/requests/`
- Response classes in `src/pages/`

## OpenAPI Specification Support

### Supported Versions
- OpenAPI 3.1.x (full support)
- OpenAPI 3.0.x (with limitations)

### Type Mapping

#### OpenAPI → Crystal

| OpenAPI Type | OpenAPI Format | Crystal Type |
|--------------|----------------|--------------|
| `string` | - | `String` |
| `string` | `date-time` | `Time` |
| `string` | `date` | `Time` |
| `string` | `uuid` | `UUID` |
| `string` | `email` | `String` |
| `string` | `uri` | `String` |
| `string` | `binary` | `Bytes` |
| `integer` | - | `Int32` |
| `integer` | `int32` | `Int32` |
| `integer` | `int64` | `Int64` |
| `number` | - | `Float64` |
| `number` | `float` | `Float32` |
| `number` | `double` | `Float64` |
| `boolean` | - | `Bool` |
| `array` | - | `Array(T)` |
| `object` | - | `Hash(String, JSON::Any)` or custom class |

#### Crystal → OpenAPI

| Crystal Type | OpenAPI Type | OpenAPI Format |
|--------------|--------------|----------------|
| `String` | `string` | - |
| `Time` | `string` | `date-time` |
| `UUID` | `string` | `uuid` |
| `Int32` | `integer` | `int32` |
| `Int64` | `integer` | `int64` |
| `Float32` | `number` | `float` |
| `Float64` | `number` | `double` |
| `Bool` | `boolean` | - |
| `Bytes` | `string` | `binary` |
| `Array(T)` | `array` | - |
| `Hash(K, V)` | `object` | - |

### Nullable Types

Nullable Crystal types (ending with `?`) are mapped to OpenAPI schemas with `nullable: true`.

## Integration with API Projects

When you create an API project with `azu new myapp --api`, the following OpenAPI features are enabled:

1. **OpenAPI Configuration** - `config/openapi.yml` with API metadata
2. **Swagger UI** - Interactive documentation at `/api/docs/ui`
3. **Spec Endpoint** - OpenAPI spec served at `/api/openapi.json`
4. **Health Endpoint** - Health check at `/health`

## Workflow Examples

### From Spec to Code

1. Design your API using an OpenAPI spec
2. Generate code: `azu openapi:generate openapi.yaml`
3. Implement business logic in generated files
4. Run your API: `azu serve`

### From Code to Spec

1. Build your API with Azu generators
2. Export spec: `azu openapi:export --output docs/openapi.yaml`
3. Share spec with frontend teams
4. Generate client SDKs using OpenAPI tools

### Round-Trip Development

1. Start with initial spec: `azu openapi:generate api-v1.yaml`
2. Develop and extend functionality
3. Export updated spec: `azu openapi:export --output api-v2.yaml`
4. Compare versions and document changes

## Best Practices

### OpenAPI Spec Design

- Use meaningful `operationId` for better code generation
- Include descriptions for all schemas and operations
- Define reusable components for common patterns
- Use `$ref` for schema references
- Tag operations for logical grouping

### Code Organization

- Keep generated files separate from custom logic
- Use service classes for business logic
- Don't modify generated request/response classes directly
- Version your API with path prefixes (`/api/v1/`)

### Documentation

- Keep OpenAPI spec in version control
- Document breaking changes in spec
- Use examples in OpenAPI spec for better docs
- Include authentication requirements

## Troubleshooting

### Generation Issues

**Problem:** Generated code doesn't compile
- Check OpenAPI spec validity with online validators
- Ensure all `$ref` references are resolved
- Verify type formats are supported

**Problem:** Missing models or endpoints
- Check file paths in OpenAPI spec
- Ensure schemas are in `components/schemas`
- Verify paths are defined at top level

### Export Issues

**Problem:** Export fails to find endpoints
- Ensure endpoints follow Azu naming conventions
- Check endpoint files are in `src/endpoints/`
- Verify struct definitions include `Azu::Endpoint`

**Problem:** Type mapping errors
- Use standard Crystal types (String, Int32, etc.)
- Avoid complex union types in public APIs
- Use custom classes for complex objects

## See Also

- [API Resource Generator](../generators/api-resource.md)
- [REST API Example](../examples/rest-api.md)
- [New Command](./new.md) - Creating API projects
- [Generate Command](./generate.md) - Code generation

