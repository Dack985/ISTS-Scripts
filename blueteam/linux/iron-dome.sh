#!/bin/bash

# Make sure the script is only run with root privilege
if [ $EUID -ne 0 ]; then
  echo "You must run this with root privileges."
  exit 2
fi


scoring_engine_ip() {
  echo "Please enter the IP address of the scoring engine."
  read -r ip
  if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
#    IFS='.' read -r -a octets <<< "$ip"
#    for octet in "${octets[@]}"; do
#      if [ "$octect" -lt 0 ] || [ "$octet" -gt 255 ]; then
#        echo "Invalid IP: each octet must be between 0 and 255."
#	return 1
#      fi
#    done
    scoring="$ip"
    echo "Scoring-engine IP: $scoring"
  else
    echo "Invalid IP format. The input IP must be in the format: X.X.X.X"
    return 1
  fi
}

install_packages () {
  #if dpkg -l | grep -q "^ii  iptables-persistent "; then
  if ! command -v iptables-save &> /dev/null; then
    echo "You don't have iptables-persistent. Installing..."
    apt install -y iptables-persistent
  else
    echo "Hey, iptables-persistent is installed--as you were!"
  fi
}

iptables_ruleset () {
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
  iptables -D INPUT 1
  iptables -D OUTPUT 1
}

flush_iptables () {
  iptables -F
}

save_config () {
  sh -c "iptables-save > /etc/iptables/rules.v4"
}


# Call the function to enter scoring IP
while true; do
  scoring_engine_ip
  if [ -n "$scoring" ]; then
    break
  fi
done

# Menu selection
echo -ne "SETUP OPTIONS: \n1) Check For/Install Packages\n2) Apply Ruleset to Running Config\n3) Safe Setup\n4) Full Setup\n5) Un-Bork the Box"
read -r choice

case $choice in
  1) install_packages ;;
  2) iptables_ruleset ;;
  3) install_packages; iptables_ruleset; save_config ;;
  4) install_packages; iptables_ruleset; remove_training_wheels; save_config ;;
  5) iptables_flush; save_config ;;
  *) echo "Please choose an option next time." ;;
esac
