#!/bin/sh
set -e

SFTP_USER="${SFTP_USER:-backupuser}"
SFTP_PASSWORD="${SFTP_PASSWORD:-changeme}"

# Create user with hashed password (more reliable than chpasswd on Alpine)
if ! id "$SFTP_USER" >/dev/null 2>&1; then
  HASHED=$(echo "$SFTP_PASSWORD" | openssl passwd -6 -stdin)
  adduser -D -h /uploads -s /sbin/nologin -p "$HASHED" "$SFTP_USER"
else
  # Update password if user already exists
  HASHED=$(echo "$SFTP_PASSWORD" | openssl passwd -6 -stdin)
  usermod -p "$HASHED" "$SFTP_USER"
fi

# Fix chroot permissions (must be owned by root, not writable by others)
chown root:root /uploads
chmod 755 /uploads
mkdir -p /uploads/incoming
chown "$SFTP_USER":"$SFTP_USER" /uploads/incoming
chmod 755 /uploads/incoming

# Append per-user SFTP jail to sshd_config
cat >> /etc/ssh/sshd_config <<EOF

Match User ${SFTP_USER}
    ChrootDirectory /uploads
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

# Generate host keys if missing
ssh-keygen -A

# Log effective config for debugging
echo "[entrypoint] sshd_config:"
cat /etc/ssh/sshd_config

# Start file watcher in background
node /app/watcher.js &

# Start SSH daemon in foreground
exec /usr/sbin/sshd -D -e
