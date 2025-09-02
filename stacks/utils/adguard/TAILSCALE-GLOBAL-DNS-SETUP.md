# 🎯 Tailscale Global DNS Configuration Guide

## Current Status: READY FOR SETUP ✅

Your AdGuard Home is running and accessible via Tailscale IP: **100.66.29.76**

## 🚀 Configure Tailscale Global DNS

### Step 1: Access Tailscale Admin Console
1. Go to: **https://login.tailscale.com/admin/dns**
2. Sign in to your Tailscale account

### Step 2: Configure Global Nameserver
1. In the **DNS** section, look for **"Global nameservers"**
2. Click **"Add nameserver"**
3. Enter: **`100.66.29.76`** (your AdGuard server's Tailscale IP)
4. Click **"Save"**

### Step 3: Enable DNS Override (CRITICAL)
1. Check the box for **"Override local DNS"** ✅
2. Keep **"MagicDNS"** enabled ✅
3. Save the configuration

## 🧠 How This Works

**Perfect DNS Flow:**
```
Tailnet Device → MagicDNS (100.100.100.100) → AdGuard (100.66.29.76) → Filtered Results
```

**What You Get:**
- ✅ **MagicDNS**: All `.ts.net` domains still work perfectly
- ✅ **AdGuard Filtering**: Roblox and ads blocked on ALL Tailnet devices  
- ✅ **Global Coverage**: Works on any network (home, mobile, public Wi-Fi)
- ✅ **Encrypted DNS**: All queries secure through Tailscale tunnel

## 🧪 Test After Configuration

Once you've set up Global DNS, test from any Tailnet device:

```bash
# Should work - MagicDNS preserved
nslookup big-chungus.burro-salmon.ts.net

# Should be blocked - Roblox filtering active
nslookup roblox.com
nslookup rbxcdn.com

# Should work - normal websites
nslookup google.com
```

## 💡 Best of Both Worlds

**Router DNS (192.168.1.12)**:
- Covers all home network devices
- Fast local resolution
- Works for guests and IoT devices

**Tailscale Global DNS (100.66.29.76)**:
- Covers all your personal devices everywhere
- MagicDNS + AdGuard filtering
- Secure encrypted queries

## 🎯 Result

You now have **comprehensive DNS filtering**:
- **At home**: Router routes to AdGuard (192.168.1.12)
- **Away/Mobile**: Tailscale routes to AdGuard (100.66.29.76)
- **MagicDNS**: Still works for all `.ts.net` devices
- **Roblox blocking**: Active everywhere

Perfect dual DNS setup complete! 🎉