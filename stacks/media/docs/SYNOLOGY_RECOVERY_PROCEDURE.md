# 🚨 EMERGENCY: Synology NAS Recovery Procedure

## Critical Situation
You've lost all access to your Synology NAS after modifying system files and running rebuild commands.

## ⚡ IMMEDIATE ACTION PLAN

### Step 1: Physical Mode 1 Reset (5 minutes)
**This is your SAFEST first option - preserves ALL data**

1. **Locate the reset button** on your Synology NAS (usually on back panel)
2. **While NAS is running**, press and hold reset button
3. **Hold for exactly 4 seconds**
4. **Release when you hear ONE beep**
5. **Wait 2-3 minutes** for system to apply changes

**Result**: Admin account enabled with blank password, all data preserved

### Step 2: Access Restored DSM (2 minutes)
1. Open browser to: `http://[NAS-IP]:5000` or `http://[NAS-NAME]:5000`
2. Login with:
   - Username: `admin`
   - Password: *(leave blank)*
3. You'll be prompted to set new admin password immediately

### Step 3: Fix User Accounts (10 minutes)
1. Navigate to: **Control Panel → User & Group**
2. Create new user account `delorenj` with:
   - UID: 1000 (or leave as auto-assigned)
   - Primary group: users
   - Grant administrator privileges
3. Set strong password for the account

### Step 4: Fix NFS Permissions Properly (15 minutes)

#### Option A: Through DSM Interface (Recommended)
1. **Control Panel → Shared Folder**
2. Select your video share
3. Click **Edit → NFS Permissions**
4. Modify or create NFS rule with:
   - Hostname: Your client IP or subnet
   - Privilege: Read/Write
   - Squash: Map all users to admin
   - Enable asynchronous
5. Click **OK** to save

#### Option B: Client-Side Fix (Your Docker Host)
```bash
# Remount with proper UID/GID mapping
sudo umount /mnt/video
sudo mount -t nfs -o rw,uid=1000,gid=1000,vers=3 192.168.1.50:/volume1/video /mnt/video
```

### Step 5: Update fstab for Persistence
```bash
# Edit /etc/fstab on your Docker host
192.168.1.50:/volume1/video /mnt/video nfs rw,uid=1000,gid=1000,vers=3 0 0
```

## 🛟 IF MODE 1 RESET FAILS

### Alternative: Mode 2 Reset (30-60 minutes)
**Still preserves your data but requires DSM reinstallation**

1. Do Mode 1 reset (4 seconds → 1 beep → release)
2. **Immediately** press reset again
3. Hold 4 seconds until **THREE beeps**
4. DSM will reinstall (data volumes preserved)
5. Reconfigure through setup wizard

## ⚠️ CRITICAL WARNINGS

- **NEVER hold reset for 20+ seconds** - this triggers factory reset and DESTROYS all data
- **DO NOT modify /etc/passwd directly** on Synology - always use DSM tools
- **UID 911** is standard for Docker media containers (LinuxServer.io) - don't fight it

## 📞 Emergency Escalation

If both reset modes fail:
1. Try serial console access (115200 8N1)
2. Contact Synology Support with your serial number
3. Professional data recovery may be needed

## Estimated Recovery Time: 15-20 minutes for Mode 1 Reset
## Data Loss Risk: ZERO with Mode 1 or Mode 2 Reset