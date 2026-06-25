#!/bin/sh
set -x  # print every command for debugging

SFTP_USER="${SFTP_USER:-backupuser}"
SFTP_PASSWORD="${SFTP_PASSWORD:-changeme}"

echo "[entrypoint] Starting with user=$SFTP_USER"

# Create user if not exists
if ! id "$SFTP_USER" >/dev/null 2>&1; then
  adduser -D -h /uploads -s /sbin/nologin "$SFTP_USER"
fi

# Set password via chpasswd (shadow package)
printf '%s:%s\n' "$SFTP_USER" "$SFTP_PASSWORD" | chpasswd
echo "[entrypoint] Password set"

# Fix chroot permissions
chown root:root /uploads
chmod 755 /uploads
mkdir -p /uploads/incoming
chown "$SFTP_USER":"$SFTP_USER" /uploads/incoming
chmod 755 /uploads/incoming

# Append per-user SFTP jail
cat >> /etc/ssh/sshd_config <<EOF

Match User ${SFTP_USER}
    ChrootDirectory /uploads
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

echo "[entrypoint] sshd_config:"
cat /etc/ssh/sshd_config

# Generate host keys
ssh-keygen -A

echo "[entrypoint] Starting sshd..."

# Start watcher in background
node /app/watcher.js &

# Start sshd in foreground
exec /usr/sbin/sshd -D -e
