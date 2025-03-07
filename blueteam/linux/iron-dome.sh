#!/bin/bash

# Make sure the script is only run with root privilege
if [ $EUID -ne 0 ]; then
  echo "You must run this script with root privileges."
  exit 2
fi


scoring_engine_ip() {
  echo "Please enter the IP address of the scoring engine:"
  read -r ip
  if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if [ $((octet)) -lt 0 ] || [ $((octet)) -gt 255 ]; then
	echo "err: Invalid IP. Each octet must be between 0 and 255."
	return 1
      fi
    done
    echo "--> Setting scoring-engine IP..."
    scoring="$ip"
    echo ""
  else
    echo "err: Invalid IP. Must input in the format: X.X.X.X"
    return 1
  fi
}

private_ip_addresses() {
  echo "Please enter the IP addresses of your private devices seperated by spaces (eg 192.168.1.1 192.168.1.2):"
  read -a private_ips

  valid_ips=()
  
  for private_ip in "${private_ips[@]}"; do
    if [[ "$private_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a octets <<< "$private_ip"
    valid=true
    
    for octet in "${octets[@]}"; do
      if [ $((octet)) -lt 0 ] || [ $((octet)) -gt 255 ]; then
	    echo "err: Invalid IP. Each octet must be between 0 and 255."
	    valid=false
        break
      fi
    done
    if [[ "$valid"=="true" ]]; then
      valid_ips+=("$private_ip")
      echo "--> valid private ip detected and added: $private_ip"
    fi
  else
    echo "err: Invalid IP. Must input in the format: X.X.X.X"
    return 1
  fi
done
echo "Valid IPs collected: ${valid_ips[*]}"
forgoten_private_ip
}

forgoten_private_ip() {
    echo "Would you like to add in any ip addresses you may have missed?"
        select yn in "Yes" "No"; do
        case $yn in
        Yes ) private_ip_addresses; break;;
        No ) return;;
    esac
done
}

install_packages () {
  if dpkg -l | grep -q "^ii  iptables-persistent "; then
    echo "--> Nice, iptables-persistent is installed--moving on!"
    sleep 0.4
  else
    echo "--> Missing iptables-persistent package. Installing now..."
    apt install -y iptables-persistent
  fi

#  if ! command -v iptables-save &> /dev/null; then
#    echo "You don't have iptables-persistent. Installing..."
#    apt install -y iptables-persistent
#  else
#    echo "Hey, iptables-persistent is installed--as you were!"
#  fi
}

iptables_ruleset () {
  echo "--> Setting up your firewall now..."
  sleep 1 
  # Create temporary allow any-any to prevent lockouts
  iptables -A INPUT -j ACCEPT
  iptables -A OUTPUT -j ACCEPT
  # Chain the default chain rules to deny any-any
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
  iptables -P OUTPUT DROP
  # Allow loopback interface traffic in/out
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT
  # Keep track of existing connections and allow them both in/out
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  # Allow DNS outbound over both tcp & udp
  iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
  # Allow SSH into and from the box (can modify later to specify certain IPs)
  iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
  # Allow NTP outbound to provide time syncing
  iptables -A OUTPUT -p udp --sport 123 --dport 123 -j ACCEPT
  # Allow the outbound connections over the Internet
  iptables -A OUTPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT
  # Add the scoring-engine IP to whitelist all traffic to and from that device
  iptables -A INPUT -s $scoring -m conntrack --ctstate NEW -j ACCEPT
  iptables -A OUTPUT -d $scoring -m conntrack --ctstate NEW -j ACCEPT
}

remove_training_wheels () {
  echo "--> Removing training wheels..."
  sleep 0.7
  iptables -D INPUT 1
  iptables -D OUTPUT 1
}

iptables_reset () {
  echo "--> Resetting your firewall rules..."
  sleep 0.7
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -F INPUT
  iptables -F FORWARD
  iptables -F OUTPUT
}

save_config () {
  echo "--> Saving configurations..."
  sh -c "iptables-save > /etc/iptables/rules.v4"
}


# Begin main part of script
while true; do
  scoring_engine_ip
  if [ -n "$scoring" ]; then
    break
  fi
done

# ~Documentation~
# 1 - Check for iptables persistent package and install if not found
# 2 - Apply our custom ruleset to the running config
# 3 - Apply the custom ruleset and save it, but do not remove the safety allow any-any
# 4 - Apply the custom ruleset, remove the safety allow any-any, and save the config
# 5 - Set each chain rule to accept all traffic and flush the individual rules
# 6 - Exit the program


#not added in yet as firewall rules/cases havent been added in to quantify using it, will augement firewall rules soon function (private_ip_addresses)
# Menu selection starts 
echo -ne "--FIREWALL CONFIGURATION-- \n1) Check For & Install Packages\n2) Quick Config\n3) Safe Setup\n4) Launch the Iron Dome\n5) Unbork the Box\n6) Exit\n"
read -r choice

case $choice in
  1) install_packages ;;
  2) iptables_ruleset ;;
  3) install_packages; iptables_ruleset; save_config ;;
  4) install_packages; iptables_ruleset; remove_training_wheels; save_config ;;
  5) iptables_reset; save_config ;;
  6) exit ;;
  *) echo "--> Defaulting to exit."; exit ;;
esac
