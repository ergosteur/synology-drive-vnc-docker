# Use an appropriate Ubuntu base image
FROM ubuntu:20.04

# Set environment variables to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Update and install required dependencies
RUN apt-get update && apt-get install -y \
    wget \
    software-properties-common \
    locales \
    supervisor \
    dbus-x11 \
    x11vnc \
    xvfb \
    xfce4 \
    xfce4-terminal \
    nautilus \
    libglib2.0-0 \
    libgtk2.0-0 \
    libc6 \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN locale-gen en_US.UTF-8

# Add the Synology Drive Client `.deb` file to the image
COPY synology-drive-client-16102.x86_64.deb /tmp/synology-drive-client.deb

# Install the Synology Drive Client
RUN dpkg -i /tmp/synology-drive-client.deb || apt-get install -f -y

# Clean up
RUN rm -f /tmp/synology-drive-client.deb

# Install noVNC and websockify
RUN apt-get update && apt-get install -y \
    git \
    python3-pip && \
    pip3 install websockify && \
    git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify.git /opt/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Create a user for the VNC session
RUN useradd -m -s /bin/bash vncuser && \
    echo "vncuser:vncpassword" | chpasswd && \
    mkdir -p /home/vncuser/.vnc && \
    chown -R vncuser:vncuser /home/vncuser

# Set up VNC server
RUN echo '#!/bin/bash\n\
x11vnc -forever -usepw -create' > /usr/local/bin/start-vnc && \
    chmod +x /usr/local/bin/start-vnc

# Set up Supervisor to manage services
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose the VNC and noVNC ports
EXPOSE 5900 6080

# Start Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
