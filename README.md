Helllooooo!
Aschere Here!


This is my fourth-ish repository on github. This is a *simple* automation script made in bash... 

It is made to help new users, gentoo-linux migrators and power users overcome a simple issue of traditional compilation of custom kernels.
Arch, being arch, is a little hard on traditional compilation(the one that is used in every other linux distro) and tries to promote compilation by MAKEPKG.
and while that is good for people to plan on sticking in arch, contribute to it, and are willing to learn MAKEPKG, but those who are from any other distro and dont want to learn MAKEPKG just to compile their kernel, this is for them!!

This script automates:

1) Fetching the latest stable kernel source from official kernel.org,
2) untaring it in /usr/src
3) symlinking it to /usr/src/linux
4) checking if /proc/config.gz exists and if so, prompt the users to use it (For the beginners!)
5) make menuconfig (From here, you kinda are on your own. Enable/Disable the options you like as usual and save the config as ".config")
6) the make phases (Inc. The compilation of headers. usefull for nvidia-drivers.)
7) Checking of nvidia gpu, and if found "nvidia" or "nvidia-open" driver, replace it with their dkms counterparts.
8) And make a new mkinitcpio preset so that the initramfs is generated automatically when installing packages which call for module rebuild. (Like plymouth and dkms)

I strongly recommend everyone to install a kernel like linux-zen along side this as this kernel is completely made by the user and might have a slight chance of breakage if the user doesnt know what they are doing.
And using linux-zen would be benificial as both the custom and zen kernels use dkms modules of nvidia.

Moreover, this script is only compatible with Archlinux distros and its derivaties if the said derivaties uses mkinitcpio and not dracut(looking at you, cachyos).

The available flags are: --help, --clean, --config, --dry-run. A detailed output is available in the script or by running frankinkernel.sh --help
