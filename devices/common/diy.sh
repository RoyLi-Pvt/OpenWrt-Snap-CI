#!/bin/bash
#=================================================
shopt -s extglob
kernel_version="$(curl -sfL https://github.com/openwrt/openwrt/commits/master/include/kernel-version.mk | grep -o 'href=".*>kernel: bump 5.10' | head -1 | cut -d / -f 5 | cut -d "#" -f 1)"
version="$(git rev-parse HEAD)"
git checkout $kernel_version
git checkout HEAD^
mv -f target/linux package/kernel include/kernel-version.mk include/kernel-defaults.mk .github/
git checkout $version
rm -rf target/linux package/kernel include/kernel-version.mk include/kernel-defaults.mk
mv -f .github/linux target/
mv -f .github/kernel package/
mv -f .github/kernel-version.mk .github/kernel-defaults.mk include/
sed -i 's/ libelf//' tools/Makefile

sed -i '/	refresh_config();/d' scripts/feeds
[ ! -f feeds.conf ] && {
sed -i '$a src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git;master' feeds.conf.default
}

./scripts/feeds update -a
./scripts/feeds install -a -p kiddin9
./scripts/feeds install -a
cd feeds/kiddin9; git pull; cd -

(
svn export --force https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/network/services/ppp package/network/services/ppp
svn export --force https://github.com/immortalwrt/immortalwrt/branches/openwrt-21.02/package/network/services/dnsmasq package/network/services/dnsmasq
svn export --force https://github.com/coolsnowwolf/lede/trunk/tools/upx tools/upx
svn export --force https://github.com/coolsnowwolf/lede/trunk/tools/ucl tools/ucl
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic/hack-5.10 target/linux/generic/hack-5.10
rm -rf target/linux/generic/hack-5.10/{220-gc_sections*,781-dsa-register*}
curl -sfL https://git.io/J0klM --create-dirs -o package/network/config/firewall/patches/fullconenat.patch
) &

sed -i 's?zstd$?zstd ucl upx\n$(curdir)/upx/compile := $(curdir)/ucl/compile?g' tools/Makefile
sed -i 's/\/cgi-bin\/\(luci\|cgi-\)/\/\1/g' `find package/feeds/kiddin9/luci-*/ -name "*.lua" -or -name "*.htm*" -or -name "*.js"` &
sed -i 's/Os/O2/g' include/target.mk
sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite/' package/Makefile
sed -i "/mediaurlbase/d" package/feeds/*/luci-theme*/root/etc/uci-defaults/*
sed -i '/root:/c\root:$1$tTPCBw1t$ldzfp37h5lSpO9VXk4uUE\/:18336:0:99999:7:::' package/base-files/files/etc/shadow
sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf
sed -i -e '$a /etc/bench.log' \
       -e '/\/etc\/profile/d' \
       -e '/\/etc\/shinit/d' \
       package/base-files/files/lib/upgrade/keep.d/base-files-essential
sed -i -e '/^\/etc\/profile/d' \
       -e '/^\/etc\/shinit/d' \
       package/base-files/Makefile
# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i '$a CONFIG_ACPI=y\nCONFIG_X86_ACPI_CPUFREQ=y\nCONFIG_NR_CPUS=128\nCONFIG_FAT_DEFAULT_IOCHARSET="utf8"\nCONFIG_CRYPTO_CHACHA20_NEON=y\n \
CONFIG_CRYPTO_CHACHA20POLY1305=y\nCONFIG_BINFMT_MISC=y' `find target/linux -path "target/linux/*/config-*"`
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
#rm -rf ./feeds/packages/lang/{golang,node}
sed -i 's?admin/status/channel_analysis??' package/feeds/luci/luci-mod-status/root/usr/share/luci/menu.d/luci-mod-status.json
sed -i "s/tty1::askfirst/tty1::respawn/g" target/linux/*/base-files/etc/inittab
date=`date +%m.%d.%Y`
sed -i "/DISTRIB_DESCRIPTION/c\DISTRIB_DESCRIPTION=\"%D %C by RoyLi\"" package/base-files/files/etc/openwrt_release
sed -i "/CONFIG_VERSION_CODE=/c\CONFIG_VERSION_CODE=\"$date\"" devices/common/.config
sed -i '$a cgi-timeout = 300' package/feeds/packages/uwsgi/files-luci-support/luci-*.ini
sed -i '/limit-as/c\limit-as = 5000' package/feeds/packages/uwsgi/files-luci-support/luci-webui.ini
sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk
sed -i 's/ +kmod-thermal//' package/kernel/mt76/Makefile

sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/kiddin9/*/Makefile

(
if [ -f sdk.tar.xz ]; then
	sed -i 's,$(STAGING_DIR_HOST)/bin/upx,upx,' package/feeds/kiddin9/*/Makefile
	mkdir sdk
	tar -xJf sdk.tar.xz -C sdk
	cp -rf sdk/*/staging_dir/* ./staging_dir/
	rm -rf sdk.tar.xz sdk
	rm -rf `find "staging_dir/host/" -maxdepth 2 -name 'libelf*'` || true
	sed -i '/\(tools\|toolchain\)\/Makefile/d' Makefile
	if [ -f /usr/bin/python ]; then
		ln -sf /usr/bin/python staging_dir/host/bin/python
	else
		ln -sf /usr/bin/python3 staging_dir/host/bin/python
	fi
	ln -sf /usr/bin/python3 staging_dir/host/bin/python3
fi
) &
