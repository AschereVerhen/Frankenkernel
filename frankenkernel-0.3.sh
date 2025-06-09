#!/bin/bash


##This script is made in mind for Advanced Power users, gentoo users migrating to arch linux, and new users alike.


if [ ! "$(id -u)" -eq "0" ]; then
    echo "We need to run this script as root. Sorry, i will have to terminate. Run me with sudo or as root."
    exit 1
fi 

if ! command -v pacman mkinitcpio &>/dev/null; then
    echo "This script is only for arch-based distros. With MKINITCPIO. like arch itself. exitting"
    exit 1
fi 

for commands in curl jq gcc make grub rsync; do 
    if ! command -v "$commands" &>/dev/null; then
        pacman -S "$commands"
    else 
        echo -e "Nice! ${command} is Already installed.\n"
    fi 
done 


config_user="null" ##Set the user config path to be null by default.
for args in "$@"; do 
    case "${args}" in 
        --help)
            echo -e "This is a script which helps in compilation of custom kernels in ArchLinux!! Its for users who are migrating from gentoo, are power users, or are beginners who wants to learn how to compile custom kernels. This is done to encourage Custom kernel compilations in the arch community to give users something else to do instead of just ricing(Not that i am against it, i am a ricer myself). And this also improves the user's knowledge of the linux kernel. Improving their portfolio. \n\n Flags are: --help: Prints this menu\n --clean: Cleans the kernel source directory\n --config=: Takes the custom config from users if said users have a config available.\n"
            exit 0
            shift
            ;;
        --clean)
            clean_source="y"
            shift
            ;;
        --config=*)
            config_user="${args#*=}"
            shift
            ;;
        --dry-run)
            dry_run="y"
            shift
            ;;
        *)
            echo -e "${args} is an invalid flag. Exitting"
            exit 1
            shift
            ;;
    esac
done
run_or_dry() {
    if [ ${dry_run} = "y" ]; then
        echo -e "[DRY RUN]: $*"
    else 
        eval "$@"
    fi 
}


#Checking if the user wants to make the kernel from scratch or would like to copy the .config file from their current kernel
if [ -e  /proc/config.gz ] && [ ${config_user} = "null" ]; then
    read -p "Looks like you already have a kernel running. would you like to extract the .config of that kernel and compile the kernel with as is (For beginners! You should do exactly this...!) (y/n):" config_old
fi 

cd /usr/src

#Making a kernel_compile function 
kernel_compile ()
{
    if [ -e /usr/src/linux/.config ]; then
        run_or_dry "make -j$(nproc)"               #Compile the kernel
        run_or_dry "make -j$(nproc) modules"       #Compile modules like nouveau, amdgpu, radeon, etc...
        run_or_dry "make -j$(nproc) modules_install" #Install modules
        run_or_dry "make -j$(nproc) headers"     #Compile headers
        run_or_dry "make -j$(nproc) headers_install"  #Install headers
        #installkernel $(make kernelrelease) vmlinuz System.map ##Parse kernel through installkernel so that it installs initramfs and regenerates grub-config or any other bootloaders. (UPDATE: it looks like arch doesnt support installkernel. so we wil have to do everything by ourselves.)
        run_or_dry "make install" #Installing vmlinuz to /boot
        run_or_dry "mv vmlinuz vmlinuz-linux-custom" ##Renaming the vmlinuz to vmlinuz-linux-custom
        run_or_dry "mkinitcpio -k "$(make kernelrelease)" -g "/boot/initramfs-linux-custom.img"" ##Making initramfs
        run_or_dry "grub-mkconfig -o /boot/grub/grub.cfg" ##For now Only supporting grub. TODO: Add more bootloaders.
        run_or_dry "cp System.map /boot/System.map" ##As FAT32 doesnt support symlinks, copy the System.map to the partition
        if [ ${clean_source} = "y" ]; then
            make clean   #Clean source directory.
        fi
    fi 
}

#Copying and untaring the kernel
latest_kver=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')
url="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${latest_kver}.tar.xz"
echo -e "\n Downloading Latest stable kernel, linux-${latest_kver} from kernel.org"
run_or_dry "curl -LO \"${url}\""
tar xpvf "linux-${latest_kver}.tar.xz"
ln -s "linux-${latest_kver}" linux
cd linux

compilation_done="null"
#Copying and compiling from the config user gave if any.
if [ ! ${config_user} = "null" ]; then
    cp -r "${config_user}" /usr/src/linux
    kernel_compile
    compilation_done="y"
fi 

#Copying the config if config_old is yes.

if [ "${config_old,,}" = "y" ]; then
    zcat /proc/config.gz > $(pwd)/.config
    echo -e "\n I have copied the .config file. Now compiling."
    kernel_compile
    compilation_done="y"
fi 

echo -e "Now begining making of .config. Executing make menuconfig. **Please save the config file as .config**\n"

if [ ! "${compilation_done}" = "y" ]; then
    make menuconfig

    ##Removing compile kernel with warnings as errors, as that will not allow custom kernels to compile correctly.
    sed -i 's/^CONFIG_WERROR.*/# &/' /usr/src/linux/.config

    echo -e "Alright. Now that .config has been made, compiling the kernel."
    kernel_compile
fi 
##Making a new preset for the custom kernel...
echo -e "ALL_kver="/boot/vmlinuz-linux-custom" \n PRESETS=('default') \n default_image="/boot/initramfs-linux-custom.img"" >> /etc/mkinitcpio.d/linux-custom.preset

##Now checking if the user has nvidia drivers. if yes, then installing the dkms version of it.
if lspci | grep -i "nvidia" &> /dev/null; then
    nvidia_detected=true

    if pacman -Qq | grep -qw nvidia; then
        pacman -Rns nvidia; pacman -S nvidia-dkms
    elif pacman -Qq | grep -qw nvidia-open; then
        pacman -Rns nvidia-open; pacman -S nvidia-open-dkms
    else 
        echo "It looks like you are using nouveau drivers. good for you, ig."
    fi 
else 
    echo "It looks like you are using amd/intel gpu."
    exit 0
fi 


