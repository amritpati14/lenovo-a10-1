cmd_/home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/netfilter_ipv6/.install := perl scripts/headers_install.pl /home/durand/projects/public/lenovo-a10/kernels/linux-3.0.36/include/linux/netfilter_ipv6 /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/netfilter_ipv6 arm ip6_tables.h ip6t_HL.h ip6t_LOG.h ip6t_REJECT.h ip6t_ah.h ip6t_frag.h ip6t_hl.h ip6t_ipv6header.h ip6t_mh.h ip6t_opts.h ip6t_rt.h; perl scripts/headers_install.pl /home/durand/projects/public/lenovo-a10/kernels/linux-3.0.36/include/linux/netfilter_ipv6 /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/netfilter_ipv6 arm ; for F in ; do echo "\#include <asm-generic/$$F>" > /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/netfilter_ipv6/$$F; done; touch /home/durand/projects/public/lenovo-a10/initramfs/usr//include/linux/netfilter_ipv6/.install
