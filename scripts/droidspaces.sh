#!/usr/bin/env bash
# droidspaces.sh — apply kABI fix + append required kernel configs
# usage: source scripts/apply_patch.sh && bash scripts/droidspaces.sh <defconfig_path>
set -e
source "$(dirname "$0")/apply_patch.sh"

DEFCONFIG="${1:?usage: droidspaces.sh <path/to/defconfig>}"

apply_patch \
  "https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/refs/heads/main/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch" \
  "droidspaces_sysvipc_kabi" \
  "1"

cat >> "$DEFCONFIG" << 'EOF'
# Droidspaces support — vili SM8350 (5.4)
# Appended by setup-configs.sh or droidspaces patch step.
# Entries that overlap with setup-configs.sh common block are omitted here.

# IPC
CONFIG_SYSCTL=y
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y

# Namespaces
CONFIG_NAMESPACES=y
CONFIG_PID_NS=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_NET_NS=y

# Seccomp
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y

# Cgroups
CONFIG_CGROUPS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_PIDS=y
CONFIG_MEMCG=y
CONFIG_CGROUP_SCHED=y
CONFIG_FAIR_GROUP_SCHED=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_NET_PRIO=y

# Devtmpfs
CONFIG_DEVTMPFS=y

# Firmware loader
CONFIG_FW_LOADER=y
CONFIG_FW_LOADER_USER_HELPER=y
CONFIG_FW_LOADER_COMPRESS=y

# Overlay + tmpfs (also in setup-configs.sh — harmless duplicate)
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y

# Droidspaces networking (NAT/none modes)
CONFIG_VETH=y
CONFIG_BRIDGE=y
CONFIG_NETFILTER=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_NETFILTER_ADVANCED=y
CONFIG_NF_CONNTRACK=y
CONFIG_NF_CONNTRACK_NETLINK=y
CONFIG_IP_NF_IPTABLES=y
CONFIG_IP_NF_FILTER=y
CONFIG_NF_NAT=y
CONFIG_NF_TABLES=y
CONFIG_IP_NF_TARGET_MASQUERADE=y
CONFIG_NETFILTER_XT_TARGET_MASQUERADE=y
CONFIG_NETFILTER_XT_TARGET_TCPMSS=y
CONFIG_NF_NAT_REDIRECT=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y

# Legacy compat (5.4 still needs these)
CONFIG_NF_CONNTRACK_IPV4=y
CONFIG_NF_NAT_IPV4=y
CONFIG_IP_NF_NAT=y

# UFW / fail2ban core
CONFIG_NETFILTER_XT_MATCH_COMMENT=y
CONFIG_NETFILTER_XT_MATCH_STATE=y
CONFIG_NETFILTER_XT_MATCH_CONNTRACK=y
CONFIG_NETFILTER_XT_MATCH_MULTIPORT=y
CONFIG_NETFILTER_XT_MATCH_HL=y
CONFIG_NETFILTER_XT_TARGET_REJECT=y
CONFIG_IP_NF_TARGET_REJECT=y
CONFIG_NETFILTER_XT_TARGET_LOG=y
CONFIG_IP_NF_TARGET_ULOG=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y
CONFIG_NETFILTER_XT_MATCH_LIMIT=y
CONFIG_NETFILTER_XT_MATCH_HASHLIMIT=y
CONFIG_NETFILTER_XT_MATCH_OWNER=y
CONFIG_NETFILTER_XT_MATCH_PKTTYPE=y
CONFIG_NETFILTER_XT_MATCH_MARK=y
CONFIG_NETFILTER_XT_TARGET_MARK=y
CONFIG_NETFILTER_NETLINK_QUEUE=y
CONFIG_NETFILTER_NETLINK_LOG=y
CONFIG_NETFILTER_XT_TARGET_NFLOG=y

# Disable Android network restrictions for Droidspaces
# blanket disable — per-app restrictions via iptables/nftables handle isolation
CONFIG_ANDROID_PARANOID_NETWORK=n
EOF

echo "droidspaces: done"
