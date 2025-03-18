#!/bin/bash

if [ $EUID -ne 0 ]; then
  echo "You must run this script with root privileges."
  exit 2
fi

this_OS=0
box_type=0

echo "Checking box for operating system type..."
OS_name=$(hostnamectl | grep "Operating System: " | awk '{ print $3 }')
if [ "$OS_name" == "Rocky" ] || [ "$OS_name" == "Fedora" ] || [ "$OS_name" == "CentOS" ] || [ "$OS_name" == "Red" ] || [ "$OS_name"  == "Oracle" ]; then
  this_OS=1
fi
echo "--> Operating system recorded!"
sleep 0.3

echo "Installing required packages... bozo... I am the firewall god!!!"
if [ "$this_OS" -eq 1 ]; then
  systemctl stop firewalld
  systemctl disable firewalld
  sleep 0.2
  echo "--> Installing all iptables services and utils..."
  dnf install -y iptables-services ; dnf install -y iptables-util
else
  if dpkg -l | grep -q "^ii  iptables-persistent "; then
    echo "--> Nice, iptables-persistent is installed--moving on!"
    sleep 0.4
  else
    echo "--> Missing iptables-persistent package. Installing now..."
    apt install -y iptables-persistent
  fi
fi


set_box_type () {
  echo "Does this box need to forward traffic? [y/n]: "
  select yn in "Yes" "No"; do
    case $yn in
      "Yes") box_type=1; break;;
      "No") box_type=0; break;;
      *) echo "Please answer yes or no.";;
    esac
  done
}

scoring_engine_ip () {
  echo "Please enter the IP address or the subnet range of the scoring engine (eg. 172.16.0.10 or 172.16.0.0/16):"
  read -r input_scoring_ip

  if [[ "$input_scoring_ip" =~ ^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(/(3[0-2]|[12]?[0-9]))?$ ]]; then
    scoring_ip="$input_scoring_ip"
    echo "--> Setting scoring-engine IP to: $scoring_ip"
    echo ""
  else
    echo "### Invalid IP. Must input in the format: X.X.X.X or X.X.X.X/N within the proper IP address ranges"
    return 1
  fi
}

private_ip_addresses () {
  echo "Please enter the IP addresses of your private devices separated by spaces (eg. 192.168.1.1 192.168.1.2):"
  read -a private_ips

  valid_ips=()

  for private_ip in "${private_ips[@]}"; do
    if [[ "$private_ip" =~ ^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$ ]]; then
      valid_ips+=("$private_ip")
      echo "--> Valid private IP detected and added: $private_ip"
    else
      echo "### Invalid IP. Must input in the format: X.X.X.X or ensure IP address is correct"
    fi
  done

  if [ ${#valid_ips[@]} -gt 0 ]; then
    echo "Valid IPs collected: ${valid_ips[*]}"
  else
    echo "### No valid IPs were entered."
  fi
  
  forgotten_private_ip
}

forgotten_private_ip () {
  echo "Would you like to add any IP addresses you may have missed?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes) private_ip_addresses; break;;
      No) return;;
      *) echo "Please answer yes or no.";;
    esac
  done
}

iptables_ruleset () {
  echo "--> Setting up your firewall now..."
  sleep 1 
  # Create temporary allow any-any to prevent lockouts
  iptables -A INPUT -j ACCEPT
  iptables -A OUTPUT -j ACCEPT

  # Change the default chain rules to deny any-any
  iptables -P INPUT DROP
  if [ "$box_type" -eq 0 ]; then
    iptables -P FORWARD DROP
  fi
  iptables -P OUTPUT DROP

  # Allow loopback interface traffic in/out - for self-testing purposes
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT

  # Keep track of existing connections and allow them both in/out
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

  # Commented out this goofy ahh NTP rule bc we didn't use it at CCDC and it didn't affect us
  # iptables -A OUTPUT -p udp --sport 123 --dport 123 -j ACCEPT

  # Allow the outbound connections over the Internet
  iptables -A OUTPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

  # Allow DNS outbound over both udp & tcp - for using apt installs and the like
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

  # Whitelist scoring-engine IP
  if [ -n "$scoring_ip" ]; then
    iptables -A INPUT -s $scoring_ip -m conntrack --ctstate NEW -j ACCEPT
    iptables -A OUTPUT -d $scoring_ip -m conntrack --ctstate NEW -j ACCEPT
  fi

  # Whitelist IPs of internal machines
  if [ ${#valid_ips[@]} -gt 0 ]; then
    for internal_ip in "${valid_ips[@]}"; do
      iptables -A INPUT -s $internal_ip -m conntrack --ctstate NEW -j ACCEPT
      iptables -A OUTPUT -d $internal_ip -m conntrack --ctstate NEW -j ACCEPT
    done
  fi
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

  if [ "$this_OS" -eq 1 ]; then
    sh -c "iptables-save > /etc/sysconfig/iptables"
  else	  
    sh -c "iptables-save > /etc/iptables/rules.v4"
  fi
}


# Function below not working cause I'm a goober
# set_box_type

echo "Would you like to set a scoring-engine IP?"
read -r option
if [ "$option" == "yes" ] || [ "$option" == "y" ]; then
  while true; do
    scoring_engine_ip
    if [ -n "$scoring_ip" ]; then
      break
    fi
  done
fi

# ~Documentation~
# 1 - Apply our custom ruleset to the running config
# 2 - Apply the custom ruleset and save it, but do not remove the safety allow any-any
# 3 - Apply the custom ruleset, remove the safety allow any-any, and save the config
# 4 - Set each chain rule to accept all traffic and flush the individual rules
# 5 - Exit the program

# not added in yet as firewall rules/cases havent been added in to quantify using it, will augment firewall rules soon function (private_ip_addresses)

echo -ne "--FIREWALL CONFIGURATION-- \n1) Quick Config\n2) Safe Setup\n3) Launch the IRON DOME\n4) Unbork the Box\n5) Exit\n"
read -r choice

case $choice in
  1) iptables_ruleset;;
  2) iptables_ruleset; save_config;;
  3) iptables_ruleset; remove_training_wheels; save_config;;
  4) iptables_reset; save_config;;
  5) exit;;
  *) echo "--> Defaulting to exit."; exit;;
esac
