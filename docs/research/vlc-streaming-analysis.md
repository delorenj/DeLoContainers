# VLC Video Streaming Research & Analysis

**Research Date:** November 28, 2025
**Focus:** VLC streaming capabilities, Docker deployment, Chromecast compatibility, and alternatives

---

## Executive Summary

VLC Media Player offers HTTP/RTSP streaming capabilities and can function as a basic streaming server, but it has significant limitations for modern self-hosted media streaming needs, particularly regarding Chromecast integration and multi-user scenarios. For a robust, Chromecast-compatible self-hosted streaming solution, alternatives like **Jellyfin** or **Plex** are significantly better choices.

---

## 1. VLC HTTP Streaming Server Capabilities

### Core Features

VLC can stream video content using several protocols:
- **HTTP streaming** - Basic web-based streaming
- **RTSP** (Real-Time Streaming Protocol)
- **RTP** (Real-time Transport Protocol)
- **Multicast streaming**

### Key Capabilities

1. **On-demand streaming** - Stream individual video files to clients
2. **Live streaming** - Can restream live sources
3. **Transcoding** - Convert formats on-the-fly during streaming
4. **Multiple output formats** - Supports various container formats (TS, ASF, FLV, etc.)

### Technical Implementation

**Basic HTTP streaming command:**
```bash
vlc -vvv /path/to/video.mp4 --sout '#standard{access=http,mux=ts,dst=:8080}'
```

**Client access:**
```
http://<server-ip>:8080
```

### Limitations

- **Not designed for multi-user scenarios** - VLC is primarily a media player, not a server
- **No native content library management** - No database or metadata management
- **Limited web interface** - Basic controls only, not a full media browser
- **Single stream focus** - Each stream typically requires a separate VLC instance
- **Firewall complications** - Windows Firewall often blocks connections by default

---

## 2. Setting Up VLC for Multiple Video Files

### Method 1: VideoLAN Manager (VLM)

VLM is VLC's built-in manager for handling multiple streams from one VLC instance.

**Setup Steps:**
1. Enable VLC web interface: `View > Add Interface > Web Interface`
2. Access VLM: `http://localhost:8080/vlm.html`
3. Add broadcast channels with different video sources
4. Configure each channel with unique streaming parameters

**VLM Configuration Example:**
```bash
# Channel 1
new channel1 broadcast enabled
setup channel1 input /path/to/movie1.mp4
setup channel1 output #rtp{mux=ts,dst=239.255.1.1,sap,name="Channel 1"}

# Channel 2
new channel2 broadcast enabled
setup channel2 input /path/to/movie2.mp4
setup channel2 output #rtp{mux=ts,dst=239.255.1.2,sap,name="Channel 2"}
```

### Method 2: Multiple VLC Instances

Run separate VLC instances for each stream on different ports:
```bash
# Stream 1 on port 8080
vlc video1.mp4 --sout '#standard{access=http,mux=ts,dst=:8080}'

# Stream 2 on port 8081
vlc video2.mp4 --sout '#standard{access=http,mux=ts,dst=:8081}'
```

### Challenges with Multiple Videos

- **No automatic playlist/queue system** for on-demand selection
- **Manual configuration required** for each video
- **Resource intensive** - Multiple instances consume significant system resources
- **No user-friendly interface** for video selection

---

## 3. VLC Web Interface for Remote Control

### Overview

VLC includes a basic HTTP-based web interface for remote control, but it's **NOT** a full-featured media browser.

### Setup Process

1. **Enable in VLC:**
   - Navigate to: `Tools > Preferences > Show settings: All`
   - Go to: `Interface > Main Interfaces`
   - Check: `Web` checkbox
   - Under: `Interface > Main Interfaces > Lua`
   - Set password (e.g., "vlcremote")
   - Save and restart VLC

2. **Access Interface:**
   - Default: `http://localhost:8080`
   - Remote: `http://<server-ip>:8080`

### Security Configuration

By default, web interface is **locked to localhost only** (403 Forbidden from other devices).

**To allow remote access:**
- Edit `.hosts` file in VLC's HTTP interface directory
- Add allowed IP addresses or ranges
- For internet access, configure port forwarding on router

### Web Interface Features

**Available Controls:**
- Play/Pause/Stop
- Volume control
- Seek/Fast forward/Rewind
- Next/Previous track
- Playlist management (basic)
- Aspect ratio adjustment
- Full-screen toggle

