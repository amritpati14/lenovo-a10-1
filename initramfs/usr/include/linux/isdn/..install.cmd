cmd_/home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/isdn/.install := perl scripts/headers_install.pl /home/durand/projects/public/lenovo-a10/kernels/linux-3.0.36/include/linux/isdn /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/isdn arm capicmd.h; perl scripts/headers_install.pl /home/durand/projects/public/lenovo-a10/kernels/linux-3.0.36/include/linux/isdn /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/isdn arm ; for F in ; do echo "\#include <asm-generic/$$F>" > /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/isdn/$$F; done; touch /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/isdn/.install
