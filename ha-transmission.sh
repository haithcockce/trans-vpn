#!/bin/bash

# Highly Available VPN/Transmission
# 
# Allows for a highly available vpn/transmission client by bouncing transmission
# and the vpn when connectivity fails. 
#
# Start the VPN and wait for the vpn to come up. Once up, start transmission. 
# This allows time for the vpn to start without starting transmission before it
# since --daemon causes openvpn to fork to the background immediately. From 
# there, we create a "heartbeat" of pinging the default gateway of the vpn. If
# we can not ping the default gateway, immediately stop transmission, restart
# the vpn, and restart transmission.
#
# After chatting with the wonderful people at #azirevpn, apparently the issue is
# when connectivity fails, openvpn will prevent any traffic for which it is
# responsible for. After pinging and attempting to come back, openvpn will, on a
# successful restart, create a new device with a new ip address, but the 
# previous routes still exist. The most common outcome was we could not connect
# to anything because the route table with the old entries did not get flushed
# did not include the new gateway. This script works to ensure the entire device
# is torn down, routes and all, rather than let openvpn attempt to soft reset it 
# and works around the issue of the revious routes being still there. 

#set -o functrace  # in case of debugging, break glass (uncomment)

############
## MACROS ##
############

OPENVPN_CONFIG=AzireVPN-se.ovpn
SLEEP_SHORT=2                       # time to wait for short periods
SLEEP_LONG=30                       # time to wait for long periods

ACTIVITY_LOG=/torrent/logs/activity.log  # log for timing of specific actions
OPENVPN_LOG=/torrent/logs/openvpn.log    # log for openvpn
TRANS_LOG=/torrent/logs/tranmission.log  # log for tranmission



########################
## STARTUP OPERATIONS ##
########################

# Reset the log file and log the vpn is starting. After the vpn is kicked off, 
# wait for it to come up completely, logging the wait and waiting 2 seconds
# between checks. Once up, designate the use of the VPN's DNS servers instead 
# of whatever NM comes up with. Then start transmission. From there, go into
# heartbeat loop. 

# Reset the activity log and indicate VPN is starting
rm $ACTIVITY_LOG
echo 'STARTING VPN...' >> $ACTIVITY_LOG
date >> $ACTIVITY_LOG
echo 'STARTING' >> $MESSAGES_LOG
date >> $MESSAGES_LOG

# Start the vpn
openvpn --config $OPENVPN_CONFIG --daemon --log $OPENVPN_LOG

# Wait for VPN come up, logging the wait and waiting SLEEP_SHORT between checks
until [[ $(ip tuntap | wc -l) > 0 ]]; do
    echo 'VPN IS CONNECTING...'
    echo 'VPN IS CONNECTING...' >> $ACTIVITY_LOG
    date >> $ACTIVITY_LOG
    sleep $SLEEP_SHORT
done

# The vpn has its own DNS servers, so let's use those. 
#cp /root/resolv.conf.BAK /etc/resolv.conf

# Start transmission
transmission-daemon --logfile "/torrent/logs/transmission-daemon.log" &
ln -s -d /root/.config/transmission-daemon/ /torrent/transmission-daemon  # why, fedora, why? 

################################
## HEARTBEAT/HA FUNCTIONALITY ##
################################

# Grab the default gateway's IP address to try reaching it via ping. From there,
# loop forever. In the loop, attempt pinging the default gateway. On success,
# wait 30 seconds and attempt reaching it again. On any ping failure, IE failure
# to reach the default gateway, assume network connectivity is down altogether. 
# Here, kill transmission and the vpn. Wait for the vpn to go down before doing
# anything else. Once down, restart the vpn, and wait for it to come back up. 
# Once up, grab the new default gateway and start transmission. Then jump back
# to the top of the loop. 

# Grab the default gateway to ping it. This will be the heartbeat target
DEFAULT_ROUTE=$(ip route show default dev tun0 | awk '{if($1 ~ /.*0.0.0.*/) {print $3}}' | uniq)

# Begin heartbeat loop
while true; do

    # If we can reach the gw, then...
    ping -c 1 $DEFAULT_ROUTE &> /dev/null
    if [[ $? == 0 ]]; then

        # log success, wait and while, and try again
        echo 'Check succeeded. Waiting...' >> $ACTIVITY_LOG
        echo date >> $ACTIVITY_LOG
        sleep $SLEEP_LONG
        continue
    fi

    # Otherwise, bounce vpn and transmission. 
    # log failure
    echo 'CHECK FAILED. BOUNCING VPN.' >> $ACTIVITY_LOG
    date >> $ACTIVITY_LOG
    echo 'RESTARTING' >> $MESSAGES_LOG
    echo date >> $MESSAGES_LOG
    
    # Grab transmission and openvpn's PIDs to kill them and kill them
    TRANSMISSION_PID=$(ps aux | grep 'transmission-daemon' | grep -v grep | awk '{print $2}')
    OPENVPN_PID=$(ps aux | grep 'openvpn' | grep -v grep | awk '{print $2}')
    kill -sigterm $TRANSMISSION_PID
    kill -sigterm $OPENVPN_PID

    # Wait for the vpn to go completely down. Killing the vpn is not immediate
    # and without waiting, we can have a race condition where we attempt to
    # start another openvpn instance while the previous instance is going down.
    # Openvpn does not succeed if it detects a current tun0 device, so you can 
    # end up with no tun0 devices.
    until [[ $(ip tuntap | wc -l) == 0 ]]; do
        echo 'VPN IS GOING DOWN'
        echo 'VPN IS GOING DOWN' >> $ACTIVITY_LOG
        echo date >> $ACTIVITY_LOG
        sleep $SLEEP_SHORT
    done

    # TODO The code from here out is logically a duplicate of the code above.
    #      Why not refactor to have it occur once? 

    # Restart the vpn and wait for it to come back up before starting transmission
    openvpn --config $OPENVPN_CONFIG --daemon --log $OPENVPN_LOG

    until [[ $(ip tuntap | wc -l) > 0 ]]; do
        echo 'VPN IS COMING BACK'
        echo 'VPN IS COMING BACK' >> $ACTIVITY_LOG
        echo date >> $ACTIVITY_LOG
        sleep $SLEEP_SHORT
    done

    # Log the vpn up success
    echo 'VPN IS BACK UP!'
    echo 'VPN IS BACK UP!' >> $ACTIVITY_LOG
    echo date >> $ACTIVITY_LOG

    # Grab the new vpn, start transmission
    DEFAULT_ROUTE=$(ip route show default dev tun0 | awk '{if($1 ~ /.*0.0.0.*/) {print $3}}' | uniq)
    transmission-daemon --logfile "/torrent/logs/transmission-daemon.log" &


done

