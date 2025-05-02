#show (Monitoring)
term len 0\rshow run | sec interface\rshow ip int brief\rshow etherchannel summary\rshow spanning-tree\rshow vlan brief\rshow ip ospf neighbor\rshow ip route\rshow ip bgp sum\r

#2. EtherChannel ports e0/0, e0/1
conf t\rint range e0/0 - 1\rchannel-group 1 mode desirable\rexit\rint po1\rswitchport mode trunk\rexit\r

#5. DHCP 192
conf t\rip dhcp excluded-address 192.168.1.1 192.168.1.10\rip dhcp pool VLAN10\rnetwork 192.168.1.0 255.255.255.0\rdefault-router 192.168.1.1\rdns-server 8.8.8.8\rexit\r

conf t\rip dhcp excluded-address 10.0.0.1 10.0.0.10\rip dhcp pool VLAN10\rnetwork 10.0.0.0 255.255.255.0\rdefault-router 10.0.0.1\rdns-server 8.8.8.8\rexit\r

#4. SNMP
conf t\rsnmp-server community PUBLIC ro\rsnmp-server location EVE\rsnmp-server contact admin@example.com\rexit\r

#5. HTTP server
conf t\rip http server\rip http secure-server\rexit\r

# 6. OSPF
conf t\rrouter ospf 1\rrouter-id 1.1.1.1\rnetwork 10.0.0.0 0.255.255.255 area 0\r

#7. VLAN 10, 20 + STP Priority
conf t\rint tun0\rip address 10.10.10.1 255.255.255.252\rtunnel source 192.168.0.1\rtunnel destination 192.168.0.2\rexit\r

#8. GRE Tunnel + IP
conf t\rrouter bgp 65001\rneighbor 10.1.0.1 remote-as 65001\rnetwork 10.0.0.0 mask 255.255.0.0\r


#10. eBGP over GRE
conf t\rinterface Tunnel0\rip address 10.10.10.1 255.255.255.252\rtunnel source 192.168.0.1\rtunnel destination 192.168.0.2\rexit\rrouter bgp 65001\rneighbor 10.10.10.2 remote-as 65001\rexit\r
#11. eigrp
conf t\rrouter eigrp 1\rrouter-id 1.1.1.1\rno auto-summary\rnetwork 10.0.0.0 0.255.255.255\rpassive-interface \r
#12 rip
conf t\rrouter rip\rversion 2\rnetwork
do wr\rdo show run\r

auto_e0/1-2_po3
conf t\rint range e0/1-2\rswitchport trunk encapsulation dot1Q\rswitchport mode trunk\rchannel-group 3 mode auto\rdescr PAgP auto\rexit\rint port-channel 3\rswitchport trunk encapsulation dot1Q\rswitchport mode trunk\r

desi_e0/1-2_po3
conf t\rint range e0/1-2\rswitchport trunk encapsulation dot1Q\rswitchport mode trunk\rchannel-group 3 mode desirable\rdescr PAgP desirable\rexit\rint port-channel 3\rswitchport trunk encapsulation dot1Q\rswitchport mode trunk\r




# no shutdown all interfaces
conf t\rint range e0/0-3\no shut\rint range e1/0-3\no shut\rint range e2/0-3\no shut\rint range g0/0-3\no shut\rint range g1/0-3\no shut\rint range g2/0-3\no shut\rint fa0/0\rno shut\rint fa0/1\rno shut\rint fa0/2\rno shut\rint fa0/3\rno shut\r