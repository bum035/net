#show (Monitoring)
term len 0\nshow run | sec interface\nshow ip int brief\nshow etherchannel summary\nshow spanning-tree\nshow vlan brief\nshow ip ospf neighbor\nshow ip route\nshow ip bgp sum\n

#2. EtherChannel ports e0/0, e0/1
conf t\nint range e0/0 - 1\nchannel-group 1 mode active\nexit\nint po1\nswitchport mode trunk\nexit\n

#5. DHCP 192
conf t\nip dhcp excluded-address 192.168.1.1 192.168.1.10\nip dhcp pool VLAN10\nnetwork 192.168.1.0 255.255.255.0\ndefault-router 192.168.1.1\ndns-server 8.8.8.8\nexit\n

conf t\nip dhcp excluded-address 10.0.0.1 10.0.0.10\nip dhcp pool VLAN10\nnetwork 10.0.0.0 255.255.255.0\ndefault-router 10.0.0.1\ndns-server 8.8.8.8\nexit\n

#4. SNMP
conf t\nsnmp-server community PUBLIC ro\nsnmp-server location EVE\nsnmp-server contact admin@example.com\nexit\n

#5. HTTP server
conf t\nip http server\nip http secure-server\nexit\n

# 6. OSPF
conf t\nrouter ospf 1\nnetwork 10.0.0.0 0.255.255.255 area 0\nexit\n

#7. VLAN 10, 20 + STP Priority
conf t\nint tun0\nip address 10.10.10.1 255.255.255.252\ntunnel source 192.168.0.1\ntunnel destination 192.168.0.2\nexit\n

#8. GRE Tunnel + IP
conf t\nrouter bgp 65001\nneighbor 1.1.1.2 remote-as 65002\nnetwork 10.0.0.0 mask 255.255.255.0\nexit\n

#9. eBGP 
conf t\nrouter bgp 65001\nneighbor 1.1.1.2 remote-as 65002\nnetwork 10.0.0.0 mask 255.255.255.0\nexit\n

#10. eBGP over GRE
conf t\ninterface Tunnel0\nip address 10.10.10.1 255.255.255.252\ntunnel source 192.168.0.1\ntunnel destination 192.168.0.2\nexit\nrouter bgp 65001\nneighbor 10.10.10.2 remote-as 65002\nexit\n


do wr\ndo show run\n
