#!/bin/bash
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "=========================================="
echo "执行自定义优化脚本 (diy-part2.sh)"
echo "=========================================="

# ---------------------------------------------------------
# 1. 升级核心编译链 (Golang 26.x 与 SmartDNS)
# ---------------------------------------------------------
echo ">>> 升级 Golang 编译链至 26.x，杜绝 daed 编译期 unknown simd 错误..."
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 升级 SmartDNS 为官方最新源码
rm -rf feeds/packages/net/smartdns feeds/luci/applications/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns.git feeds/packages/net/smartdns
git clone --depth=1 https://github.com/pymumu/luci-app-smartdns.git feeds/luci/applications/luci-app-smartdns

# ---------------------------------------------------------
# 2. 清理官方冲突组件并统一加载 small 源
# ---------------------------------------------------------
echo ">>> 清洗官方旧版冲突组件并挂载 small 源..."
rm -rf feeds/packages/net/daed feeds/packages/net/dae feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-daed feeds/luci/applications/luci-app-daede feeds/luci/applications/luci-app-mosdns
rm -rf package/feeds/packages/daed package/feeds/packages/dae package/feeds/packages/mosdns
rm -rf package/feeds/luci/luci-app-daed package/feeds/luci/luci-app-daede package/feeds/luci/luci-app-mosdns
rm -rf package/openwrt-daede package/custom/luci-app-daede package/daed package/luci-app-daed

# 更新并安装 small 源包
./scripts/feeds update small
./scripts/feeds install -a -p small
./scripts/feeds install -a

# 清理遗留的老版 luci-app-dae (避免 geoip 依赖告警)
find feeds/ package/ -type d -name "luci-app-dae" 2>/dev/null | xargs rm -rf 2>/dev/null || true

# ---------------------------------------------------------
# 2.1 加固 mt_wifi 驱动编译参数 (剔除 -Werror 防止 6.6 内核报错中断)
# ---------------------------------------------------------
echo ">>> 正在加固 mt_wifi 驱动编译参数..."
find package/mtk/drivers/mt_wifi/ -type f \( -name "Makefile*" -o -name "*.mk" \) 2>/dev/null | while read -r f; do
    sed -i 's/-Werror//g' "$f"
    sed -i 's/EXTRA_CFLAGS += -Werror/EXTRA_CFLAGS += -Wno-error/g' "$f"
    sed -i 's/WERROR=1/WERROR=0/g' "$f"
done

# ---------------------------------------------------------
# 3. 双重拦截：关闭 Ruby YJIT，跳过 rust/host 漫长编译
# ---------------------------------------------------------
echo ">>> 执行双重拦截：关闭 Ruby YJIT，跳过 rust/host 编译..."
for conf in .config *.config; do
    if [ -f "$conf" ]; then
        sed -i '/CONFIG_RUBY_ENABLE_YJIT/d' "$conf"
        echo "# CONFIG_RUBY_ENABLE_YJIT is not set" >> "$conf"
    fi
done

RUBY_MK=$(find feeds package -name "Makefile" -path "*/lang/ruby/Makefile" 2>/dev/null | head -n 1)
if [ -f "$RUBY_MK" ]; then
    sed -i '/config RUBY_ENABLE_YJIT/,/help/{s/default y.*/default n/g}' "$RUBY_MK"
    sed -i 's/RUBY_ENABLE_YJIT:rust\/host//g' "$RUBY_MK" 2>/dev/null || true
    echo "✅ 已斩断 Ruby 对 Rust 的依赖链"
fi

# ---------------------------------------------------------
# 4. libxcrypt 编译参数加固
# ---------------------------------------------------------
XCRYPT_MK=$(find feeds package -name "Makefile" -path "*/libxcrypt/Makefile" 2>/dev/null | head -n 1)
if [ -n "$XCRYPT_MK" ] && [ -f "$XCRYPT_MK" ]; then
    sed -i 's/CONFIGURE_ARGS[ \t]*+=[ \t]*/&--disable-werror /' "$XCRYPT_MK"
    sed -i 's/TARGET_CFLAGS[ \t]*+=[ \t]*/&-fcommon /' "$XCRYPT_MK"
    echo "✅ libxcrypt 参数注入完成"
