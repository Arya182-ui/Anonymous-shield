# 🆓 FREE VPN SERVER SETUP GUIDE

## Option 1: Cloudflare WARP (Recommended) ⭐

### सबसे अच्छा Free Option - Unlimited Data!

```bash
# Automatically configured in app - no manual setup needed
# App में "Get Free Configs" button दबाएं
```

**Benefits:**
- ✅ Unlimited data
- ✅ Fast speeds  
- ✅ Privacy focused
- ✅ No registration needed
- ✅ Automatic configuration

---

## Option 2: ProtonVPN Free 

### Setup Steps:

1. **ProtonVPN Account बनाएं:**
   ```
   https://protonvpn.com/free-vpn
   ```

2. **WireGuard Config Download करें:**
   - Login करें ProtonVPN dashboard में
   - Downloads section में जाएं  
   - WireGuard config files download करें
   - Free servers: US, JP, NL available

3. **App में Import करें:**
   ```dart
   // Config file content paste करें या QR scan करें
   // App automatically parse कर देगा
   ```

---

## Option 3: Windscribe (10GB/month)

### Setup Steps:

1. **Windscribe Account:**
   ```  
   https://windscribe.com/signup
   ```

2. **Config Generation:**
   - Dashboard → Config Generator
   - Select locations (Free: US, CA, UK, HK, FR, DE, NL, CH, NO)
   - Protocol: WireGuard
   - Download .conf files

3. **Import in App:**
   - File picker से .conf file select करें
   - या QR code scan करें

---

## Option 4: Hide.me (10GB/month)

### Quick Setup:
```
Website: https://hide.me/en/
Free locations: Canada, Netherlands, Germany, UK, US East
WireGuard configs available in member area
```

---

## Option 5: TunnelBear (500MB/month)

### Setup:
```
Website: https://www.tunnelbear.com/
Limited data but good for testing  
WireGuard configs in account settings
```

---

## Manual Configuration Format:

यदि आपके पास WireGuard config है, तो इस format में होना चाहिए:

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY_HERE
Address = 10.2.0.2/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]  
PublicKey = SERVER_PUBLIC_KEY_HERE
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = server.example.com:51820
```

---

## Security Tips 🔒

1. **हमेशा Reputable Providers** use करें
2. **Free VPN Limitations** समझें (data limits, speed limits)
3. **Legal Compliance** - अपने country के laws follow करें
4. **Kill Switch** हमेशा enable रखें
5. **DNS Leak** tests regularly करें

---

## Testing Your Setup 🧪

Configuration add करने के बाद test करें:

```bash
# IP Check websites:
- whatismyipaddress.com
- ipleak.net  
- dnsleaktest.com

# Speed Tests:
- fast.com
- speedtest.net
```

---

## Troubleshooting 🔧

### Common Issues:

1. **Connection Failed:**
   - Check server address/port
   - Verify keys are correct
   - Try different server

2. **Slow Speeds:**
   - Free servers often have limited bandwidth
   - Try different location
   - Check server load

3. **DNS Leaks:**
   - Ensure DNS servers are configured
   - Enable kill switch
   - Use app's leak protection

---

**💡 Pro Tip:** Start with Cloudflare WARP से - यह automatically configure होता है और unlimited है!