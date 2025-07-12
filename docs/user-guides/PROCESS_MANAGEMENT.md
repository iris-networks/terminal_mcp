# Process Management and Security

This guide covers running the MCP Terminal Server with process managers like s6, systemd, and others using non-root permissions for enhanced security.

## Security Model

### Non-Root Execution

Running the server with non-root permissions provides several security benefits:

- **Limited system access**: Commands execute with restricted user permissions
- **No privileged operations**: Cannot modify system files, install packages, or change system configuration
- **Filesystem isolation**: Access limited to user's home directory and explicitly granted paths
- **Process isolation**: Cannot kill system processes or access other users' processes
- **Network restrictions**: Cannot bind to privileged ports (< 1024)

### Principle of Least Privilege

The server follows the principle of least privilege by:
1. Running as a dedicated non-privileged user
2. Having access only to necessary directories
3. Using restricted shell environments when possible
4. Implementing command timeouts to prevent resource exhaustion

## s6 Process Management

s6 is a lightweight process supervision suite that's excellent for managing long-running services.

### Installation

**Alpine Linux:**
```bash
apk add s6
```

**Ubuntu/Debian:**
```bash
apt-get install s6
```

**macOS (via Homebrew):**
```bash
brew install s6
```

### Setup

#### 1. Create Dedicated User

```bash
# Create a dedicated user for the MCP server
sudo useradd -r -s /bin/bash -d /var/lib/mcp-terminal -m mcp-terminal
sudo usermod -a -G mcp-terminal mcp-terminal
```

#### 2. Create Service Directory Structure

```bash
# Create s6 service directory
sudo mkdir -p /etc/s6/sv/mcp-terminal

# Create the service directories
sudo mkdir -p /etc/s6/sv/mcp-terminal/log
```

#### 3. Create Run Script

Create `/etc/s6/sv/mcp-terminal/run`:

```bash
#!/bin/bash
exec 2>&1

# Set environment variables
export MCP_COMMAND_TIMEOUT=30
export MCP_SHELL=/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin"

# Change to service user
exec chpst -u mcp-terminal:mcp-terminal \
  /var/lib/mcp-terminal/mcp-terminal-server --http --host 127.0.0.1 --port 8080
```

#### 4. Create Log Run Script

Create `/etc/s6/sv/mcp-terminal/log/run`:

```bash
#!/bin/bash
exec chpst -u mcp-terminal:mcp-terminal \
  svlogd -tt /var/log/mcp-terminal
```

#### 5. Set Permissions

```bash
sudo chmod +x /etc/s6/sv/mcp-terminal/run
sudo chmod +x /etc/s6/sv/mcp-terminal/log/run
sudo mkdir -p /var/log/mcp-terminal
sudo chown mcp-terminal:mcp-terminal /var/log/mcp-terminal
```

#### 6. Deploy Binary

```bash
# Copy the binary to the service user's directory
sudo cp mcp-terminal-server /var/lib/mcp-terminal/
sudo chown mcp-terminal:mcp-terminal /var/lib/mcp-terminal/mcp-terminal-server
sudo chmod +x /var/lib/mcp-terminal/mcp-terminal-server
```

#### 7. Enable and Start Service

```bash
# Link service to enable it
sudo ln -sf /etc/s6/sv/mcp-terminal /etc/s6/rc/default/

# Start s6-svscan if not running
sudo s6-svscan /etc/s6/rc/default &

# Or if using an existing s6 installation
sudo s6-svc -u /etc/s6/sv/mcp-terminal
```

#### 8. Service Management

```bash
# Start service
sudo s6-svc -u /etc/s6/sv/mcp-terminal

# Stop service
sudo s6-svc -d /etc/s6/sv/mcp-terminal

# Restart service
sudo s6-svc -t /etc/s6/sv/mcp-terminal

# Check status
s6-svstat /etc/s6/sv/mcp-terminal

# View logs
sudo tail -f /var/log/mcp-terminal/current
```

## systemd Management

