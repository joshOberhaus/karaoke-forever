# Karaoke Forever Dockerfile
FROM node:18-bookworm

# Install ffmpeg, python3, and build dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-pip \
    build-essential \
    git \
    cron \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Install spleeter via pip (using --break-system-packages for Docker)
RUN pip3 install --no-cache-dir --break-system-packages spleeter

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application files
COPY . .

# Build the application
RUN npm run build

# Create directory for media files
RUN mkdir -p /media

# Expose the default port
EXPOSE 3000

# Set up cron job for daily youtube update, prevent API breaking
RUN echo "0 5 * * * cd /usr/src/app && npm run youtube-update >> /var/log/youtube-update.log 2>&1" | crontab -

# Create startup script
RUN echo '#!/bin/bash\n\
cron\n\
node server/main.js -p 3000' > /usr/src/app/start.sh && \
    chmod +x /usr/src/app/start.sh

CMD ["/usr/src/app/start.sh"]
