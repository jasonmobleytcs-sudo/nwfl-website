#!/bin/sh
set -e

# Create backup user with password from env
SFTP_USER="${SFTP_USER:-backupuser}"
SFTP_PASSWORD="${SFTP_PASSWORD:-changeme}"

# Create user if not exists
if ! id "$SFTP_USER" >/dev/null 2>&1; then
  adduser -D -h /uploads -s /sbin/nologin "$SFTP_USER"
fi
echo "${SFTP_USER}:${SFTP_PASSWORD}" | chpasswd

# Fix permissions
chown root:root /uploads
chmod 755 /uploads
mkdir -p /uploads/incoming
chown "$SFTP_USER":"$SFTP_USER" /uploads/incoming
chmod 755 /uploads/incoming

# Configure SFTP jail for this user
cat >> /etc/ssh/sshd_config <<EOF

Match User ${SFTP_USER}
    ChrootDirectory /uploads
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

# Generate host keys if missing
ssh-keygen -A

# Start file watcher in background
node /app/watcher.js &

# Start SSH daemon in foreground
exec /usr/sbin/sshd -D -e