### Create Service File

Create `/etc/systemd/system/mcp-terminal.service`:

```ini
[Unit]
Description=MCP Terminal Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=mcp-terminal
Group=mcp-terminal
WorkingDirectory=/var/lib/mcp-terminal
ExecStart=/var/lib/mcp-terminal/mcp-terminal-server --http --host 127.0.0.1 --port 8080
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/mcp-terminal
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

# Resource limits
LimitNOFILE=1024
LimitNPROC=512
MemoryMax=256M
CPUQuota=50%

# Environment
Environment=MCP_COMMAND_TIMEOUT=30
Environment=MCP_SHELL=/bin/bash
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
```

### Service Management

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable mcp-terminal

# Start service
sudo systemctl start mcp-terminal

# Check status
sudo systemctl status mcp-terminal

# View logs
sudo journalctl -u mcp-terminal -f

# Stop service
sudo systemctl stop mcp-terminal

# Restart service
sudo systemctl restart mcp-terminal
```

## Docker Deployment

### Dockerfile

```dockerfile
FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY . .
RUN go build -o mcp-terminal-server

FROM alpine:latest

# Create non-root user
RUN addgroup -g 1001 -S mcp && \
    adduser -u 1001 -S mcp -G mcp

# Install required packages
RUN apk --no-cache add bash curl

# Create necessary directories
RUN mkdir -p /home/mcp/workspace && \
    chown -R mcp:mcp /home/mcp

# Copy binary
COPY --from=builder /app/mcp-terminal-server /usr/local/bin/mcp-terminal-server
RUN chmod +x /usr/local/bin/mcp-terminal-server

# Switch to non-root user
USER mcp
WORKDIR /home/mcp

# Set environment variables
ENV MCP_COMMAND_TIMEOUT=30
ENV MCP_SHELL=/bin/bash

EXPOSE 8080

CMD ["mcp-terminal-server", "--http", "--host", "0.0.0.0", "--port", "8080"]
```

### Docker Compose

```yaml
version: '3.8'

services:
  mcp-terminal:
    build: .
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - MCP_COMMAND_TIMEOUT=30
      - MCP_SHELL=/bin/bash
    volumes:
      - mcp_workspace:/home/mcp/workspace
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=100m
    user: "1001:1001"

volumes:
  mcp_workspace:
```

## Supervisor Process Management

### Configuration

Create `/etc/supervisor/conf.d/mcp-terminal.conf`:

```ini
[program:mcp-terminal]
command=/var/lib/mcp-terminal/mcp-terminal-server --http --host 127.0.0.1 --port 8080
directory=/var/lib/mcp-terminal
user=mcp-terminal
group=mcp-terminal
autostart=true
autorestart=true
startretries=3
stderr_logfile=/var/log/supervisor/mcp-terminal.err.log
stdout_logfile=/var/log/supervisor/mcp-terminal.out.log
environment=MCP_COMMAND_TIMEOUT=30,MCP_SHELL=/bin/bash,PATH="/usr/local/bin:/usr/bin:/bin"

# Resource limits
umask=022
priority=999
```

### Management Commands

```bash
# Reload configuration
sudo supervisorctl reread
sudo supervisorctl update

# Start service
sudo supervisorctl start mcp-terminal

# Stop service
sudo supervisorctl stop mcp-terminal

# Restart service
sudo supervisorctl restart mcp-terminal

# Check status
sudo supervisorctl status mcp-terminal

# View logs
sudo tail -f /var/log/supervisor/mcp-terminal.out.log
```

## Security Hardening

### File Permissions

```bash
# Ensure binary is not writable by others
chmod 755 /var/lib/mcp-terminal/mcp-terminal-server
chown mcp-terminal:mcp-terminal /var/lib/mcp-terminal/mcp-terminal-server

# Restrict access to user directory
chmod 750 /var/lib/mcp-terminal
chown mcp-terminal:mcp-terminal /var/lib/mcp-terminal
```

### Network Security

```bash
# Bind only to localhost (recommended)
--host 127.0.0.1

