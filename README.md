# irker - IRC Notification Daemon

A specialized IRC client daemon that enables programs to send IRC notifications through a persistent connection, eliminating join/leave spam.

## Overview

**irker** is a daemon that maintains persistent IRC connections and accepts notification requests via JSON over TCP/UDP. It's designed primarily for version control system hooks (git, Mercurial, Subversion) to broadcast commit notifications to IRC channels.

### Key Components

- **irkerd** - The IRC relay daemon that maintains connections
- **irkerhook.py** - VCS hook script (supports git, hg, Subversion)
- **irk** - Command-line client for testing and manual notifications

### Why Use irker?

Instead of individual scripts connecting/disconnecting for each notification (causing join/leave spam), irker maintains persistent connections to IRC servers and channels, making notifications cleaner and more efficient.

## Architecture

```
[VCS Hook] → JSON → [irkerd:6659] → IRC Protocol → [IRC Server] → [Channels]
```

**irkerd** listens on port 6659 for JSON messages of the form:
```json
{"to": "irc://server.net/channel", "privmsg": "notification text"}
```

The daemon handles:
- Connection pooling (maintains connections to multiple servers/channels)
- Anti-flood protection (rate limiting)
- Automatic reconnection on failures
- SSL/TLS support for secure IRC connections
- SOCKS proxy support

## Installation

### Prerequisites

- **Python 3.x** (Python 2 support is deprecated)
- Optional: `pip install -r requirements.txt` (for SOCKS proxy support)

### Quick Start

1. **Install irkerd as a daemon:**

   ```bash
   # Start manually (foreground with logging)
   ./irkerd -d info

   # Or install as systemd service
   sudo cp irkerd.service /etc/systemd/system/
   sudo useradd -r -s /bin/false irker  # Create irker user
   sudo systemctl enable irkerd
   sudo systemctl start irkerd
   ```

2. **Configure your firewall:**
   ```bash
   # IMPORTANT: Block port 6659 from external access
   # irkerd should only be accessible from inside your network
   sudo ufw deny 6659/tcp
   sudo ufw deny 6659/udp
   ```

3. **Test the installation:**
   ```bash
   # Send a test message
   ./irk '#test-channel' 'Hello from irker!'

   # Or with full IRC URL
   ./irk 'irc://chat.freenode.net/#test' 'Test message'
   ```

## Usage

### Using the irk Command-Line Tool

```bash
# Basic usage
./irk <channel-or-url> <message>

# Examples
./irk '#myproject' 'Build completed successfully'
./irk 'irc://irc.libera.chat/#commits' 'New commit pushed'

# Pipe input
echo "Multi-line message" | ./irk '#channel' -
```

### Using irkerhook.py in Version Control

#### Git Hook Installation

Add to `.git/hooks/update` or `.git/hooks/post-receive`:

```bash
#!/bin/sh
# Project configuration
project="MyProject"
channels="irc://irc.libera.chat/#myproject-commits"

# Call irkerhook
/path/to/irkerhook.py --project="$project" --channels="$channels" "$@"
```

Make the hook executable:
```bash
chmod +x .git/hooks/update
```

#### Mercurial Hook Installation

Add to `.hg/hgrc`:
```ini
[hooks]
changegroup = /path/to/irkerhook.py --project=MyProject --channels='irc://irc.libera.chat/#myproject'
```

#### Subversion Hook Installation

Add to `hooks/post-commit`:
```bash
#!/bin/sh
REPOS="$1"
REV="$2"
/path/to/irkerhook.py --project=MyProject --channels='irc://irc.libera.chat/#myproject' "$REPOS" "$REV"
```

### irkerhook.py Configuration Options

```bash
# Test mode - print JSON without sending
irkerhook.py -n

# Custom server (default: localhost:6659)
irkerhook.py --server=192.168.1.100

# Multiple channels
irkerhook.py --channels='irc://server1/#chan1,irc://server2/#chan2'

# Custom URL prefix for commit links
irkerhook.py --urlprefix='https://github.com/user/repo/commit/'

# Use tinyurl for link shortening
irkerhook.py --tinyifier='http://tinyurl.com/api-create.php?url='

# Custom message template
irkerhook.py --template='%(project)s: %(author)s committed %(rev)s: %(logmsg)s'
```

### Direct JSON API

Send JSON directly to irkerd via TCP or UDP on port 6659:

```python
import socket
import json

# Create notification
notification = {
    "to": "irc://irc.libera.chat/#myproject",
    "privmsg": "Deployment completed successfully"
}

# Send via TCP
sock = socket.create_connection(("localhost", 6659))
sock.sendall(json.dumps(notification).encode('utf-8') + b'\n')
sock.close()
```

Multiple channels:
```python
notification = {
    "to": [
        "irc://irc.libera.chat/#channel1",
        "irc://irc.libera.chat/#channel2"
    ],
    "privmsg": "Broadcasting to multiple channels"
}
```

## irkerd Command-Line Options

```bash
./irkerd [options]

-d LEVEL          Debug level (critical, error, warning, info, debug)
-l LOGFILE        Log to file instead of stderr
-H HOST           Hostname for IRC connections (default: localhost)
-n NICK           IRC nickname prefix (default: irker)
-p PASSWORD       Server password
-P PASSWORDFILE   Read server password from file
-i IRC-URL        Immediate send mode (send message and exit)
-t TIMEOUT        Connection timeout in seconds
-c CA-FILE        SSL certificate authority file
-e CERT-FILE      SSL client certificate file
-V                Show version and exit
-h                Show help
```

