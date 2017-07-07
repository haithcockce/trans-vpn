FROM fedora:latest

LABEL maintainer "haithcockce@gmail.com"

EXPOSE 9091 51413/tcp 51413/udp

# We copy just the requirements.txt first to leverage Docker cache
WORKDIR /torrent

# Add appropriate configs and custom scripts
#ADD AzireVPN-se.ovpn .
#ADD login .
#ADD update-resolv-conf /etc/openvpn/
#ADD ha-transmission.sh .
ADD openresolv-3.9.0 .
ADD settings.json /root/.config/transmission-daemon/

# App prep via installing necessary packages. Also openvpn is janky
RUN dnf update -y && \
    dnf install -y openvpn transmission* xonsh make iputils procps-ng

# Clean up

ENTRYPOINT [ "bash" ]
ADD update-resolv-conf /etc/openvpn/update-resolv-conf
#CMD [ "chmod +x ha-transmission.sh" ]
#CMD [ "openvpn --config AzireVPN-se.ovpn --daemon --log /torrent/logs/openvpn.log" ]
#CMD [ "openvpn --config AzireVPN-se.ovpn " ]
CMD [ "/torrent/ha-transmission.sh" ]
#CMD [ "/torrent/init.sh" ]