**NOT Available:**
- Media library browsing
- Metadata display (posters, descriptions, etc.)
- User management
- Content discovery/search
- Mobile-optimized interface

### Third-Party Remote Apps

- **VLC Mobile Remote** - iOS/Android apps
- **Remote Player for VLC™** - Chrome extension
- Various open-source projects on GitHub

---

## 4. Docker Containers for VLC Streaming

### Available Docker Images

#### 1. **galexrt/vlc** (Recommended)
- **Source:** https://github.com/galexrt/container-vlc
- **Images:** Available on Quay.io and GHCR.io

**Pull Command:**
```bash
docker pull quay.io/galexrt/vlc:latest
# OR
docker pull ghcr.io/galexrt/vlc:latest
```

**HTTP Streaming Example:**
```bash
docker run -d \
  -v "$(pwd)":/data \
  -p 8080:8080 \
  quay.io/galexrt/vlc:latest \
  file:///data/your-video.mp4 \
  --sout '#transcode{scodec=none}:http{mux=ffmpeg{mux=flv},dst=:8080/}'
```

**Access stream:** `http://<server-ip>:8080`

#### 2. **lroktu/vlc-server**
- VLC Media Player 3.0.9.2 Vetinari
- Headless (cvlc) version

**Pull Command:**
```bash
docker pull lroktu/vlc-server:latest
```

**Exposed Ports:**
- 8080 (HTTP)
- 8554 (RTSP)
- 554 (RTSP alternative)

**RTSP Streaming Example:**
```bash
docker run -d \
  --name vlc \
  -p 8554:8554 \
  lroktu/vlc-server \
  big_buck_bunny.mp4 \
  --loop \
  :sout=#gather:rtp{sdp=rtsp://:8554/} \
  :network-caching=1500 \
  :sout-all \
  :sout-keep
```

#### 3. **gersilex/cvlc-docker**
- Alpine-based (lightweight)
- Focus on transcoding and streaming

**MJPEG Transcoding Example:**
```bash
docker run -p 10001:8080 \
  gersilex/cvlc \
  rtsp://192.168.1.150/stream \
  --sout '#transcode{vcodec=MJPG,venc=ffmpeg{strict=1}}:standard{access=http{mime=multipart/x-mixed-replace;boundary=--7b3cc56e5f51db803f790dad720ed50a},mux=mpjpeg,dst=:8080/}'
```

### Docker Implementation Considerations

**Critical Requirements:**
1. **Cannot run as root** - VLC refuses to run with root privileges
2. **Use cvlc** - Command-line VLC without GUI (vlc command fails in containers)
3. **Volume mounting** - Videos must be mounted into container
4. **Port exposure** - Must expose streaming ports to host
5. **Network configuration** - Ensure proper network mode for discovery

**Limitations:**
- Still inherits VLC's basic server limitations
- No built-in media management
- Manual configuration for each stream
- Resource intensive for multiple simultaneous streams

---

## 5. Chromecast Compatibility with VLC Streaming

### VLC Native Chromecast Support

**Version Requirements:**
- VLC 3.0+ (Windows/Mac only)
- **NOT available** in headless/server mode
- Requires GUI interface for Chromecast discovery

**Supported Platforms:**
- Chromecast (1st gen, 2nd gen, 3rd gen)
- Chromecast Ultra
- Android TV devices (NVIDIA SHIELD, Sony TVs)
- **Issues reported** with Chromecast with Google TV (namespace errors)

### How It Works

VLC **does NOT** pass through the URL to Chromecast directly. Instead:
1. VLC buffers the stream locally
2. Creates its own web server
3. Serves transcoded content to Chromecast
4. Chromecast fetches from VLC's temporary server

### Supported Formats

**Native Chromecast formats:**
- MP4
- WebM
- MPEG-DASH
- HLS (HTTP Live Streaming)
- Smooth Streaming

**VLC transcoding:**
- VLC can transcode unsupported formats on-the-fly
- Performance depends on CPU power
- May introduce latency

### Known Issues

**Reliability Problems:**
- "Finicky" implementation - works for some users, fails for others
- Format compatibility issues with certain codecs
- Audio plays but no video (common on Windows)
  - **Fix:** Change video output to OpenGL in VLC settings
