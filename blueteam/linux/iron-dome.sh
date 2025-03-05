#!/bin/bash

# Insert check to make sure that the script is only run with root privilege


install_packages () {
  apt install iptables-persistent -y
}

iptables_ruleset () {
  # Create temporary allow any-any to prevent lockouts
  iptables -A INPUT -j ACCEPT
  iptables -A OUTPUT -j ACCEPT
  # Chain the default chain rules to deny any-any
  iptables -P INPUT -j DROP
  #iptables -P FORWARD -j DROP
  iptables -P OUTPUT -j DROP
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
}

save_config () {
  sh -c "iptables-save > /etc/iptables/rules.v4"
}
