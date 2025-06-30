# Hot Reloading Development Server

The Azu CLI includes a powerful hot reloading development server that automatically rebuilds your application and refreshes the browser when files change. This dramatically improves development productivity by providing instant feedback.

## Features

### 🔥 **Automatic Rebuilds**

- Detects changes to Crystal source files (`.cr`)
- Automatically recompiles the application
- Restarts the server with the new binary
- Shows build errors in real-time

### 🎨 **Template Hot Reloading**

- Monitors template files (`.jinja`, `.html`, `.ecr`)
- Automatically refreshes pages when templates change
- No need to manually refresh the browser
- Preserves scroll position when possible

### 💄 **Static Asset Reloading**

- Watches CSS and JavaScript files
- Intelligently reloads stylesheets without page refresh
- Forces page reload for JavaScript changes
- Cache-busting for immediate updates

### 🔌 **WebSocket Communication**

- Real-time communication between server and browser
- Automatic reconnection if connection is lost
- Visual notifications for different types of changes
- Debug mode for troubleshooting

## Getting Started

### Basic Usage

Start the development server with hot reloading:

```bash
azu serve
```

This will:

1. Build your application
2. Start the application server on `http://localhost:3000`
3. Start the hot reload WebSocket server on port `35729`
4. Begin watching for file changes

### Command Options

```bash
azu serve [options]

Options:
  --host HOST               Host to bind to (default: localhost)
  --port PORT               Port to run on (default: 3000)
  --hot-reload-port PORT    Hot reload WebSocket port (default: 35729)
  --no-watch                Disable file watching
  --verbose                 Enable verbose output

Examples:
  azu serve                          # Start with defaults
  azu serve --port 4000              # Use custom port
  azu serve --host 0.0.0.0           # Bind to all interfaces
  azu serve --no-watch               # Disable hot reloading
  azu serve --verbose                # Show detailed output
```

### Using the `dev` Alias

For convenience, you can use the shorter `dev` command:

```bash
azu dev
azu dev --port 4000
```

## How It Works

### File Watching

The hot reload system monitors these file patterns:

- `src/**/*.cr` - Crystal source files
- `config/**/*.cr` - Configuration files
- `public/templates/**/*.jinja` - Jinja templates
- `public/templates/**/*.html` - HTML templates
- `public/assets/**/*.css` - Stylesheets
- `public/assets/**/*.js` - JavaScript files

### Change Detection

When a file changes, the system determines the appropriate action:

| File Type      | Action                 | Browser Behavior                              |
| -------------- | ---------------------- | --------------------------------------------- |
| `.cr` files    | Full rebuild + restart | Page reload after successful build            |
| Template files | Template reload        | Page reload with template update notification |
| CSS files      | Asset reload           | Stylesheet refresh without page reload        |
| JS files       | Asset reload           | Page reload                                   |

### Browser Integration

The hot reload client is automatically injected into your HTML pages when:

- Running in development mode
- The `hot_reload_enabled` template variable is true
- Accessing from localhost, 127.0.0.1, or 0.0.0.0

## Client-Side Features

### Visual Notifications

The hot reload client shows non-intrusive notifications for:

- ✅ **Successful connections** - "🔥 Hot reload enabled"
- 🔄 **Page reloads** - "🔄 Reloading page..."
- 🎨 **Template updates** - "🎨 Template updated"
- 💄 **Style updates** - "🎨 Styles updated"
- ❌ **Build errors** - "❌ Build failed - check console"
- 🔌 **Connection issues** - "❌ Hot reload disconnected"

### Automatic Reconnection

The client automatically attempts to reconnect when:

- The connection is lost
- The page regains focus
- The page becomes visible (tab switching)

### Debug Mode

Enable detailed logging in the browser console:

```javascript
window.AZU_HOT_RELOAD_DEBUG = true;
```

Or set the debug flag in the configuration.

## Configuration

### Environment Variables

Configure the development server using environment variables:

```bash
export AZU_HOST=0.0.0.0          # Default host
export AZU_PORT=4000             # Default port
export AZU_ENV=development       # Environment
export HOT_RELOAD=true           # Enable hot reload
export HOT_RELOAD_PORT=35729     # WebSocket port
```

### Project Configuration

Add hot reload settings to your `azu.yml` configuration:

```yaml
# azu.yml
environment: development

server:
  host: "localhost"
  port: 3000
  watch: true
  rebuild: true

development:
  hot_reload_enabled: true
  hot_reload_port: 35729
  hot_reload_debug: false
```

### Application Configuration

In your Azu application, configure template variables:

```crystal
# src/your_app.cr
configure do |config|
  # Enable hot reload in development
  config.hot_reload_enabled = config.env.development?

  # Template hot reloading
  config.template_hot_reload = config.env.development?
end
```

## Template Integration

The hot reload script is automatically included when the `hot_reload_enabled` variable is true:

