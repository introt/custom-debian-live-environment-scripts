# custom-debian-live-environment-scripts
Scripts for easy custom Debian live environment creation (WIP)

Based on Will Haley's article [Create a Custom Debian Live Environment (CD or USB)](https://willhaley.com/blog/custom-debian-live-environment/)

## How to use

All scripts have "--help" option describing usage and available options.

### Usage example: from zero to ISO

Assuming the scripts are in the current directory and you're using a Debian based distribution (tested on Ubuntu 16.04), you should be able to create your first ISO in N steps:

1. '# ./chrootbootstrapper.sh --install-dependencies' installs the needed packages via apt-get

2. '# ./chrootbootstrapper.sh -n rebiandemix-live -d /root/rebiandemix' creates a base Debian environment. Please use '-m' or '--mirror' to specify a mirror if you are not in the United States or if you know of a mirror closer to you. You can find the list of Debian mirrors from [here](https://www.debian.org/mirror/list).

3. Chroot to your newly-created Debian environment: '# chroot /root/rebiandemix'

4. **Inside the chroot:** Install a kernel: '# apt update && apt install linux-image-amd64' *Note: the default arch is amd64. See chrootbootstrapper.sh --help for setting a different arch.* **TODO: why isn't this automated in chrootbootstrapper.sh??**

5. **Inside the chroot:** Set a root password: '# passwd'

6. **Inside the chroot:** Now it'd be time for customization, but we don't cover that here: exit the chroot with 'exit'

7. '# ./chroot2iso.sh -d /root/rebiandemix -n "Rebian Demix" -o rebiandemix.iso' will turn the chroot into an ISO. Done and done.

If you followed this far, you should now have an ISO image at '/root/rebiandemix/rebiandemix.iso.' You can test the iso without burning it to a CD with QEMU (apt install qemu): 'qemu-system-x86_64 -cdrom rebiandemix.iso -m 1G'. You should see something like this:

![Rebian Demix bootloader in QEMU](https://raw.githubusercontent.com/masakoodaa/custom-debian-live-environment-scripts/master/screenshots/qemu-1.png "Rebian Demix bootloader in QEMU")

![Logged in as root in the live environment](https://raw.githubusercontent.com/masakoodaa/custom-debian-live-environment-scripts/master/screenshots/qemu-2.png "Logged in as root in the live environment")