fi

# ---------------------------------------------------------
# 5. 菜单归类调整
# ---------------------------------------------------------
TS_DIR=$(find feeds package -type d -name "luci-app-tailscale-community" 2>/dev/null | head -n 1)
if [ -n "$TS_DIR" ]; then
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's|admin/services/tailscale|admin/vpn/tailscale|g' {} +
    find "$TS_DIR" -type f -name "*.json" -exec sed -i 's/"parent": "luci.services"/"parent": "luci.vpn"/g' {} +
    echo "✅ Tailscale 菜单已移动到 VPN"
fi

KSMBD_DIR=$(find feeds package -type d -name "luci-app-ksmbd" 2>/dev/null | head -n 1)
if [ -n "$KSMBD_DIR" ]; then
    find "$KSMBD_DIR" -type f -exec sed -i 's|admin/services/ksmbd|admin/nas/ksmbd|g' {} +
    find "$KSMBD_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ KSMBD 菜单已移动到 NAS"
fi

OPENLIST2_DIR=$(find feeds package -type d -name "luci-app-openlist2" 2>/dev/null | head -n 1)
if [ -n "$OPENLIST2_DIR" ]; then
    find "$OPENLIST2_DIR" -type f -exec sed -i 's|admin/services/openlist2|admin/nas/openlist2|g' {} +
    find "$OPENLIST2_DIR" -type f -exec sed -i 's/"parent": "luci.services"/"parent": "luci.nas"/g' {} +
    echo "✅ OpenList2 菜单已移动到 NAS"
fi

# ---------------------------------------------------------
# 6. 系统参数与网络优化（sysctl）及默认后台 IP
# ---------------------------------------------------------
mkdir -p files/etc/sysctl.d/
cat > files/etc/sysctl.d/99-proxy-optimize.conf << 'SYSCTL'
net.netfilter.nf_conntrack_max=32768
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=120
net.core.netdev_max_backlog=2048
net.core.somaxconn=2048
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_tw_buckets=8192
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.udp_mem=8192 12288 16384
net.ipv4.ip_local_port_range=1024 65535
SYSCTL

sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate 2>/dev/null || true

# ---------------------------------------------------------
# 7. Filogic 6.6 内核精简注入 eBPF/BTF
# ---------------------------------------------------------
find target/linux/mediatek/ -name "config-6.6" 2>/dev/null | while read -r kernel_config; do
    sed -i '/CONFIG_DEBUG_INFO/d' "$kernel_config"
    sed -i '/CONFIG_BPF/d' "$kernel_config"
    cat <<EOF >> "$kernel_config"
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_EVENTS=y
CONFIG_NET_ACT_BPF=y
CONFIG_NET_CLS_ACT=y
CONFIG_CGROUP_BPF=y
CONFIG_DEBUG_INFO_BTF=y
EOF
done

# ---------------------------------------------------------
# 8. 追加正确包名与顶层内核参数
# ---------------------------------------------------------
echo ">>> 正在更新 .config 关键项..."
cat <<EOF >> .config
# Daed 与 eBPF 核心 (满足 small 依赖)
CONFIG_PACKAGE_luci-app-daede=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_kmod-vmlinux-btf=y

# 强制打包离线 GeoIP / GeoSite 数据库与证书
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y
CONFIG_PACKAGE_ca-bundle=y

# 常用核心插件 (由 small 源提供)
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-mosdns=y
CONFIG_PACKAGE_luci-app-lucky=y

# Momo 及其 Sing-box 核心
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_momo=y
CONFIG_PACKAGE_sing-box=y

# Clashoo 前端、守护服务及其 Mihomo 核心
CONFIG_PACKAGE_luci-app-clashoo=y
CONFIG_PACKAGE_clashoo=y
CONFIG_PACKAGE_mihomo=y

# 仅开启内核原生生成 BTF 的关键项
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_KERNEL_DEBUG_INFO_BTF=y
EOF

# 刷新并生成最终依赖树
make defconfig

echo "=========================================="
echo "自定义优化脚本执行完毕！"
echo "=========================================="