- Chromecast icon may not appear
  - Causes: Firewall, network issues, incomplete installation
- Requires same network for VLC and Chromecast

**Critical Limitation for Server Use:**
Chromecast casting only works from **VLC GUI**, not from VLC running as a server/daemon. This makes it **unsuitable for headless server deployments** or Docker containers.

### Alternative Approach: DLNA/UPnP

Some users report success using VLC with DLNA, but this requires:
- DLNA-compatible client app on mobile/casting device
- Additional configuration
- Less reliable than native Chromecast protocols

---

## 6. Alternatives to VLC for Self-Hosted Chromecast Streaming

### 1. **Jellyfin** ⭐ HIGHLY RECOMMENDED

**Overview:**
- Free, open-source media server
- Native Chromecast support
- No subscriptions, no ads, no paywalls
- Privacy-focused (no cloud account required)

**Key Features:**
- Full media library with metadata (posters, descriptions, ratings)
- Automatic media scanning and organization
- Hardware transcoding (FREE, unlike Plex)
- Multi-user support with permissions
- Mobile apps (Android/iOS) - FREE
- Web-based interface
- Plugin system for extensions
- 4K streaming support
- Live TV & DVR support

**Chromecast Support:**
- Native casting from web interface
- Casting from mobile apps (Android/iOS)
- Supports multiple Chromecast devices
- Automatic format transcoding

**Deployment:**
```bash
docker run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v /path/to/config:/config \
  -v /path/to/media:/media \
  jellyfin/jellyfin
```

**Pros:**
- ✅ Completely free and open-source
- ✅ No telemetry or cloud dependencies
- ✅ Hardware transcoding included
- ✅ Active development community
- ✅ Easy Docker deployment
- ✅ Excellent Chromecast integration
- ✅ No account/login required for local use

**Cons:**
- ❌ Remote access setup more complex (requires reverse proxy/DDNS)
- ❌ Smaller plugin ecosystem than Plex
- ❌ Interface less polished than Plex
- ❌ Occasional bugs (especially with subtitles on some clients)

---

### 2. **Plex**

**Overview:**
- Most popular proprietary media server
- Freemium model (basic free, Plex Pass for advanced features)
- Extremely polished interface

**Key Features:**
- Comprehensive device support (PlayStation, Xbox, Apple TV, Roku, Chromecast, Fire TV, Smart TVs)
- Automatic metadata fetching
- Easy remote access (no complex setup)
- Mobile sync for offline viewing (Plex Pass)
- Live TV & DVR (Plex Pass)
- Hardware transcoding (Plex Pass required)
- Discover/watch third-party content

**Chromecast Support:**
- Excellent native support
- Casting from all Plex apps
- Reliable and well-tested

**Deployment:**
```bash
docker run -d \
  --name plex \
  -p 32400:32400 \
  -v /path/to/config:/config \
  -v /path/to/media:/media \
  plexinc/pms-docker
```

**Pros:**
- ✅ Most polished interface
- ✅ Widest device support
- ✅ Easy remote access setup
- ✅ Large plugin ecosystem
- ✅ Excellent mobile apps
- ✅ Reliable Chromecast casting

**Cons:**
- ❌ Requires Plex account (cloud-dependent)
- ❌ Hardware transcoding behind paywall ($4.99/month or $119.99 lifetime)
- ❌ Mobile apps cost money on Android/iOS (or need Plex Pass)
- ❌ Privacy concerns (previous data leak)
- ❌ Increasing focus on third-party content/ads
- ❌ Telemetry and analytics

**Plex Pass Costs:**
- Monthly: $4.99
- Yearly: $39.99
- Lifetime: $119.99

---

### 3. **Emby**

**Overview:**
- Middle ground between Jellyfin and Plex
- Partially closed-source (forked from original Emby before Jellyfin)
- Freemium model

**Key Features:**
- Similar to Plex/Jellyfin feature set
- Hardware transcoding (Emby Premiere required)
- Mobile apps (premium required for full access)
- Live TV & DVR support
- Multi-user support

**Chromecast Support:**
- Native support available
- Works from web and mobile apps

**Pros:**
- ✅ More features than free Jellyfin
- ✅ Better support than Jellyfin
- ✅ Good performance

