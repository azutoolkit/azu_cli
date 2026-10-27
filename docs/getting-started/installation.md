# Installation

Azu CLI is one binary, built from source with Crystal. There is no Homebrew formula and no prebuilt release binary yet.

## Overview

You need Crystal and `shards`, then `make install`. A SQLite library is enough for the default database; PostgreSQL and
MySQL need a server only if you pick them.

```mermaid
flowchart LR
  A["Install Crystal 1.22.1+"] --> B["git clone azu_cli"]
  B --> C["shards install"]
  C --> D["make install"]
  D --> E["azu version"]
```

## Quickstart

### 1. Crystal

{% tabs %}
{% tab title="macOS" %}
```bash
brew install crystal sqlite
```
{% endtab %}

{% tab title="Ubuntu / Debian" %}
Follow the [official instructions](https://crystal-lang.org/install/), then:

```bash
sudo apt install libsqlite3-dev libreadline-dev libevent-dev libssl-dev libxml2-dev libyaml-dev libgmp-dev
```
{% endtab %}

{% tab title="Arch" %}
```bash
sudo pacman -S crystal shards sqlite
```
{% endtab %}
{% endtabs %}

### 2. The CLI

{% tabs %}
{% tab title="System-wide" %}
```bash
git clone https://github.com/azutoolkit/azu_cli.git
cd azu_cli
shards install
sudo make install      # builds a release binary, copies it to /usr/local/bin/azu, installs the man page
```
{% endtab %}

{% tab title="Your home directory" %}
```bash
git clone https://github.com/azutoolkit/azu_cli.git
cd azu_cli
shards install
make build             # bin/azu
install -m 755 bin/azu ~/.local/bin/azu
```
{% endtab %}
{% endtabs %}

### 3. Check it

```bash
azu version
```

| Make target        | What it does                                         |
| ------------------ | ---------------------------------------------------- |
| `make build`       | `shards build --production`, binary at `bin/azu`     |
| `make install`     | build, then copy to `$(PREFIX)/bin` (default `/usr/local`) and install the man page |
| `make install-man` | the man page only                                    |
| `make clean`       | uninstall                                            |

## Shell completion

{% tabs %}
{% tab title="bash" %}
```bash
echo 'eval "$(azu completion bash)"' >> ~/.bashrc
```
{% endtab %}

{% tab title="zsh" %}
```bash
echo 'eval "$(azu completion zsh)"' >> ~/.zshrc
```
{% endtab %}

{% tab title="fish" %}
```bash
azu completion fish > ~/.config/fish/completions/azu.fish
```
{% endtab %}
{% endtabs %}

`azu completion` with no shell argument guesses from `$SHELL`; `--shell NAME` forces one.

## Output

```text
$ azu version
Azu CLI v0.1.46
Crystal 1.22.1
Topia CLI Framework

Plugins:
  - Generator Plugin v1.0.0
  - Database Plugin v1.0.0
  - Development Plugin v1.0.0
```

On a color terminal inside a project the same command is a card that also lists the `azu`, `cql` and `joobq`
versions from `shard.lock` (`--ui plain` for the text above).

<figure><img src="../assets/terminal-ui/18-version.png" alt="azu version card"><figcaption><p><code>azu version</code> on a color terminal.</p></figcaption></figure>

## Do's and don'ts

{% hint style="success" %}
Run `azu doctor` in a project after installing. It checks Crystal, shards, dependencies, database, ports and secrets, and
changes nothing.
{% endhint %}

{% hint style="warning" %}
`azu --version` is not understood (it reports an unknown command). Use `azu version`.
{% endhint %}

{% hint style="danger" %}
Do not run the CLI inside a checkout you do not trust. It loads the project's `.env*` files and compiles and runs the
project's own code.
{% endhint %}

<details>

<summary>Troubleshooting</summary>

**`crystal: command not found`**: the Crystal bin directory is not on `PATH`; open a new shell or check the installer output.

**`Error: Package ... not found` during `shards install`**: network access to GitHub is required to fetch dependencies.

**Linker errors about `sqlite3`, `ssl` or `yaml`**: install the development packages from the Ubuntu tab above.

**Permission denied on `make install`**: use `sudo`, or the "Your home directory" tab.

</details>