# Use firewall to restrict access
sudo ufw allow from 127.0.0.1 to any port 8080
sudo ufw deny 8080
```

### Resource Limits

Create `/etc/security/limits.d/mcp-terminal.conf`:

```
mcp-terminal soft nproc 100
mcp-terminal hard nproc 200
mcp-terminal soft nofile 1024
mcp-terminal hard nofile 2048
mcp-terminal soft fsize 1048576
mcp-terminal hard fsize 2097152
mcp-terminal soft cpu 60
mcp-terminal hard cpu 120
```

### AppArmor Profile (Ubuntu/Debian)

Create `/etc/apparmor.d/mcp-terminal`:

```
#include <tunables/global>

/var/lib/mcp-terminal/mcp-terminal-server {
  #include <abstractions/base>
  #include <abstractions/bash>

  # Binary permissions
  /var/lib/mcp-terminal/mcp-terminal-server mr,

  # Network access
  network inet stream,
  network inet6 stream,

  # File access
  /var/lib/mcp-terminal/ r,
  /var/lib/mcp-terminal/** rw,
  /tmp/ r,
  /tmp/** rw,

  # System access (restricted)
  /bin/bash ix,
  /usr/bin/** ix,
  /bin/** ix,

  # Deny dangerous operations
  deny /etc/passwd r,
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** rw,
  deny /home/*/** w,
  deny capability sys_admin,
  deny capability sys_module,

  # Logging
  /var/log/mcp-terminal/** rw,
}
```

Enable the profile:
```bash
sudo apparmor_parser -r /etc/apparmor.d/mcp-terminal
```

## Monitoring and Logging

### Health Checks

```bash
#!/bin/bash
# health-check.sh

# Check if service is running
if ! pgrep -f "mcp-terminal-server" > /dev/null; then
    echo "ERROR: MCP Terminal Server is not running"
    exit 1
fi

# Check if HTTP endpoint responds
if ! curl -s http://127.0.0.1:8080/mcp >/dev/null; then
    echo "ERROR: MCP Terminal Server is not responding"
    exit 1
fi

echo "OK: MCP Terminal Server is healthy"
exit 0
```

### Log Rotation

Create `/etc/logrotate.d/mcp-terminal`:

```
/var/log/mcp-terminal/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    su mcp-terminal mcp-terminal
}
```

## Troubleshooting

### Common Issues

**1. Permission Denied**
```bash
# Check user permissions
sudo -u mcp-terminal ls -la /var/lib/mcp-terminal/
sudo -u mcp-terminal /var/lib/mcp-terminal/mcp-terminal-server --help
```

**2. Port Already in Use**
```bash
# Check what's using the port
sudo netstat -tlnp | grep :8080
sudo ss -tlnp | grep :8080
```

**3. Service Won't Start**
```bash
# Check system logs
sudo journalctl -u mcp-terminal -n 50
sudo tail -f /var/log/mcp-terminal/current
```

**4. Command Execution Fails**
```bash
# Test shell access
sudo -u mcp-terminal bash -c "whoami"
sudo -u mcp-terminal bash -c "echo \$PATH"
```

### Debug Mode

Enable verbose logging by modifying the service configuration to include debug flags:

```bash
# Add to run script or service file
--debug --verbose
```

## Security Benefits Summary

Running with non-root permissions and process management provides:

1. **Isolation**: Commands cannot escape the user's permission boundary
2. **Auditability**: All actions are logged and attributable to the service user
3. **Recoverability**: Service automatically restarts on failure
4. **Resource Control**: CPU, memory, and file limits prevent resource exhaustion
5. **Network Security**: Can be bound to localhost only
6. **File System Protection**: Cannot modify system files or other users' data
7. **Process Supervision**: Automatic restart and health monitoring
8. **Compliance**: Meets security requirements for enterprise environments

This setup ensures the MCP Terminal Server operates safely in production environments while providing the necessary functionality for AI-powered terminal operations.