#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

mkdir -p package/custom

# ================= 引入 kenzok8/small 源 (集成 daed/dae 核心与依赖链) =================
sed -i '/small/d' feeds.conf.default
echo "src-git small https://github.com/kenzok8/small.git;master" >> feeds.conf.default

# ================= 常用插件 (独立克隆) =================
# AdGuardHome
git clone --depth=1 https://github.com/rufengsuixing/luci-app-adguardhome.git package/custom/luci-app-adguardhome

# Momo (Nikki 原生轻量版)
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo.git package/custom/momo

# Lucky
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom/lucky

# Mosdns 与配套 Geodata (独立 v5 分支)
git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns.git package/custom/mosdns
git clone --depth=1 https://github.com/sbwml/v2ray-geodata.git package/custom/v2ray-geodata

# vmlinux-btf 补丁
git clone --depth=1 https://github.com/QiuSimons/vmlinux-btf.git package/custom/vmlinux-btf

# ================= 主题 =================
git clone --depth=1 -b openwrt-25.12 https://github.com/sbwml/luci-theme-argon.git package/custom/luci-theme-argon
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora.git package/custom/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config.git package/custom/luci-app-aurora-config
git clone --depth=1 https://github.com/sirpdboy/luci-theme-kucat.git package/custom/luci-theme-kucat
git clone --depth=1 https://github.com/sirpdboy/luci-app-kucat-config.git package/custom/luci-app-kucat-config
