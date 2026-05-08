# Claude / AI prompt templates — олимпиадын өдөр

> Олимпиадын дүрэм AI-г зөвшөөрсөн. Доорх template-уудыг chat-руу copy-paste, `<paste>` хэсэгт өөрийн show output-ыг тавь.

## Алдаа олох / debugging

### IOS / NX-OS алдаа
```
Энэ Cisco config-д X функц ажиллахгүй байна. Show output:
<paste show ip interface brief / show ip ospf neighbor / show vpc гэх мэт>

Шалтгаан + засварыг эхлэх алхамаар тайлбарла. Хэрэв миний config буруу
бол ялгахад зориулсан line-by-line diff гарга.
```

### BGP neighbor stuck Active
```
BGP neighbor 10.0.0.2 нь "Active" state-д наалджээ.

show ip bgp summary:
<paste>

show run | sec router bgp:
<paste>

show ip route 10.0.0.2:
<paste>

Шалтгаан + засварыг өг. update-source, ebgp-multihop, AS, password
mismatch-ийг хянах.
```

### vPC peer-link down
```
NX-OS vPC peer-keepalive up, peer-link down. Топологи:
- N9K-1 ↔ N9K-2 (port-channel 1, peer-link)
- show vpc:
<paste>

show vpc consistency-parameters global:
<paste>

Mismatch-уудыг ялгаж засах конкрет команд гарга.
```

## Syntax conversion

### IOS → NX-OS
```
Энэ IOS config-ыг NX-OS syntax-руу хөрвүүл. feature командуудыг
бүгд багтаа. Деprecated keyword-уудыг хасч, шинэ NX-OS equivalent-руу шилжүүл.

<paste IOS config>
```

### NX-OS → IOS
```
Энэ NX-OS config-ийг IOS XE syntax-руу хөрвүүл. feature командуудыг
ip routing / ip multicast-routing-руу хөрвүүл.

<paste NX-OS config>
```

## Generate config

### iBGP RR + IPv4/IPv6 family
```
AS 65001 дотор iBGP route reflector RR1 (loopback 1.1.1.1) болон
RR client R2 (loopback 2.2.2.2)-руу IPv4 + IPv6 unicast family
activate. update-source loopback0 ашигла. password "olymp".
Config block-ыг гарга.
```

### OSPF Multi-Area + redistribute
```
R1 нь area 0 + area 10 stub-д хамаарна. Connected route-уудыг
OSPF-руу redistribute хийх. metric-type 2, metric 100. Config гарга.
```

### IPSec + GRE tunnel
```
R1 (10.0.1.1) ↔ R2 (10.0.3.2) тарай GRE tunnel + IPSec protect
crypto isakmp policy 10 (3DES, MD5, group 2, PSK "olymp"),
transform-set "TS1" (esp-3des, esp-sha-hmac, mode transport),
crypto ipsec profile, tunnel protection.

Hub side (R1) болон spoke side (R2)-ийн config-ыг гарга.
```

## Verify

### vPC validity check
```
Энэ vPC peer-link config зөв үү?
<paste>

Шалгуурууд:
- vpc peer-link нь port-channel дээр л байх ёстой
- peer-keepalive vrf нь management vrf бөгөөд гарцтай
- system-mac auto-derived
- consistency parameters global ялгахгүй
```

### IPv6 reachability check
```
Энэ R1 config-аас 2001:db8::1 (R3 loopback)-руу хүрэх ёстой
ipv6 route, ipv6 unicast-routing идэвхтэй эсэх, OSPFv3
neighbor бүрэн эсэхийг шалгах команд + хүлээгдэж буй output.
```

## Olympiad task parse

### Даалгаврын skeleton гарга
```
Энэ даалгавар:
<paste task>

Топологи + тавьсан шаардлагыг нэгтгэн config skeleton гарга.
Бүх router бүрд: hostname, interface IP, routing protocol, ACL,
NAT гэх мэт хэсэгт зориулсан bullet жагсаалт + жишээ command block.
```

### Шалгуурыг тайлбарлах
```
Олимпиадын шалгуур:
<paste criteria>

Энэ шалгуурыг хангахад прайс vs cost trade-off, deprecated
keyword байх эсэх, IOS/NX-OS-ийн платформын ялгааг тэмдэглэж өг.
```

## Хэрэглэх workflow

```
1. SecureCRT Button Bar → BACKUP → .cfg татна
2. VS Code → Claude Code panel → даалгавар + .cfg paste
3. Claude хариулсан тус config block-ыг clipboard-руу
4. SecureCRT-руу шууд paste эсвэл Button Bar PUSH (push_config.vbs)
5. show run-аар verify
```

## АНХААР — AI-аар хийхгүй

| Юу | Яагаад |
|---|---|
| Шалгууруудыг өөрөө уншиж AI-руу зөв тайлбарлах | Хязгаарлалт (open standard, prepend хориглох) AI-д хүрэхгүй |
| `show` output-ыг өөрөө уншиж нэгтгэх | AI false hypothesis өгч магадгүй |
| Эцсийн config push хийхээс өмнө 1 удаа дахин уншсан байх | AI deprecated/Cisco-only keyword гаргаж магадгүй |
| Live PSK / production password-ыг chat-руу хуулахгүй | Privacy + олимпиадын дараа сэжиг үлдэх |