**Cons:**
- ❌ Key features behind paywall (Emby Premiere: $54/year or $119 lifetime)
- ❌ Not fully open-source
- ❌ Smaller community than Plex or Jellyfin
- ❌ Less compelling than Jellyfin (free) or Plex (polish)

---

### 4. **Universal Media Server (UMS)**

**Overview:**
- DLNA/UPnP focused media server
- Completely free and open-source
- Minimal setup required

**Key Features:**
- Automatic transcoding for compatibility
- Supports wide range of formats
- Works with older hardware
- Chromecast compatibility
- No accounts or configuration needed

**Deployment:**
- Standalone applications for Windows/Mac/Linux
- Docker images available

**Pros:**
- ✅ Completely free
- ✅ Very simple setup
- ✅ Great for DLNA devices
- ✅ Automatic transcoding

**Cons:**
- ❌ No web interface for browsing
- ❌ Less user-friendly than Plex/Jellyfin
- ❌ Limited metadata management
- ❌ Primarily for local network use

---

### 5. **Kodi** (Honorable Mention)

**Overview:**
- Media center application (NOT a server)
- Can be used as a client for Plex/Jellyfin/Emby
- Runs on many devices including Raspberry Pi

**Key Features:**
- Extensive plugin ecosystem
- Highly customizable
- Works with network shares
- Can integrate with Plex/Jellyfin backends

**Chromecast:**
- NOT native support
- Requires workarounds or plugins

**Pros:**
- ✅ Free and open-source
- ✅ Highly customizable
- ✅ Runs on low-power hardware

**Cons:**
- ❌ Not a server solution
- ❌ No native Chromecast support
- ❌ Requires more technical setup

---

### 6. **Rapidbay** (Niche - Torrent Streaming)

**Overview:**
- Self-hosted torrent streaming service
- Designed for Chromecast/AppleTV
- Streams torrents directly without full download

**Chromecast Support:**
- Native support
- Automatic transcoding for compatibility

**Use Case:**
- Very specific use case (torrent streaming)
- Not for personal media library

---

## 7. Comprehensive Comparison: VLC vs Alternatives

### Feature Matrix

| Feature | VLC Server | Jellyfin | Plex | Emby | UMS |
|---------|-----------|----------|------|------|-----|
| **Cost** | Free | Free | Free/Premium | Free/Premium | Free |
| **Open Source** | Yes | Yes | No | Partial | Yes |
| **Media Library** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ Basic |
| **Chromecast (GUI)** | ⚠️ Limited | ✅ Excellent | ✅ Excellent | ✅ Good | ✅ Yes |
| **Chromecast (Server)** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Web Interface** | ⚠️ Basic Controls | ✅ Full Media Browser | ✅ Full Media Browser | ✅ Full Media Browser | ❌ No |
| **Mobile Apps** | 3rd party | ✅ Free | 💰 Paid | 💰 Paid | Limited |
| **Hardware Transcoding** | Manual | ✅ Free | 💰 Plex Pass | 💰 Premiere | ✅ Free |
| **Multi-User** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ Limited |
| **Remote Access** | Manual | ⚠️ Complex | ✅ Easy | ✅ Easy | ⚠️ Complex |
| **Docker Support** | ⚠️ Limited | ✅ Excellent | ✅ Excellent | ✅ Excellent | ✅ Good |
| **Metadata/Artwork** | ❌ No | ✅ Automatic | ✅ Automatic | ✅ Automatic | ⚠️ Basic |
| **Plugin System** | Limited | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Privacy** | ✅ Local | ✅ No Telemetry | ⚠️ Cloud Account | ⚠️ Some Telemetry | ✅ Local |

---

### VLC as Streaming Server - Detailed Pros & Cons

#### Pros ✅
1. **Free and open-source** - No costs, fully open
2. **Lightweight** - Can run on minimal hardware
3. **Format support** - Excellent codec/format compatibility
4. **Transcoding** - Powerful on-the-fly transcoding
5. **Flexibility** - Highly configurable via command line
6. **No setup complexity** - Simple single-file streaming
7. **Privacy** - No accounts, no telemetry, fully local

