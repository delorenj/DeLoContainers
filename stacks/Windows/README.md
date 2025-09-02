Windows inside a Docker container.

## Features ✨

[](https://github.com/dockur/windows#features-)

-   ISO downloader
-   KVM acceleration
-   Web-based viewer

## Video 📺

[](https://github.com/dockur/windows#video-)

[![Youtube](https://camo.githubusercontent.com/c500c734a7cf171b2c89dd3f65132e1483931ac78a6b96411b431f0e016ea3eb/68747470733a2f2f696d672e796f75747562652e636f6d2f76692f786847596f6275473530382f302e6a7067)](https://www.youtube.com/watch?v=xhGYobuG508)

## Usage 🐳

[](https://github.com/dockur/windows#usage-)

##### Via Docker Compose:

[](https://github.com/dockur/windows#via-docker-compose)

```yaml
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "11"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
    volumes:
      - ./windows:/storage
    restart: always
    stop_grace_period: 2m
```

##### Via Docker CLI:

[](https://github.com/dockur/windows#via-docker-cli)

```shell
docker run -it --rm --name windows -p 8006:8006 --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -v "${PWD:-.}/windows:/storage" --stop-timeout 120 dockurr/windows
```

##### Via Kubernetes:

[](https://github.com/dockur/windows#via-kubernetes)

```shell
kubectl apply -f https://raw.githubusercontent.com/dockur/windows/refs/heads/master/kubernetes.yml
```

##### Via Github Codespaces:

[](https://github.com/dockur/windows#via-github-codespaces)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dockur/windows)

## FAQ 💬

[](https://github.com/dockur/windows#faq-)

### How do I use it?

[](https://github.com/dockur/windows#how-do-i-use-it)

Very simple! These are the steps:

-   Start the container and connect to [port 8006](http://127.0.0.1:8006/) using your web browser.
    
-   Sit back and relax while the magic happens, the whole installation will be performed fully automatic.
    
-   Once you see the desktop, your Windows installation is ready for use.
    

Enjoy your brand new machine, and don't forget to star this repo!

### How do I select the Windows version?

[](https://github.com/dockur/windows#how-do-i-select-the-windows-version)

By default, Windows 11 Pro will be installed. But you can add the `VERSION` environment variable to your compose file, in order to specify an alternative Windows version to be downloaded:

```yaml
environment:
  VERSION: "11"
```

Select from the values below:

| **Value** | **Version** | **Size** |
| --- | --- | --- |
| `11` | Windows 11 Pro | 5.4 GB |
| `11l` | Windows 11 LTSC | 4.7 GB |
| `11e` | Windows 11 Enterprise | 4.0 GB |
|  |  |  |
| `10` | Windows 10 Pro | 5.7 GB |
| `10l` | Windows 10 LTSC | 4.6 GB |
| `10e` | Windows 10 Enterprise | 5.2 GB |
|  |  |  |
| `8e` | Windows 8.1 Enterprise | 3.7 GB |
| `7u` | Windows 7 Ultimate | 3.1 GB |
| `vu` | Windows Vista Ultimate | 3.0 GB |
| `xp` | Windows XP Professional | 0.6 GB |
| `2k` | Windows 2000 Professional | 0.4 GB |
|  |  |  |
| `2025` | Windows Server 2025 | 5.6 GB |
| `2022` | Windows Server 2022 | 4.7 GB |
| `2019` | Windows Server 2019 | 5.3 GB |
| `2016` | Windows Server 2016 | 6.5 GB |
| `2012` | Windows Server 2012 | 4.3 GB |
| `2008` | Windows Server 2008 | 3.0 GB |
| `2003` | Windows Server 2003 | 0.6 GB |

### How do I change the storage location?

[](https://github.com/dockur/windows#how-do-i-change-the-storage-location)

To change the storage location, include the following bind mount in your compose file:

```yaml
volumes:
  - ./windows:/storage
```

Replace the example path `./windows` with the desired storage folder or named volume.

### How do I change the size of the disk?

[](https://github.com/dockur/windows#how-do-i-change-the-size-of-the-disk)

To expand the default size of 64 GB, add the `DISK_SIZE` setting to your compose file and set it to your preferred capacity:

```yaml
environment:
  DISK_SIZE: "256G"
```

Tip

This can also be used to resize the existing disk to a larger capacity without any data loss.

### How do I share files with the host?

Open 'File Explorer' and click on the 'Network' section, you will see a computer called `host.lan`.

Double-click it and it will show a folder called `Data`, which can be bound to any folder on your host via the compose file:

```yaml
volumes:
  -  ./example:/data
```

The example folder `./example` will be available as `\\host.lan\Data`.

Tip

You can map this path to a drive letter in Windows, for easier access.

### How do I change the amount of CPU or RAM?

[](https://github.com/dockur/windows#how-do-i-change-the-amount-of-cpu-or-ram)

By default, the container will be allowed to use a maximum of 2 CPU cores and 4 GB of RAM.

If you want to adjust this, you can specify the desired amount using the following environment variables:

```yaml
environment:
  RAM_SIZE: "8G"
  CPU_CORES: "4"
```

### How do I configure the username and password?

[](https://github.com/dockur/windows#how-do-i-configure-the-username-and-password)

By default, a user called `Docker` is created during installation and its password is `admin`.

If you want to use different credentials, you can configure them in your compose file (only before installation):

```yaml
environment:
  USERNAME: "bill"
  PASSWORD: "gates"
```

### How do I select the Windows language?

[](https://github.com/dockur/windows#how-do-i-select-the-windows-language)

By default, the English version of Windows will be downloaded.

But before installation you can add the `LANGUAGE` environment variable to your compose file, in order to specify an alternative language:

```yaml
environment:
  LANGUAGE: "French"
```

You can choose between: 🇦🇪 Arabic, 🇧🇬 Bulgarian, 🇨🇳 Chinese, 🇭🇷 Croatian, 🇨🇿 Czech, 🇩🇰 Danish, 🇳🇱 Dutch, 🇬🇧 English, 🇪🇪 Estonian, 🇫🇮 Finnish, 🇫🇷 French, 🇩🇪 German, 🇬🇷 Greek, 🇮🇱 Hebrew, 🇭🇺 Hungarian, 🇮🇹 Italian, 🇯🇵 Japanese, 🇰🇷 Korean, 🇱🇻 Latvian, 🇱🇹 Lithuanian, 🇳🇴 Norwegian, 🇵🇱 Polish, 🇵🇹 Portuguese, 🇷🇴 Romanian, 🇷🇺 Russian, 🇷🇸 Serbian, 🇸🇰 Slovak, 🇸🇮 Slovenian, 🇪🇸 Spanish, 🇸🇪 Swedish, 🇹🇭 Thai, 🇹🇷 Turkish and 🇺🇦 Ukrainian.

### How do I select the keyboard layout?

[](https://github.com/dockur/windows#how-do-i-select-the-keyboard-layout)

If you want to use a keyboard layout or locale that is not the default for your selected language, you can add `KEYBOARD` and `REGION` variables like this (before installation):

```yaml
environment:
  REGION: "en-US"
  KEYBOARD: "en-US"
```

### How do I select the edition?

[](https://github.com/dockur/windows#how-do-i-select-the-edition)

Windows Server offers a minimalistic Core edition without a GUI. To select those non-standard editions, you can add a `EDITION` variable like this (before installation):

```yaml
environment:
  EDITION: "core"
```

### How do I install a custom image?

[](https://github.com/dockur/windows#how-do-i-install-a-custom-image)

In order to download an unsupported ISO image, specify its URL in the `VERSION` environment variable:

```yaml
environment:
  VERSION: "https://example.com/win.iso"
```

Alternatively, you can also skip the download and use a local file instead, by binding it in your compose file in this way:

```yaml
volumes:
  - ./example.iso:/boot.iso
```

Replace the example path `./example.iso` with the filename of your desired ISO file. The value of `VERSION` will be ignored in this case.

### How do I run a script after installation?

[](https://github.com/dockur/windows#how-do-i-run-a-script-after-installation)

To run your own script after installation, you can create a file called `install.bat` and place it in a folder together with any additional files it needs (software to be installed for example).

Then bind that folder in your compose file like this:

```yaml
volumes:
  -  ./example:/oem
```

The example folder `./example` will be copied to `C:\OEM` and the containing `install.bat` will be executed during the last step of the automatic installation.

### How do I perform a manual installation?

[](https://github.com/dockur/windows#how-do-i-perform-a-manual-installation)

It's recommended to stick to the automatic installation, as it adjusts various settings to prevent common issues when running Windows inside a virtual environment.

However, if you insist on performing the installation manually at your own risk, add the following environment variable to your compose file:

### How do I connect using RDP?

[](https://github.com/dockur/windows#how-do-i-connect-using-rdp)

The web-viewer is mainly meant to be used during installation, as its picture quality is low, and it has no audio or clipboard for example.

So for a better experience you can connect using any Microsoft Remote Desktop client to the IP of the container, using the username `Docker` and password `admin`.

There is a RDP client for [Android](https://play.google.com/store/apps/details?id=com.microsoft.rdc.androidx) available from the Play Store and one for [iOS](https://apps.apple.com/nl/app/microsoft-remote-desktop/id714464092?l=en-GB) in the Apple Store. For Linux you can use [FreeRDP](https://www.freerdp.com/) and on Windows just type `mstsc` in the search box.

### How do I assign an individual IP address to the container?

[](https://github.com/dockur/windows#how-do-i-assign-an-individual-ip-address-to-the-container)

By default, the container uses bridge networking, which shares the IP address with the host.

If you want to assign an individual IP address to the container, you can create a macvlan network as follows:

```shell
docker network create -d macvlan \
    --subnet=192.168.0.0/24 \
    --gateway=192.168.0.1 \
    --ip-range=192.168.0.100/28 \
    -o parent=eth0 vlan
```

Be sure to modify these values to match your local subnet.

Once you have created the network, change your compose file to look as follows:

```yaml
services:
  windows:
    container_name: windows
    ..<snip>..
    networks:
      vlan:
        ipv4_address: 192.168.0.100

networks:
  vlan:
    external: true
```

An added benefit of this approach is that you won't have to perform any port mapping anymore, since all ports will be exposed by default.

Important

This IP address won't be accessible from the Docker host due to the design of macvlan, which doesn't permit communication between the two. If this is a concern, you need to create a [second macvlan](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/#host-access) as a workaround.

### How can Windows acquire an IP address from my router?

[](https://github.com/dockur/windows#how-can-windows-acquire-an-ip-address-from-my-router)

After configuring the container for [macvlan](https://github.com/dockur/windows#how-do-i-assign-an-individual-ip-address-to-the-container), it is possible for Windows to become part of your home network by requesting an IP from your router, just like a real PC.

To enable this mode, in which the container and Windows will have separate IP addresses, add the following lines to your compose file:

```yaml
environment:
  DHCP: "Y"
devices:
  - /dev/vhost-net
device_cgroup_rules:
  - 'c *:* rwm'
```

### How do I add multiple disks?

[](https://github.com/dockur/windows#how-do-i-add-multiple-disks)

To create additional disks, modify your compose file like this:

```yaml
environment:
  DISK2_SIZE: "32G"
  DISK3_SIZE: "64G"
volumes:
  - ./example2:/storage2
  - ./example3:/storage3
```

### How do I pass-through a disk?

[](https://github.com/dockur/windows#how-do-i-pass-through-a-disk)

It is possible to pass-through disk devices or partitions directly by adding them to your compose file in this way:

```yaml
devices:
  - /dev/sdb:/disk1
  - /dev/sdc1:/disk2
```

Use `/disk1` if you want it to become your main drive (which will be formatted during installation), and use `/disk2` and higher to add them as secondary drives (which will stay untouched).

### How do I pass-through a USB device?

[](https://github.com/dockur/windows#how-do-i-pass-through-a-usb-device)

To pass-through a USB device, first lookup its vendor and product id via the `lsusb` command, then add them to your compose file like this:

```yaml
environment:
  ARGUMENTS: "-device usb-host,vendorid=0x1234,productid=0x1234"
devices:
  - /dev/bus/usb
```

If the device is a USB disk drive, please wait until after the installation is fully completed before connecting it. Otherwise the installation may fail, as the order of the disks can get rearranged.

### How do I verify if my system supports KVM?

[](https://github.com/dockur/windows#how-do-i-verify-if-my-system-supports-kvm)

First check if your software is compatible using this chart:

| **Product** | **Linux** | **Win11** | **Win10** | **macOS** |
| --- | --- | --- | --- | --- |
| Docker CLI | ✅ | ✅ | ❌ | ❌ |
| Docker Desktop | ❌ | ✅ | ❌ | ❌ |
| Podman CLI | ✅ | ✅ | ❌ | ❌ |
| Podman Desktop | ✅ | ✅ | ❌ | ❌ |

After that you can run the following commands in Linux to check your system:

```shell
sudo apt install cpu-checker
sudo kvm-ok
```

If you receive an error from `kvm-ok` indicating that KVM cannot be used, please check whether:

-   the virtualization extensions (`Intel VT-x` or `AMD SVM`) are enabled in your BIOS.
    
-   you enabled "nested virtualization" if you are running the container inside a virtual machine.
    
-   you are not using a cloud provider, as most of them do not allow nested virtualization for their VPS's.
    

If you did not receive any error from `kvm-ok` but the container still complains about a missing KVM device, it could help to add `privileged: true` to your compose file (or `sudo` to your `docker` command) to rule out any permission issue.

### How do I run macOS in a container?

[](https://github.com/dockur/windows#how-do-i-run-macos-in-a-container)

You can use [dockur/macos](https://github.com/dockur/macos) for that. It shares many of the same features, except for the automatic installation.

### How do I run a Linux desktop in a container?

[](https://github.com/dockur/windows#how-do-i-run-a-linux-desktop-in-a-container)

You can use [qemus/qemu](https://github.com/qemus/qemu) in that case.

### Is this project legal?

[](https://github.com/dockur/windows#is-this-project-legal)

Yes, this project contains only open-source code and does not distribute any copyrighted material. Any product keys found in the code are just generic placeholders provided by Microsoft for trial purposes. So under all applicable laws, this project will be considered legal.

## FL Studio Audio Production Setup 🎵

This setup is configured for FL Studio with USB audio interface and MIDI controller passthrough.

### Connected Devices:
- **Focusrite Scarlett 4i4 4th Gen** (USB ID: 1235:821a)
- **Arturia KeyLab mkII 88** (USB ID: 1c75:02cb)

### Connecting with FreeRDP:
```bash
cd /home/delorenj/docker/trunk-main/stacks/Windows
./connect-flstudio.sh [username] [password]
```

Default credentials:
- Username: `Docker`
- Password: `admin`

### Audio Configuration in Windows:
1. Open Windows Sound Settings
2. Set Focusrite USB Audio as default playback device
3. Set Focusrite USB Audio as default recording device
4. Install Focusrite Control software from focusrite.com
5. Install FL Studio and configure audio settings to use Focusrite ASIO driver

### Troubleshooting Audio Devices:
If Focusrite devices don't appear in Windows:
1. Check Device Manager for any unrecognized USB devices
2. Try reconnecting the USB devices while Windows is running
3. Install Focusrite drivers manually if needed
4. Check if devices appear under "Sound, video and game controllers"
5. Restart Windows audio services if needed

### VST Plugin Installation:
Your VST plugins are available at `\\host.lan\Data\vst` in Windows File Explorer.

To install plugins:
1. Open File Explorer and navigate to `\\host.lan\Data\vst`
2. Run the Windows installer executables (.exe files)
3. Install plugins to their default locations
4. In FL Studio, go to Options > File Settings and add the VST plugin directories

Available plugins include:
- FabFilter Total Bundle
- iZotope Bundle (Nectar, Neutron, Ozone, etc.)
- reFX Nexus 5
- Applied Acoustics Lounge Lizard
- Pulsar Audio Vocal Studio
- Ableton Live 12 Suite

## Stars 🌟

[](https://github.com/dockur/windows#stars-)

[![Stars](https://camo.githubusercontent.com/f1d1e81ca0959e2817b94c394169862428df2fbc6b5ee24b4eb33ca668474f85/68747470733a2f2f7374617263686172742e63632f646f636b75722f77696e646f77732e7376673f76617269616e743d6164617074697665)](https://starchart.cc/dockur/windows)

## Disclaimer ⚖️

[](https://github.com/dockur/windows#disclaimer-%EF%B8%8F)

_The product names, logos, brands, and other trademarks referred to within this project are the property of their respective trademark holders. This project is not affiliated, sponsored, or endorsed by Microsoft Corporation._
