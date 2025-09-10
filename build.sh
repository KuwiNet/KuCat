#!/bin/bash
set -ex

#========== 唯一需要改的地方 ==========
OPENWRT_BRANCH="24.10.2"          # 22.03 / 23.05 / 24.10 均可
KuCat_Version="2.6.15"
#=====================================
ROOT="$HOME/kucat-auto-${OPENWRT_BRANCH//./}"
OUT="$ROOT/bin/all-archs"
mkdir -p "$OUT"

command -v curl &>/dev/null || { echo "❌ 请先安装 curl"; exit 1; }
command -v zstd &>/dev/null || sudo apt-get install -y zstd

# n 个靶机
declare -A TARGET_MAP=(
  [x86_64]="x86/64"
  [mediatek]="mediatek/filogic"
  [rockchip]="rockchip/armv8"
)

# 如果环境变量 ARCH 存在，就用它；否则按原来的 for 循环
if [[ -n "$ARCH" ]]; then
    # 创建一个新的关联数组，只包含指定的架构
    declare -A FILTERED_MAP
    if [[ -n "${TARGET_MAP[$ARCH]}" ]]; then
        FILTERED_MAP["$ARCH"]="${TARGET_MAP[$ARCH]}"
    else
        echo "❌ 未知的架构: $ARCH"
        exit 1
    fi
    # 将 TARGET_MAP 替换为过滤后的版本
    unset TARGET_MAP
    declare -A TARGET_MAP
    for key in "${!FILTERED_MAP[@]}"; do
        TARGET_MAP["$key"]="${FILTERED_MAP[$key]}"
    done
fi

download_sdk() {
  local arch=$1 tgt=$2 sub=$3
  local urls=(
    "https://downloads.openwrt.org/releases/${OPENWRT_BRANCH}/targets/${tgt}/${sub}/"
    "https://mirror-03.infra.openwrt.org/releases/${OPENWRT_BRANCH}/targets/${tgt}/${sub}/"
  )
  local html="" url=""
  for u in "${urls[@]}"; do
    echo ">>> 尝试抓取 $u" >&2
    html=$(curl -sL -f "$u" 2>&1) && { url="$u"; break; } || continue
  done
  [[ -n $html ]] || { echo "❌ 所有 mirror 均无法访问" >&2; exit 1; }

  local sdk_file=$(echo "$html" | \
  grep -oE 'href="(openwrt-sdk-[^"]+Linux-x86_64\.tar\.(xz|zst))"' | \
  head -1 | sed 's/href="//;s/"//' | xargs)
  [[ -n $sdk_file ]] || { echo "❌ 未解析到 SDK 文件名" >&2; exit 1; }
  echo ">>> 解析到：$sdk_file" >&2
  echo "$url$sdk_file"
}

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
  
  # 删除旧的主题包目录（如果存在）
  rm -rf package/luci-theme-kucat
  
  # 克隆主题包（使用js分支）
  git clone --depth 1 -b js https://github.com/KuwiNet/KuCat.git package/luci-theme-kucat

  # 检查字体文件是否存在
  echo "检查字体文件..."
  if [[ -f package/luci-theme-kucat/htdocs/luci-static/kucat/fonts/AlimamaFangYuanTiVF-Thin.ttf ]]; then
    echo "✅ 字体文件存在"
    ls -la package/luci-theme-kucat/htdocs/luci-static/kucat/fonts/
  else
    echo "❌ 字体文件不存在，检查目录结构:"
    find package/luci-theme-kucat -name "*.ttf" -o -name "*.woff" -o -name "*.woff2" | head -10
    exit 1
  fi

  make defconfig
  sed -i 's/# CONFIG_PACKAGE_luci-theme-kucat is not set/CONFIG_PACKAGE_luci-theme-kucat=m/' .config
  make defconfig

  make package/luci-theme-kucat/compile V=s -j$(nproc)
  cp bin/packages/*/base/luci-theme-kucat_*.ipk "$OUT/luci-theme-kucat-${KuCat_Version}-$arch.ipk"
done

echo "====== 架构完成 ======"
ls -lh "$OUT"/*.ipk
