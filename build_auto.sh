#!/bin/bash
set -e
#========== 唯一需要改的地方 ==========
OPENWRT_BRANCH="24.10.2"          # 22.03 / 23.05 / 24.10 均可
KuCat_Version="2.6.15"
#=====================================
ROOT="$HOME/kucat-4arch-${OPENWRT_BRANCH//./}"
OUT="$ROOT/bin/all-archs"
mkdir -p "$OUT"

command -v curl &>/dev/null || { echo "❌ 请先安装 curl"; exit 1; }
command -v zstd &>/dev/null || sudo apt-get install -y zstd

download_sdk() {
  local arch=$1 tgt=$2 sub=$3
  local urls=(
    "https://downloads.openwrt.org/releases/${OPENWRT_BRANCH}/targets/${tgt}/${sub}/"
    "https://mirror-03.infra.openwrt.org/releases/${OPENWRT_BRANCH}/targets/${tgt}/${sub}/"
  )
  local html="" url=""
  for u in "${urls[@]}"; do
    echo ">>> 尝试抓取 $u" >&2          # ← 改到标准错误
    html=$(curl -sL -f "$u" 2>&1) && { url="$u"; break; } || continue
  done
  [[ -n $html ]] || { echo "❌ 所有 mirror 均无法访问" >&2; exit 1; }

  local sdk_file
  sdk_file=$(echo "$html" | \
    grep -oE 'href="(openwrt-sdk-[^"]+\.Linux-x86_64\.tar\.(xz|zst))"' | \
    head -1 | sed 's/href="//;s/"//' | xargs)
  [[ -n $sdk_file ]] || { echo "❌ 未解析到 SDK 文件名" >&2; exit 1; }
  echo ">>> 解析到：$sdk_file" >&2      # ← 改到标准错误
  echo "$url$sdk_file"                 # ← 仅标准输出返回纯 URL
}

# 4 个靶机
declare -A TARGET_MAP=(
  [x86_64]="x86/64"
  [mediatek]="mediatek/filogic"
)

for arch in "${!TARGET_MAP[@]}"; do
  echo "==========  $arch (branch ${OPENWRT_BRANCH})  =========="
  cd "$ROOT"
  SDK_URL=$(download_sdk "$arch" ${TARGET_MAP[$arch]})
  tarfile=$(basename "$SDK_URL")

  [[ -f $tarfile ]] || curl -L -C - -o "$tarfile" "$SDK_URL"

  if [[ $(stat -c%s "$tarfile") -lt 1048576 ]]; then
    echo "❌ $tarfile 过小，可能 404"; exit 1; fi

  dir="sdk-$arch"
  mkdir -p "$dir"
case "$tarfile" in
  *.tar.xz)  tar -xf "$tarfile" --strip=1 -C "$dir" ;;
  *.tar.zst) tar --use-compress-program=unzstd -xf "$tarfile" --strip=1 -C "$dir" ;;
  *) echo "未知压缩格式"; exit 1 ;;
esac
  cd "$dir"

  ./scripts/feeds update -a
  ./scripts/feeds install -a
  [[ -d package/luci-theme-kucat ]] || \
    git clone --depth 1 https://github.com/KuwiNet/KuCat.git package/luci-theme-kucat

  make defconfig
  sed -i 's/# CONFIG_PACKAGE_luci-theme-kucat is not set/CONFIG_PACKAGE_luci-theme-kucat=m/' .config
  make defconfig

  make package/luci-theme-kucat/compile V=s -j$(nproc)
  cp bin/packages/*/base/luci-theme-kucat_*.ipk "$OUT/luci-theme-kucat-${KuCat_Version}-$arch.ipk"
done

echo "====== 4 架构完成 ======"
ls -lh "$OUT"/*.ipk
