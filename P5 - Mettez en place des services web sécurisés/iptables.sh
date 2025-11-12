#!/bin/sh

# Vider les tables
iptables -t filter -F
iptables -t filter -X

# Activer le routage IPv4
echo 1 > /proc/sys/net/ipv4/ip_forward

# Configurer le NAT pour le WAN
iptables -t nat -A POSTROUTING -o ens33 -j MASQUERADE

# Autoriser les connexions LAN -> WAN
iptables -A FORWARD -i ens37 -o ens33 -j ACCEPT
iptables -A FORWARD -i ens33 -o ens37 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Autoriser les connexions du LAN
iptables -A INPUT -i ens37 -j ACCEPT

# Maintenir les connexions existantes
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Autoriser boucle locale
iptables -t filter -A INPUT -i lo -j ACCEPT
iptables -t filter -A OUTPUT -o lo -j ACCEPT

# ICMP
iptables -t filter -A INPUT -p icmp -j ACCEPT
iptables -t filter -A OUTPUT -p icmp -j ACCEPT

# SSH
iptables -t filter -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 22 -j ACCEPT

# HTTP(S)
iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT

# DROP tout le reste
iptables -t filter -P INPUT DROP
iptables -t filter -P OUTPUT DROP
iptables -t filter -P FORWARD DROP