### Examples

```bash
# Run with debug logging
./irkerd -d debug -l /var/log/irkerd.log

# Use custom nickname
./irkerd -n mybot

# Immediate mode (send one message and exit)
./irkerd -i 'irc://irc.libera.chat/#test' 'One-time message'

# SSL connection with custom certificates
./irkerd -c /path/to/ca.crt -e /path/to/client.crt
```

## Configuration

### Environment Variables

irkerhook.py can read configuration from git repository config:

```bash
# Set project name
git config irker.project "MyAwesomeProject"

# Set notification channels
git config irker.channels "irc://irc.libera.chat/#myproject,irc://irc.libera.chat/#commits"

# Set custom server
git config irker.server "192.168.1.100"

# Set URL prefix for commits
git config irker.urlprefix "https://github.com/user/repo/commit/"
```

### Message Filtering

Create a filter script to customize notification content:

```python
# filter-example.py
def filter_message(message):
    """Modify message before sending to IRC"""
    # Add custom prefix
    message['privmsg'] = '[BOT] ' + message['privmsg']
    return message
```

Use with irkerhook:
```bash
irkerhook.py --filter=/path/to/filter-example.py
```

## Security Considerations

**CRITICAL: irkerd can be abused as a spam relay if exposed publicly.**

### Security Checklist

- [ ] **Block port 6659** from external access via firewall
- [ ] **Run irkerd inside your network perimeter**
- [ ] **Never expose irkerd to the public internet**
- [ ] **Use a dedicated user account** (not root)
- [ ] **Monitor logs** for suspicious activity

See `security.adoc` for detailed security analysis.

## Troubleshooting

### Test Connection

```bash
# Verify irkerd is running
netstat -tulpn | grep 6659

# Test with irk
./irk '#test' 'Connection test'

# Test with irkerhook in dry-run mode
cd /path/to/repo
irkerhook.py -n  # Shows JSON output without sending
```

### Common Issues

**No notifications appearing:**
- Check firewall allows localhost:6659 connections
- Verify irkerd is running: `ps aux | grep irkerd`
- Check irkerd logs: `journalctl -u irkerd` (systemd) or check log file
- Test with `irk` to isolate hook vs daemon issues

**Join/leave spam:**
- This suggests irkerd isn't maintaining connections
- Check irkerd timeout settings (default 3 hours)
- Verify irkerd has sufficient resources and isn't crashing

**Authentication errors:**
- Some IRC servers require NickServ authentication
- Use `-p` option or configure password file
- Check IRC server supports the authentication method

**SSL/TLS errors:**
- Ensure `ircs://` URL scheme for SSL connections
- Verify certificate paths with `-c` and `-e` options
- Check server certificate validity

### Debug Mode

Run irkerd in debug mode to see all activity:
```bash
./irkerd -d debug
```

This shows:
- All incoming JSON requests
- IRC protocol exchanges
- Connection state changes
- Error conditions

## Advanced Features

### Connection Pooling

irkerd maintains connection pools with configurable timeouts:

- **XMIT_TTL**: 3 hours - idle connection lifetime
- **PING_TTL**: 15 minutes - keepalive interval
- **CHANNEL_MAX**: 18 - max channels per connection
- **CONNECTION_MAX**: 200 - max total connections

Edit these in `irkerd` source if needed.

### Proxy Support

Use SOCKS proxy for IRC connections:

```bash
# Install proxy support
pip install -r requirements.txt

# Edit irkerd source to configure proxy
PROXY_TYPE = 2  # 1=SOCKS4, 2=SOCKS5, 3=HTTP
PROXY_HOST = "proxy.example.com"
PROXY_PORT = 1080
```

### Load Balancing

Run multiple irkerd instances on different ports:
```bash
# Instance 1
./irkerd -H localhost -p 6659

# Instance 2
./irkerd -H localhost -p 6660
```

Configure hooks to distribute load across instances.

## Integration Examples

### GitHub Actions

```yaml
name: IRC Notify
on: [push]
jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Send IRC notification
        run: |
          echo '{"to":"irc://irc.libera.chat/#myproject","privmsg":"GitHub: New push by ${{ github.actor }}"}' | \
          nc -w 1 irker.example.com 6659
```

### GitLab CI

```yaml
notify_irc:
  stage: deploy
  script:
    - |
      echo "{\"to\":\"irc://irc.libera.chat/#myproject\",\"privmsg\":\"GitLab: Pipeline $CI_PIPELINE_ID passed\"}" | \
      nc -w 1 irker.example.com 6659
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    post {
        success {
            sh '''
                echo '{"to":"irc://irc.libera.chat/#builds","privmsg":"Jenkins: Build SUCCESS"}' | \
                nc -w 1 localhost 6659
            '''
        }
    }
}
```

## Project Resources

- **Documentation**: See `install.adoc`, `security.adoc`, `hacking.adoc`
- **Man Pages**: `irkerd.xml`, `irkerhook.xml`, `irk.xml` (DocBook sources)
- **License**: BSD-2-Clause (see `COPYING` and `LICENSE`)
- **Project Page**: http://www.catb.org/~esr/irker/
- **IRC Channel**: `irc://chat.freenode.net/#irker`

## Contributing

See `hacking.adoc` for development guidelines.

## Version

Current version: 2.24

## Author

Design and code by Eric S. Raymond <esr@thyrsus.com>

## See Also

- `irkerd(8)` - Daemon man page
- `irkerhook(1)` - Hook script man page
- `irk(1)` - Test client man page
- RFC 1459 - IRC Protocol specification
