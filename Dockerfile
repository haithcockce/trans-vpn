FROM ubuntu:latest

LABEL maintainer "haithcockce@gmail.com"

EXPOSE 9091/tcp 9091/udp 51413/tcp 51413/udp

# We copy just the requirements.txt first to leverage Docker cache
WORKDIR /torrent

# App prep via installing necessary packages. Also openvpn is janky
RUN apt update -y && apt upgrade -y && \
    apt install -y openvpn transmission-daemon make iputils* procps openresolv

# Add appropriate configs and custom scripts
ADD settings.json /root/.config/transmission-daemon/
# Clean up

ENTRYPOINT [ "bash" ]
#CMD [ "chmod +x ha-transmission.sh" ]
#CMD [ "openvpn --config AzireVPN-se.ovpn --daemon --log /torrent/logs/openvpn.log" ]
#CMD [ "openvpn --config AzireVPN-se.ovpn " ]
CMD [ "/torrent/ha-transmission.sh" ]
