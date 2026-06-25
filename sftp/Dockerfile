FROM node:22-alpine

# Install OpenSSH + shadow (provides reliable chpasswd)
RUN apk add --no-cache openssh openssl shadow

# Create uploads directory
RUN mkdir -p /uploads

# Write a clean sshd_config that explicitly allows password auth
RUN printf 'Port 22\nPermitRootLogin no\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\nAuthenticationMethods password keyboard-interactive\nChallengeResponseAuthentication no\nUsePAM no\nPrintMotd no\nSubsystem sftp internal-sftp\n' > /etc/ssh/sshd_config

# Copy app files
WORKDIR /app
COPY package.json ./
RUN npm install
COPY watcher.js ./
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/app/entrypoint.sh"]
