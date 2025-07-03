import subprocess
import os
from pathlib import Path as path
import requests
import json
import hashlib
##First goal: make the kernel_compile() function.

##Testing echo
#subprocess.run(["echo", "Hello world"]) ##It works... so i have to seperate echo and hello world...


def run(name,command,wd): ##Syntax: run(name,"[command]","/path/to/working/directory"), eg:  run("build",["make", f'-j{os.cpu_count()}'],src_path)
    try:
        subprocess.run(command,
                       check=True,
                       capture_output=True,
                       cwd=wd,
                       text=True)
    except subprocess.CalledProcessError as e:
        print(f"Command failed with return code {e.returncode}")
        path(f'{name}.err').write_text(e.stderr or "")
        path(f'{name}.out').write_text(e.stdout or "")
        return 1
    else:
        return 0



def kernel_compile():
    ##This compiles the kernel that sits in /usr/src
    
    src_path=path("/usr/src/linux")
    if not src_path.exists():
        print("Oh, oh. the kernel is not symlinked to linux.... Fail.")
        return 1

    if run("build",["make", f'-j{os.cpu_count()}'],src_path): return 1
    ##Make phase over. Now moving on to make modules_install.
    if run("modules",["make","modules_install",f"-j{os.cpu_count()}"],src_path): return 1
    ##Headers portion is right now skipped as it relys on argument parser and is a user-enabled feature. havent implemented argparse yet.
    ##Moving on to make install
    if run("install",["make", "install"],src_path): return 1 ##No error handling as an error(cannot find lilo), is expected.
    ##now moving to mkinitcpio section
    path('/etc/mkinitcpio.d/linux-custom.preset').write_text("ALL_kver=\"/boot/vmlinuz-linux-custom\" \n PRESETS=('default') \n default_image=\"/boot/initramfs-linux-custom.img\"")
    ##Making initramfs
    k_release=subprocess.run(["make","kernelrelease"],text=True,capture_output=True,cwd=src_path)
    if run("initramfs",["mkinitcpio","-k",f"{k_release.stdout.strip()}","-g","/boot/initramfs-linux-custom.img"],src_path): return 1
    ##Regenerating grub-mkconfig.
    ##There isnt any error that might happen in this phase.
    subprocess.run(["grub-mkconfig","-o","/boot/grub/grub.cfg"])##No need for cwd....
    return 0

def get_kernel():
    ##This function is to get the latest kernel sources... 
    src_directory=path('/usr/src')
    ##First, getting kernel latest version.
    resp=requests.get("https://www.kernel.org/releases.json")
    resp.raise_for_status()##Kill the tool if status code != 200(or 1 in python language or 0 in linux lango)
    data=resp.json()
    latest_version=data["latest_stable"]["version"]
    print (f"Latest kernel version is: {latest_version}")
    ##Now, getting the Actual kernel.
    url=f"https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-{latest_version}.tar.xz"
    with requests.get(url, stream=True) as request:
        request.raise_for_status()
        with open(f"linux-{latest_version}.tar.xz", 'wb') as file:
            for chunk in request.iter_content(chunk_size=8192):
                file.write(chunk)
    print("File downloaded!")
    ##Now, SHA256 checksum!!
    hash=hashlib.sha256()
    with open(f"linux-{latest_version}.tar.xz",'rb') as file:
        for chunt in iter(lambda: file.read(8126), b''): 
            hash.update(chunk)
    actual_hash=hash.hexdigest()
    expected_hash=subprocess.run(["curl", "-l", f"https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-{latest_version}.tar.sign", "|", "cut", "-d", " ", "-f100"], capture_output=True, text=True, check=True)
    if actual_hash != expected_hash:
        print("Hash is not the same, exitting...")
        return 1
    else:
        print("Hash are the same!")
        return 0