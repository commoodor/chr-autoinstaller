# Cloud Hosted Router v6 & v7 Auto Installer
## build date : dec 2024
### just run
~~~
wget -qO- https://github.com/commoodor/chr-autoinstaller/raw/refs/heads/latest/run.sh | bash
~~~
Or
~~~
curl -Lso- https://github.com/commoodor/chr-autoinstaller/raw/refs/heads/latest/run.sh | bash
~~~


Example Output
~~~
[1] Preparation
Updating system packages...
Hit:1 http://archive.ubuntu.com/ubuntu focal InRelease
Hit:2 http://archive.ubuntu.com/ubuntu focal-updates InRelease
Hit:3 http://archive.ubuntu.com/ubuntu focal-security InRelease
Fetched 50.0 MB in 5s (10.0 MB/s)
Reading package lists... Done
Building dependency tree       
Reading state information... Done
48 packages can be upgraded. Run 'apt list --upgradable' to see them.
Reading package lists... Done
Building dependency tree       
Reading state information... Done
All packages are up to date.
The following additional packages will be installed:
  unzip wget
Suggested packages:
  unzip-doc
The following NEW packages will be installed:
  unzip wget
0 upgraded, 2 newly installed, 0 to remove and 0 not upgraded.
Need to get 1,080 kB of archives.
After this operation, 5,494 kB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu focal/universe amd64 unzip amd64 6.0-21ubuntu1 [179 kB]
Get:2 http://archive.ubuntu.com/ubuntu focal/universe amd64 wget amd64 1.20.3-1ubuntu2.2 [902 kB]
Fetched 1,080 kB in 1s (1,423 kB/s)
Selecting previously unselected package unzip.
(Reading database ... 302992 files and directories currently installed.)
Preparing to unpack .../unzip_6.0-21ubuntu1_amd64.deb ...
Unpacking unzip (6.0-21ubuntu1) ...
Selecting previously unselected package wget.
Preparing to unpack .../wget_1.20.3-1ubuntu2.2_amd64.deb ...
Unpacking wget (1.20.3-1ubuntu2.2) ...
Setting up unzip (6.0-21ubuntu1) ...
Setting up wget (1.20.3-1ubuntu2.2) ...
Processing triggers for libc-bin (2.31-0ubuntu9.9) ...
[2] Getting Information
[+] STORAGE : sda
[+] INTERFACE : eth0
[+] IP ADDRESS : 192.168.1.100/24
[+] GATEWAY : 192.168.1.1
[+] Fetching latest Cloud Hosted Router ...
[+] Fetching latest Cloud Hosted Router version from MikroTik download page...
[+] Latest RouterOS v6 Version: 6.49.7
[+] Latest RouterOS v7 Version: 7.10.2
[3] Select RouterOS Version
1) RouterOS v6: 6.49.7
2) RouterOS v7: 7.10.2
3) Exit
Enter your choice (1, 2, or 3): 1
[+] Selected RouterOS Version: 6.49.7
[4] Proceeding with RouterOS Version: 6.49.7
Downloading RouterOS image for version 6.49.7...
--2024-12-13 14:05:27--  https://download.mikrotik.com/routeros/6.49.7/chr-6.49.7.img.zip
Resolving download.mikrotik.com (download.mikrotik.com)... 185.9.79.158
Connecting to download.mikrotik.com (download.mikrotik.com)|185.9.79.158|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 20,000,000 (20M) [application/zip]
Saving to: ‘chr.img.zip’

chr.img.zip           100%[===================>]  20.00M  1.24MB/s    in 16s     

2024-12-13 14:05:43 (1.24 MB/s) - ‘chr.img.zip’ saved [20000000/20000000]
[+] Unzipping RouterOS image...
inflating: chr-6.49.7.img
[+] Mounting image...
[+] Configuring RouterOS settings...
[+] Unmounting image...
[5] Flashing the image to disk...
dd if=chr-6.49.7.img bs=1M of=/dev/vda status=progress
123456789/1000000 bytes (12.3 MB) copied, 2.3 s, 5.3 MB/s
[6] Complete. Rebooting now...
~~~