#### Cons ❌
1. **Not designed as a server** - Fundamentally a player, not server software
2. **No media library management** - No database, metadata, or organization
3. **No Chromecast from headless mode** - GUI required for casting
4. **Poor multi-user support** - Single stream focus
5. **Basic web interface** - Remote control only, not a browser
6. **Manual configuration** - Each stream requires manual setup
7. **No mobile apps** - Third-party solutions only
8. **Resource intensive for multiple streams** - Needs multiple instances
9. **No user authentication** - Basic password only
10. **Firewall complications** - Often requires manual configuration
11. **Limited documentation** - Server use not primary focus
12. **Reliability issues** - Chromecast casting can be "finicky"

---

### Jellyfin - Detailed Pros & Cons (Recommended Alternative)

#### Pros ✅
1. **Completely free** - No subscriptions, no paywalls, no premium tiers
2. **Open-source** - Fully transparent, community-driven
3. **Privacy-focused** - No telemetry, no cloud account required
4. **Hardware transcoding included** - FREE (costs $120 with Plex)
5. **Excellent Chromecast support** - Native integration
6. **Full media library** - Metadata, posters, descriptions
7. **Multi-user support** - User accounts with permissions
8. **Free mobile apps** - Android and iOS apps included
9. **Plugin system** - Extensible functionality
10. **Active development** - Regular updates and improvements
11. **Docker support** - Easy containerized deployment
12. **4K streaming** - Supports high-quality content
13. **Live TV & DVR** - Built-in, no extra cost
14. **Subtitle support** - Multiple formats
15. **No vendor lock-in** - Can migrate freely

#### Cons ❌
1. **Remote access complexity** - Requires reverse proxy/DDNS setup
2. **Smaller plugin ecosystem** - Fewer plugins than Plex
3. **Less polished UI** - Interface not as refined as Plex
4. **Subtitle bugs** - Occasional issues on some clients (Roku)
5. **Smaller community** - Less documentation than Plex
6. **Learning curve** - More setup required than Plex
7. **No official support** - Community-based help only

---

### Plex - Detailed Pros & Cons

#### Pros ✅
1. **Most polished interface** - Beautiful, intuitive UI
2. **Widest device support** - Works on everything
3. **Easy remote access** - No complex networking setup
4. **Excellent documentation** - Extensive guides and support
5. **Large community** - Many users, lots of help
6. **Plugin ecosystem** - Many available plugins
7. **Reliable Chromecast** - Very stable casting
8. **Discover content** - Can watch free third-party content
9. **Easy setup** - Quick to get started

#### Cons ❌
1. **Requires account** - Cloud-dependent, privacy concerns
2. **Hardware transcoding costs $120** - Major feature behind paywall
3. **Mobile apps cost money** - $5 one-time or Plex Pass needed
4. **Previous data breach** - Security concerns
5. **Increasing ads/bloat** - Focus on third-party content
6. **Telemetry** - Collects analytics data
7. **Subscription pressure** - Constantly upsells Plex Pass
8. **Cloud dependency** - Authentication requires internet

---

## 8. Recommendations

### For Chromecast-Compatible Self-Hosted Streaming:

#### **Best Overall Choice: Jellyfin**
**Reasons:**
- ✅ Completely free with all features
- ✅ Excellent Chromecast support
- ✅ Privacy-focused (no cloud account)
- ✅ Hardware transcoding included
- ✅ Active development
- ✅ Perfect for self-hosting enthusiasts

**Best for:** Privacy-conscious users, self-hosting enthusiasts, those who want full control without ongoing costs.

---

#### **Best for Ease of Use: Plex**
**Reasons:**
- ✅ Easiest setup and remote access
- ✅ Most polished interface
- ✅ Works on every device
- ✅ Best documentation

**Best for:** Users who value convenience over privacy, willing to pay for premium features, want "it just works" experience.

---

#### **VLC Use Cases**
**Only recommend VLC for:**
1. **Quick, temporary streaming** - One-off file sharing
2. **Format conversion** - Transcoding specific files
3. **Local playback** - Single user, single device
4. **Learning/experimentation** - Understanding streaming concepts

**NOT recommended for:**
- ❌ Permanent media server
- ❌ Multi-user scenarios
- ❌ Chromecast-focused deployment
- ❌ Media library management
- ❌ Headless/Docker server deployments

---

### Implementation Strategy

#### For Jellyfin Deployment:

**1. Docker Compose Setup (Recommended):**
```yaml
version: '3.8'
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    network_mode: host  # Important for Chromecast discovery
    volumes:
      - /path/to/config:/config
      - /path/to/cache:/cache
      - /path/to/media:/media
    environment:
      - JELLYFIN_PublishedServerUrl=http://your-server-ip:8096
    restart: unless-stopped
```

