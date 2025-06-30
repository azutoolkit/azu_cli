# Installation

This guide will help you install Azu CLI on your development machine. Azu CLI is distributed as a single binary and works on macOS, Linux, and Windows.

## Prerequisites

Before installing Azu CLI, ensure you have the following prerequisites:

### Crystal Language

Azu CLI requires Crystal 1.6.0 or higher.

**macOS (using Homebrew):**

```bash
brew install crystal
```

**Ubuntu/Debian:**

```bash
curl -fsSL https://packagecloud.io/84codes/crystal/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/84codes-crystal.gpg
echo "deb [signed-by=/usr/share/keyrings/84codes-crystal.gpg] https://packagecloud.io/84codes/crystal/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/84codes-crystal.list
sudo apt update
sudo apt install crystal
```

**Arch Linux:**

```bash
sudo pacman -S crystal
```

**From Source:**

```bash
git clone https://github.com/crystal-lang/crystal.git
cd crystal
make clean crystal
```

### Database (Optional)

Azu applications typically use a database. Install one of the supported databases:

**PostgreSQL (Recommended):**

```bash
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt install postgresql postgresql-contrib

# Arch Linux
sudo pacman -S postgresql
```

**MySQL:**

```bash
# macOS
brew install mysql

# Ubuntu/Debian
sudo apt install mysql-server

# Arch Linux
sudo pacman -S mysql
```

**SQLite:**

```bash
# Usually comes pre-installed on most systems
# macOS
brew install sqlite

# Ubuntu/Debian
sudo apt install sqlite3

# Arch Linux
sudo pacman -S sqlite
```

## Installation Methods

### Method 1: From Source (Recommended)

This is the most reliable method and ensures you get the latest version.

1. **Clone the repository:**

   ```bash
   git clone https://github.com/azutoolkit/azu_cli.git
   cd azu_cli
   ```

2. **Install dependencies:**

   ```bash
   shards install
   ```

3. **Build and install:**

   ```bash
   make install
   ```

   This will:

   - Compile the binary in release mode
   - Install it to `/usr/local/bin/azu` (may require `sudo`)
   - Make it available system-wide

4. **Verify installation:**
   ```bash
   azu version
   ```

### Method 2: Using Make (Alternative)

If you prefer to build manually:

1. **Clone and build:**

   ```bash
   git clone https://github.com/azutoolkit/azu_cli.git
   cd azu_cli
   make
   ```

2. **Install manually:**
   ```bash
   sudo make install
   ```

### Method 3: Development Installation

For development or if you want to modify Azu CLI:

1. **Clone the repository:**

   ```bash
   git clone https://github.com/azutoolkit/azu_cli.git
   cd azu_cli
   ```

2. **Install dependencies:**

   ```bash
   shards install
   ```

3. **Build in development mode:**

   ```bash
   crystal build src/main.cr -o bin/azu
   ```

4. **Add to PATH (optional):**
   ```bash
   export PATH="$PWD/bin:$PATH"
   # Add to your shell profile for persistence
   echo 'export PATH="$PWD/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
   ```

## Post-Installation Setup

### 1. Verify Installation

```bash
azu version
# Should output: Azu CLI v0.0.1+13

azu help
# Should display the help menu
```

### 2. Configure Global Settings (Optional)

Create a global configuration file:

```bash
mkdir -p ~/.config/azu
cat > ~/.config/azu/config.yml << EOF
# Global Azu CLI configuration
default_database: postgres
default_template: web
editor: code  # or vim, nano, etc.
git_auto_init: true
EOF
```

### 3. Set Up Database

If you're planning to use databases, ensure your database server is running:

**PostgreSQL:**

```bash
# macOS (Homebrew)
brew services start postgresql

# Linux (systemd)
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create a user (optional)
createuser -s $USER
```

**MySQL:**

```bash
# macOS (Homebrew)
brew services start mysql

# Linux (systemd)
sudo systemctl start mysql
sudo systemctl enable mysql
```

## Troubleshooting

### Common Issues

#### 1. "azu: command not found"

**Solution 1:** Check if the binary is in your PATH:

```bash
which azu
echo $PATH
```

**Solution 2:** Reinstall with proper permissions:

```bash
sudo make install
```

**Solution 3:** Add to PATH manually:

```bash
export PATH="/usr/local/bin:$PATH"
```

#### 2. Permission Denied During Installation

```bash
# Use sudo for system-wide installation
sudo make install

# Or install to user directory
make install PREFIX=~/.local
export PATH="$HOME/.local/bin:$PATH"
```

#### 3. Crystal Not Found

Ensure Crystal is properly installed and in your PATH:

```bash
crystal version
# Should output Crystal version information
```

#### 4. Compilation Errors

Update your Crystal installation:

```bash
# macOS
brew upgrade crystal

# Linux - follow Crystal installation guide for your distribution
```

Clear shards cache and reinstall:

```bash
rm -rf lib/ shard.lock
shards install
```

#### 5. Database Connection Issues

Ensure your database service is running:

```bash
# PostgreSQL
sudo systemctl status postgresql

# MySQL
sudo systemctl status mysql

# Or check processes
ps aux | grep postgres
ps aux | grep mysql
```

### Getting Help

If you encounter issues during installation:

1. **Check the logs** during compilation for specific errors
2. **Verify prerequisites** are properly installed
3. **Update Crystal** to the latest version
4. **Clear build cache**: `make clean && make`
5. **Create an issue** on [GitHub](https://github.com/azutoolkit/azu_cli/issues) with:
   - Your operating system and version
   - Crystal version (`crystal version`)
   - Full error output
   - Installation method used

## Updating Azu CLI

To update to the latest version:

```bash
cd /path/to/azu_cli
git pull origin master
shards install
make clean
make install
```

## Uninstalling

To remove Azu CLI:

```bash
sudo rm /usr/local/bin/azu
rm -rf ~/.config/azu  # Remove configuration (optional)
```

---

**Next Steps:**

- [Quick Start Guide](quick-start.md) - Create your first Azu application
- [Project Structure](project-structure.md) - Understand Azu project organization
- [Command Reference](../commands/README.md) - Learn all available commands
