#!/bin/bash

# we want case-insensitive matching
shopt -s nocasematch

QUERY=$(echo "$1" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/ /* /g')

echo "<?xml version=\"1.0\"?>"
echo "<items>"

# exclude lines of include asterisk (An asterisk (*) denotes that a network service is disabled.)
#for networkservice in $(networksetup -listallnetworkservices | grep -v "\*")
networksetup -listallnetworkservices | grep -v "\*" | while read NETWORKSERVICE
do
  if [[ " $NETWORKSERVICE" == *\ $QUERY* ]]; then

    DEVICE=$(networksetup -listallhardwareports | grep -A 2 -E "$NETWORKSERVICE" | grep Device | awk '{print $2}' | sed -e 's/ //g')

    # exclude Bluetooth device
    if [[ ! -z "$DEVICE" ]] && [[ ! "$NETWORKSERVICE" =~ Bluetooth ]]; then

      # guest network interface type
      if [[ "$NETWORKSERVICE" =~ Wi-Fi ]]; then
        IS_WIFI=true
      else
        IS_WIFI=false
      fi

      # query status of network interface ("active" or "inactive" or nothing)
      if [[ $(ifconfig $DEVICE | grep status | awk '{print $2}' | sed -e 's/ //g') != "active" ]]; then
        ACTIVE=false

        TITLE="$NETWORKSERVICE is invalid, goagent proxy setting won't work."
        SUBTITLE="Please turn it on."
      else
        ACTIVE=true

        IPV4=$(networksetup -getinfo "$NETWORKSERVICE" | grep "^IP address" | awk -F: '{print $2}' | sed -e 's/ //g')
        MASK=$(networksetup -getinfo "$NETWORKSERVICE" | grep "^Subnet mask" | awk -F: '{print $2}' | sed -e 's/ //g')


        # Query web proxy enabled on networkservice(Yes or No)
        WEB_PROXY_ENABLED=$(networksetup -getwebproxy "$NETWORKSERVICE" | grep "^Enabled" | awk -F: '{print $2}' | sed -e 's/ //g')

        if [[ "$WEB_PROXY_ENABLED" = "Yes" ]]; then
          PROXY_SERVER=$(networksetup -getwebproxy "$NETWORKSERVICE" | grep "^Server" | awk -F: '{print $2}' | sed -e 's/ //g')
          PROXY_PORT=$(networksetup -getwebproxy "$NETWORKSERVICE" | grep "^Port" | awk -F: '{print $2}' | sed -e 's/ //g')
          WEB_PROXY_INFO="GoAgent Enabled: Yes(${PROXY_SERVER}:${PROXY_PORT})"
          TOGGLE_ACTION="off"
        else
          WEB_PROXY_INFO="GoAgent Enabled: No"
          TOGGLE_ACTION="on"
        fi

        if [[ "$IS_WIFI" == true ]]; then
          CURRENT_NETWORK=$(networksetup -getairportnetwork $DEVICE | awk -F: '{print $2}' | sed -e 's/ //g')
          TITLE="Turn ${TOGGLE_ACTION} GoAgent with ${NETWORKSERVICE}(${CURRENT_NETWORK})"
        else
          TITLE="Turn ${TOGGLE_ACTION} GoAgent with $NETWORKSERVICE"
        fi

        SUBTITLE="IP address: (${IPV4}/${MASK}) ${WEB_PROXY_INFO}"

      fi

      VALID="$($ACTIVE && echo 'yes' || echo 'no')"
      ICON="$($IS_WIFI && echo 'wifi' || echo 'ethernet')_$($ACTIVE && echo 'on' || echo 'off')";

      echo "<item uid=\"$NETWORKSERVICE\" arg=\"${NETWORKSERVICE}:${TOGGLE_ACTION}\" valid=\"$VALID\">"
      echo "<title>$TITLE</title>"
      echo "<subtitle>$SUBTITLE</subtitle>"
      echo "<icon>$ICON.png</icon></item>"
    fi
  fi
done

echo "</items>"
shopt -u nocasematch