**2. Access:**
- Local: `http://localhost:8096`
- Remote: Setup reverse proxy (Nginx/Traefik) + DDNS

**3. Chromecast Setup:**
- Ensure Jellyfin and Chromecast on same network
- Enable DLNA in Jellyfin settings
- Cast from web interface or mobile apps

---

### Cost Analysis (3-Year Total Cost of Ownership)

| Solution | Setup Cost | Year 1 | Year 2 | Year 3 | 3-Year Total |
|----------|-----------|--------|--------|--------|-------------|
| **VLC** | $0 | $0 | $0 | $0 | **$0** |
| **Jellyfin** | $0 | $0 | $0 | $0 | **$0** |
| **Plex (Free)** | $0 | $0 | $0 | $0 | **$0** ⚠️ |
| **Plex Pass (Monthly)** | $0 | $59.88 | $59.88 | $59.88 | **$179.64** |
| **Plex Pass (Lifetime)** | $119.99 | $0 | $0 | $0 | **$119.99** |
| **Emby Premiere** | $119 | $0 | $0 | $0 | **$119** |

⚠️ Plex Free lacks hardware transcoding and mobile apps

**Winner:** Jellyfin (Full features at $0)

---

## 9. Conclusion

### Key Findings:

1. **VLC is NOT suitable as a primary media server** for Chromecast streaming:
   - Lacks media library management
   - No Chromecast support in headless/server mode
   - Poor multi-user support
   - Basic web interface insufficient for browsing

2. **Jellyfin is the best alternative** for self-hosted Chromecast streaming:
   - All features completely free
   - Excellent Chromecast integration
   - Privacy-focused
   - Active development

3. **Plex is best for users prioritizing ease-of-use** over cost and privacy:
   - Most polished experience
   - Easiest setup
   - But costs $120 for hardware transcoding

4. **VLC has valid use cases** but only for:
   - Temporary/ad-hoc streaming
   - Format conversion/transcoding
   - Single-user local playback
   - Learning and experimentation

### Final Recommendation:

**For a self-hosted video streaming solution with Chromecast support:**
- 🥇 **Use Jellyfin** - Best overall value and features
- 🥈 **Use Plex if willing to pay** - Best user experience
- 🥉 **Avoid VLC for this purpose** - Not designed for this use case

### Next Steps:

If proceeding with Jellyfin:
1. Set up Docker container with proper volume mounts
2. Configure network mode to `host` for Chromecast discovery
3. Organize media library with proper folder structure
4. Set up reverse proxy for remote access (optional)
5. Install mobile apps for casting
6. Test Chromecast functionality

---

## Sources

