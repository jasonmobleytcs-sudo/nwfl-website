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

# SSH config: SFTP-only, no shell
RUN echo "Subsystem sftp internal-sftp" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "Port 22" >> /etc/ssh/sshd_config

EXPOSE 22

ENTRYPOINT ["/app/entrypoint.sh"]