```jinja
<!-- public/templates/layout.jinja -->
{% if hot_reload_enabled %}
<!-- Azu Hot Reload Script - Development Only -->
<script>
  // Hot reload client code is automatically injected
</script>
{% endif %}
```

## Troubleshooting

### Common Issues

#### Hot Reload Not Working

1. **Check if watching is enabled:**

   ```bash
   azu serve --verbose
   ```

2. **Verify WebSocket connection:**

   - Open browser developer tools
   - Check for WebSocket connection to `ws://localhost:35729`
   - Look for connection errors in console

3. **Check file permissions:**
   - Ensure the CLI can read your source files
   - Verify write permissions for the build directory

#### Build Failures

1. **Check Crystal compiler output:**

   - Build errors are displayed in the terminal
   - Fix syntax errors and save again

2. **Verify project structure:**
   - Ensure `src/your_app.cr` exists
   - Check that all required files are present

#### Connection Issues

1. **Firewall blocking WebSocket:**

   - Ensure port 35729 is not blocked
   - Try a different port with `--hot-reload-port`

2. **Multiple server instances:**
   - Kill any existing server processes
   - Check for port conflicts

### Debug Mode

Enable verbose logging to diagnose issues:

```bash
azu serve --verbose
```

This will show:

- File change events
- Build process details
- WebSocket connection status
- Client communication

### Network Access

To access the development server from other devices:

```bash
azu serve --host 0.0.0.0 --port 3000
```

Then access from other devices using your machine's IP:

```
http://192.168.1.100:3000
```

**Note:** Hot reload WebSocket connections require the same host, so ensure your device can connect to the hot reload port (35729) as well.

## Performance Considerations

### File Watching Optimization

The file watcher checks for changes every 500ms. For large projects:

1. **Exclude unnecessary directories:**

   - The system automatically ignores common patterns
   - Binary files, logs, and cache directories are excluded

2. **Use specific patterns:**
   - Focus watching on source directories only
   - Avoid watching node_modules or similar large directories

### Build Performance

- **Initial builds** may take longer as dependencies are compiled
- **Incremental builds** are faster, only recompiling changed modules
- **Parallel builds** are used when possible

## Advanced Usage

### Custom File Patterns

Currently, file patterns are hardcoded but future versions will support:

```yaml
# Future configuration
hot_reload:
  watch_patterns:
    - "src/**/*.cr"
    - "custom/**/*.template"
  ignore_patterns:
    - "**/node_modules/**"
    - "**/.git/**"
```

### Integration with IDEs

The hot reload system works well with:

- **VS Code** - Files are monitored automatically
- **Vim/Neovim** - Works with auto-save plugins
- **Any editor** - Just save files normally

### CI/CD Integration

Disable hot reloading in CI environments:

```bash
export AZU_ENV=production
azu build  # Instead of azu serve
```

## API Reference

### Commands

- `azu serve [options]` - Start development server with hot reloading
- `azu dev [options]` - Alias for the serve command

### Client API

The hot reload client exposes a global API:

```javascript
// Manual control (advanced usage)
window.azuHotReload.connect(); // Manually connect
window.azuHotReload.disconnect(); // Manually disconnect
window.AZU_HOT_RELOAD_DEBUG = true; // Enable debug mode
```

### WebSocket Messages

The WebSocket API uses these message types:

```json
{
  "type": "full_reload",
  "data": {
    "file": "src/controllers/users.cr",
    "timestamp": 1679875200
  }
}

{
  "type": "template_reload",
  "data": {
    "file": "public/templates/users/index.jinja",
    "timestamp": 1679875300
  }
}

{
  "type": "static_reload",
  "data": {
    "file": "public/assets/css/app.css",
    "timestamp": 1679875400
  }
}

{
  "type": "build_error",
  "data": {
    "file": "src/models/user.cr",
    "error": "Syntax error on line 25"
  }
}
```

## Best Practices

### Development Workflow

1. **Start with hot reload:**

   ```bash
   azu serve
   ```

2. **Keep the terminal visible** to see build output and errors

3. **Use the browser console** to debug client-side issues

4. **Save frequently** to get immediate feedback

### File Organization

- Keep templates in `public/templates/`
- Organize Crystal files in `src/` subdirectories
- Place static assets in `public/assets/`
- Use meaningful file names for easier debugging

### Performance Tips

- **Close unused browser tabs** to reduce WebSocket connections
- **Use specific file patterns** to avoid watching unnecessary files
- **Fix build errors quickly** to avoid blocking the rebuild process

## Future Enhancements

The hot reload system will continue to evolve with features like:

- **Partial page updates** without full reload
- **Component-level hot swapping**
- **State preservation** across reloads
- **Parallel file watching** for better performance
- **Custom reload strategies** per file type
- **Integration with browser dev tools**

---

The hot reloading development server makes Azu development fast and enjoyable. Combined with Crystal's compile-time type checking and Azu's powerful features, you get a robust development experience that scales from prototypes to production applications.