### VLC Streaming Server Setup
- [How to make VLC server that can communicate with clients - Super User](https://superuser.com/questions/719600/how-to-make-vlc-server-that-can-communicate-with-clients)
- [How to stream on your LAN using VLC? - DEV Community](https://dev.to/apalebluedev/how-to-stream-on-your-lan-using-vlc-1h0j)
- [Media Server VLC: Complete Guide to VLC Streaming Server Setup in 2025 - VideoSDK](https://www.videosdk.live/developer-hub/media-server/media-server-vlc)
- [Streaming-Server - VideoLAN](http://www.videolan.org/vlc/streaming.html)
- [How to configure VLC as streaming server - VideoLAN Forums](https://forum.videolan.org/viewtopic.php?t=59676)
- [How to stream multiple files on demand in VLC? - Super User](https://superuser.com/questions/50609/how-to-stream-multiple-files-on-demand-in-vlc)
- [How to stream Video using VLC in http to other computer - Stack Overflow](https://stackoverflow.com/questions/65293175/how-to-stream-video-using-vlc-in-http-to-other-computer)

### VLC Docker Containers
- [run vlc in a Docker image to send a video stream via rtsp protocol - Stack Overflow](https://stackoverflow.com/questions/42162137/run-vlc-in-a-docker-image-to-send-a-video-stream-via-rtsp-protocol)
- [GitHub - galexrt/container-vlc: VLC Media Player in a Container Image](https://github.com/galexrt/container-vlc)
- [GitHub - lroktu/vlc-server: Docker container based VLC Server](https://github.com/lroktu/vlc-server)
- [GitHub - yinshangqing/docker-vlc: VLC Media Player in a Docker container](https://github.com/yinshangqing/docker-vlc)
- [galexrt/vlc - Docker Hub](https://hub.docker.com/r/galexrt/vlc/)
- [GitHub - gersilex/cvlc-docker: Video Lan Client for streaming](https://github.com/gersilex/cvlc-docker)

### VLC Chromecast Compatibility
- [How to Cast VLC to Chromecast [Full Guide] - Reolink](https://reolink.com/blog/vlc-chromecast/)
- [How to Stream From VLC to Your Chromecast - How-To Geek](https://www.howtogeek.com/269272/how-to-stream-from-vlc-to-your-chromecast/)
- [How to Stream Videos From VLC to Chromecast - MakeUseOf](https://www.makeuseof.com/tag/stream-videos-vlc-chromecast/)
- [How to Stream VLC Player to Chromecast - Alphr](https://www.alphr.com/google/1002435/how-to-stream-vlc-player-to-chromecast/)
- [How does VLC cast to Chromecast work? - VideoLAN Forums](https://forum.videolan.org/viewtopic.php?t=147224)
- [VLC not compatible with Chromecast with Google TV - VideoLAN Forums](https://forum.videolan.org/viewtopic.php?t=165208)

### VLC Web Interface
- [How to Remote Control VLC in Few Simple Procedures - Wondershare](https://videoconverter.wondershare.com/vlc/how-to-remote-control-vlc.html)
- [How to Activate VLC's Web Interface - How-To Geek](https://www.howtogeek.com/117261/how-to-activate-vlcs-web-interface-control-vlc-from-a-browser-use-any-smartphone-as-a-remote/)
- [Web interface - VideoLAN Wiki](https://wiki.videolan.org/Control_VLC_via_a_browser)
- [GitHub - franciscobmacedo/vlc-remote-control: VLC remote control web interface](https://github.com/franciscobmacedo/vlc-remote-control)

### Jellyfin, Plex, and Alternatives
- [Great Jellyfin Alternatives - AlternativeTo](https://alternativeto.net/software/jellyfin/)
- [The best Plex alternative in 2025 is Jellyfin - Android Authority](https://www.androidauthority.com/jellyfin-vs-plex-home-server-3360937/)
- [The Top 7 Plex Alternatives (2025 Update) - RapidSeedbox](https://www.rapidseedbox.com/blog/plex-alternatives)
- [Best Plex alternatives in 2024: Jellyfin, Emby, and more - XDA](https://www.xda-developers.com/best-plex-alternatives/)
- [Plex vs. Jellyfin: Which Media Server Solution Is the Best? - How-To Geek](https://www.howtogeek.com/plex-vs-jellyfin-media-server-comparison/)
- [Jellyfin vs Plex: Best Self-hosted Media Server - Virtualization Howto](https://www.virtualizationhowto.com/2023/10/jellyfin-vs-plex-best-self-hosted-media-server/)
- [5 Plex alternatives you can self-host on your NAS - XDA](https://www.xda-developers.com/plex-alternatives-self-host-nas/)

### Self-Hosted Media Servers 2025
- [OwnTone: Your Local-First Self-hosted Audio Media Server - Medevel](https://medevel.com/owntone/)
- [Plex Alternatives: Top 20 Self-Hosted Media Servers - AlternativeTo](https://alternativeto.net/software/plex/?platform=self-hosted)
- [Top 10 Self-Hosted Apps - Perfect Media Server](https://perfectmediaserver.com/04-day-two/top10apps/)
- [Media Server Hosting in 2025: The Ultimate Guide - VideoSDK](https://www.videosdk.live/developer-hub/media-server/media-server-hosting)
- [GitHub - hauxir/rapidbay: Self-hosted torrent video streaming](https://github.com/hauxir/rapidbay)
- [Media Streaming - awesome-selfhosted](https://awesome-selfhosted.net/tags/media-streaming---video-streaming.html)
- [3 ways a Chromecast was the best addition to my self-hosted smart home - XDA](https://www.xda-developers.com/chromecast-best-addition-self-hosted-smart-home/)

---

**Document Version:** 1.0
**Last Updated:** November 28, 2025
**Next Review:** As needed based on software updates
