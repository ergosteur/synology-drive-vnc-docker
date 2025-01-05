# Base image
FROM ubuntu:20.04

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Default build arg variables for user and VNC passwords
ARG BUILD_USER=vncuser
ARG BUILD_PASS=Strangely8-Yearly-Clubbed
ARG BUILD_VNCPASS=Throwing3-Gooey-Postcard

# Environment variables for user and VNC passwords
ENV USERNAME=${BUILD_USER}
ENV PASSWORD=${BUILD_PASS}
ENV VNC_PASSWORD=${BUILD_VNCPASS}

# Default `.deb` filename (can be overridden)
ENV DEB_FILE=synology-drive-client-16102.x86_64.deb

# Install dependencies and setup VNC desktop
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

# Add and install Synology Drive Client
COPY ${DEB_FILE} /tmp/synology-drive-client.deb
RUN dpkg -i /tmp/synology-drive-client.deb || apt-get install -f -y
RUN rm -f /tmp/synology-drive-client.deb

# Install noVNC and websockify
RUN apt-get update && apt-get install -y \
    git \
    python3-pip && \
    pip3 install websockify && \
    git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify.git /opt/websockify && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Create user and configure password
RUN useradd -m -s /bin/bash $USERNAME && \
    echo "$USERNAME:$PASSWORD" | chpasswd && \
    mkdir -p /home/$USERNAME/.vnc && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME

# Create a default sync directory - mount this as a volume
RUN mkdir -p /data && \
    chown -R $USERNAME:$USERNAME /data

# Configure VNC server
RUN echo "#!/bin/bash\n\
x11vnc -forever -rfbauth /home/$USERNAME/.vnc/passwd -create" > /usr/local/bin/start-vnc && \
    chmod +x /usr/local/bin/start-vnc

# Add script to set VNC password
RUN echo "$VNC_PASSWORD" | x11vnc -storepasswd - /home/$USERNAME/.vnc/passwd && \
    chmod 600 /home/$USERNAME/.vnc/passwd && \
    chown $USERNAME:$USERNAME /home/$USERNAME/.vnc/passwd

# Set up Supervisor to manage services
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose VNC and noVNC ports
EXPOSE 5900 6080

# Start Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]