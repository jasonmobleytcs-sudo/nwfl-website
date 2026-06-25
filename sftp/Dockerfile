FROM node:22-alpine

# Install OpenSSH
RUN apk add --no-cache openssh openssl

# Create uploads directory
RUN mkdir -p /uploads /home/backupuser/.ssh

# Copy app files
WORKDIR /app
COPY package.json ./
RUN npm install
COPY watcher.js ./
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

# Write a clean sshd_config (overwrite default so our settings take effect)
RUN printf '\
Port 22\n\
PermitRootLogin no\n\
PasswordAuthentication yes\n\
ChallengeResponseAuthentication no\n\
UsePAM no\n\
Subsystem sftp internal-sftp\n\
' > /etc/ssh/sshd_config

EXPOSE 22

ENTRYPOINT ["/app/entrypoint.sh"]
