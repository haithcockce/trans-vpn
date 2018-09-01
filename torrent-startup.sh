docker run \
	--cap-add=NET_ADMIN \
	--device=/dev/net/tun \
	--sysctl net.ipv6.conf.all.disable_ipv6=0 \
	-p 9091:9091 -p 51413:51413 \
	-v /var/log/torrent:/torrent/logs/ \
	-v /srv/media/downloads/:/torrent/downloads/ \
	-v /srv/docker/torrent/:/torrent/ \
	-itd torrent
