#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

mkdir -p package/custom

# ================= 引入 kenzok8/small 源 =================
# 该源集成托管了 daed、dae、adguardhome、mosdns、momo、lucky 等常用插件与配套依赖
sed -i '/small/d' feeds.conf.default
echo "src-git small https://github.com/kenzok8/small.git;master" >> feeds.conf.default

# ================= 主题 (独立克隆) =================
git clone --depth=1 -b openwrt-25.12 https://github.com/sbwml/luci-theme-argon.git package/custom/luci-theme-argon
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora.git package/custom/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config.git package/custom/luci-app-aurora-config
git clone --depth=1 https://github.com/sirpdboy/luci-theme-kucat.git package/custom/luci-theme-kucat
git clone --depth=1 https://github.com/sirpdboy/luci-app-kucat-config.git package/custom/luci-app-kucat-config
