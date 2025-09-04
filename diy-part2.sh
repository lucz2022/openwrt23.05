#!/bin/bash
# ================================================
# diy-part2.sh  —— OpenWrt 二次配置（feeds 安装后执行）
# 1) 锁定 x86_64
# 2) 禁用 mosdns
# 3) 禁用 shadowsocks-libev 全家（避免 PCRE1 依赖链）
# 4) 启用 ucode / ucode-mod-digest
# 5) make defconfig 展开依赖
# 6) 守卫：检查是否误拉回 ss-libev（默认只告警；STRICT_GUARD=1 时中断）
# ================================================

set -eux

# 如果当前目录不是 openwrt/，且存在 openwrt/ 目录，则切进去
[ -d openwrt ] && cd openwrt

# 确保存在 .config（如果你在上一步把 openwrt.config 拷到 openwrt/.config，这里就会直接用）
[ -f .config ] || touch .config

echo "[diy2] Lock target to x86_64"
# 1) 只保留 x86_64 目标，清理历史目标项
sed -i '/^CONFIG_TARGET_/d' .config
cat >> .config <<'EOF'
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
EOF

echo "[diy2] Disable mosdns and its menu include"
# 2) 关闭 mosdns（部分环境会编译失败）
sed -i '/^CONFIG_PACKAGE_mosdns[ =]/d;/^CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_MosDNS[ =]/d' .config
cat >> .config <<'EOF'
# CONFIG_PACKAGE_mosdns is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_MosDNS is not set
EOF

echo "[diy2] Hard-disable shadowsocks-libev family to avoid PCRE1 chain"
# 3) 明确禁用 SS-libev（不要和 SSRR 混淆）
sed -i '/^CONFIG_PACKAGE_shadowsocks-libev/d;/^CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_/d' .config
cat >> .config <<'EOF'
# CONFIG_PACKAGE_shadowsocks-libev-config is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-local is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-redir is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-rules is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-server is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-tunnel is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Server is not set
EOF

echo "[diy2] Ensure ucode & ucode-mod-digest present"
# 4) 一些插件（如 homeproxy 等）需要 ucode + ucode-mod-digest
sed -i '/^CONFIG_PACKAGE_ucode/d;/^CONFIG_PACKAGE_ucode-mod-digest/d' .config
cat >> .config <<'EOF'
CONFIG_PACKAGE_ucode=y
CONFIG_PACKAGE_ucode-mod-digest=y
EOF

# 5) 展开依赖
echo "[diy2] make defconfig..."
make defconfig
# ==== 你的 defconfig 之后，追加一个“二次清理 + 卸载”守卫 ====

echo "[diy2] Post-defconfig hard guards"

# 1) 把 ss-libev 全家从最终结果里踢掉（避免 pcre1 链）
./scripts/feeds uninstall shadowsocks-libev || true
sed -i '
/^CONFIG_PACKAGE_shadowsocks-libev-/d
/^CONFIG_PACKAGE_shadowsocks-libev[ =]/d
/^CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_/d
' .config
cat >> .config <<'EOF'
# CONFIG_PACKAGE_shadowsocks-libev-config is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-local is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-redir is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-rules is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-server is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-tunnel is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Server is not set
EOF

# 2) 关 MosDNS（23.05/24.10 都见过编译炸）
./scripts/feeds uninstall mosdns luci-app-mosdns || true
sed -i '
/^CONFIG_PACKAGE_mosdns[ =]/d
/^CONFIG_PACKAGE_luci-app-mosdns[ =]/d
/^CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_MosDNS[ =]/d
' .config
cat >> .config <<'EOF'
# CONFIG_PACKAGE_mosdns is not set
# CONFIG_PACKAGE_luci-app-mosdns is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_MosDNS is not set
EOF

# 3) 继续禁用会触发 Rust 的包（双保险）
./scripts/feeds uninstall ripgrep bottom dns2socks-rust python-cryptography python-bcrypt || true
sed -i '
/^CONFIG_PACKAGE_ripgrep[ =]/d
/^CONFIG_PACKAGE_bottom[ =]/d
/^CONFIG_PACKAGE_dns2socks-rust[ =]/d
/^CONFIG_PACKAGE_python3-cryptography[ =]/d
/^CONFIG_PACKAGE_python3-bcrypt[ =]/d
' .config
cat >> .config <<'EOF'
# CONFIG_PACKAGE_ripgrep is not set
# CONFIG_PACKAGE_bottom is not set
# CONFIG_PACKAGE_dns2socks-rust is not set
# CONFIG_PACKAGE_python3-cryptography is not set
# CONFIG_PACKAGE_python3-bcrypt is not set
EOF

# 4) 如果你只要 Xray + SSRR（而非 SS-libev），确保这两个依赖开启
grep -q '^CONFIG_PACKAGE_xray-core=y' .config || echo 'CONFIG_PACKAGE_xray-core=y' >> .config
grep -q '^CONFIG_PACKAGE_shadowsocksr-libev-ssr-local=y' .config || echo 'CONFIG_PACKAGE_shadowsocksr-libev-ssr-local=y' >> .config
grep -q '^CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir=y' .config || echo 'CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir=y' >> .config
grep -q '^CONFIG_PACKAGE_luci-app-ssr-plus=y' .config || echo 'CONFIG_PACKAGE_luci-app-ssr-plus=y' >> .config
grep -q '^CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y' .config || echo 'CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y' >> .config

# 5) 再 defconfig 一次，让依赖闭合
make defconfig

# 6) 显式校验：如果 ss-libev 还被某 feed 联动拉回，直接报警（不中断）
if grep -R -E '(^| )PACKAGE_shadowsocks-libev' tmp/.config-package.in | grep -qv 'is not set'; then
  echo "[diy2][WARNING] shadowsocks-libev **已被启用**，很可能被某个面板(feed)联动拉入。"
  echo "[diy2][WARNING] 请关闭 passwall/ssr-plus/bypass 中的 INCLUDE_Shadowsocks_Libev* 选项，或移除相应 feed。"
fi

echo "[diy2] Guards done."


# 6) 守卫（检查最终 .config 是否真的启用了 ss-libev；默认仅告警，不中断）
STRICT_GUARD="${STRICT_GUARD:-0}"  # 环境变量设为 1 可改为严格模式
if grep -Eq '^(CONFIG_PACKAGE_shadowsocks-libev(-[a-z0-9_]+)?=y|CONFIG_PACKAGE_shadowsocks-libev(-[a-z0-9_]+)?=m)' .config; then
  echo "[diy2][WARNING] shadowsocks-libev **已被启用**，很可能被某个面板(feed)联动拉入。"
  echo "[diy2][WARNING] 请关闭 passwall/ssr-plus/bypass 中的 INCLUDE_Shadowsocks_Libev* 选项，或移除相应 feed。"
  if [ "$STRICT_GUARD" = "1" ]; then
    echo "[diy2][ERROR] STRICT_GUARD=1，终止构建。"
    exit 1
  fi
fi

echo "[diy2] Done."
