#!/bin/bash
set -ex

#========== 唯一需要改的地方 ==========
OPENWRT_BRANCH="24.10.2"          # 22.03 / 23.05 / 24.10 均可
KuCat_Version="2.6.15"
#=====================================
ROOT="$HOME/kucat-auto-${OPENWRT_BRANCH//./}"
OUT="$ROOT/bin/all-archs"
mkdir -p "$OUT"

# 切换到工作目录
cd "$ROOT"

# 安装依赖（如果已经安装就跳过）
echo "========== 检查依赖 =========="
if ! command -v curl &>/dev/null; then
    echo "❌ 请先安装 curl"
    exit 1
else
    echo "✅ curl 已安装"
fi

if ! command -v zstd &>/dev/null; then
    echo ">>> 安装 zstd..."
    sudo apt-get install -y zstd
else
    echo "✅ zstd 已安装"
fi

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

# 预先下载所有需要的SDK
declare -A SDK_URLS
for arch in "${!TARGET_MAP[@]}"; do
  echo "========== 处理 $arch SDK =========="
  SDK_URL=$(download_sdk "$arch" ${TARGET_MAP[$arch]})
  SDK_URLS["$arch"]="$SDK_URL"
  tarfile=$(basename "$SDK_URL")

  # 检查SDK文件是否已经存在且大小正常
  if [[ -f "$tarfile" ]]; then
    local file_size=$(stat -c%s "$tarfile")
    if [[ $file_size -gt 1048576 ]]; then
      echo "✅ $arch SDK 已存在且大小正常 ($((file_size/1024/1024))MB)，跳过下载"
      continue
    else
      echo "⚠️  $arch SDK 文件过小 ($((file_size/1024))KB)，重新下载..."
      rm -f "$tarfile"
    fi
  fi

  echo ">>> 下载 $arch SDK..."
  curl -L -C - -o "$tarfile" "$SDK_URL"

  # 再次检查文件大小
  if [[ $(stat -c%s "$tarfile") -lt 1048576 ]]; then
    echo "❌ $tarfile 过小，可能 404"; exit 1
  fi
done

# 处理主题包（每次都更新）
echo "========== 处理主题包 =========="
if [[ -d "kucat-theme" ]]; then
  echo ">>> 更新主题包..."
  cd "kucat-theme"
  git pull origin js
  cd "$ROOT"
else
  echo ">>> 克隆主题包..."
  git clone --depth 1 -b js https://github.com/KuwiNet/KuCat.git "kucat-theme"
fi

echo "✅ 主题包已更新到最新版本"

# 开始编译每个架构
for arch in "${!TARGET_MAP[@]}"; do
  echo "========== 编译 $arch (branch ${OPENWRT_BRANCH}) =========="
  
  tarfile=$(basename "${SDK_URLS[$arch]}")
  dir="sdk-$arch"
  
  # 确保我们在正确的目录
  cd "$ROOT"
  
  # 解压SDK（如果目录不存在）
  if [[ ! -d "$dir" ]]; then
    echo ">>> 解压 $arch SDK..."
    mkdir -p "$dir"
    case "$tarfile" in
      *.tar.xz)  tar -xf "$tarfile" --strip=1 -C "$dir" ;;
      *.tar.zst) tar --use-compress-program=unzstd -xf "$tarfile" --strip=1 -C "$dir" ;;
      *) echo "未知压缩格式"; exit 1 ;;
    esac
    echo "✅ $arch SDK 解压完成"
  else
    echo "✅ $arch SDK 已解压，跳过"
  fi
  
  cd "$dir"

  # 更新feeds（只运行一次）
  if [[ ! -f .feeds_updated ]]; then
    echo ">>> 更新feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    touch .feeds_updated
    echo "✅ feeds 更新完成"
  else
    echo "✅ feeds 已更新，跳过"
  fi
  
  # 复制主题包（每次都使用最新的）
  echo ">>> 复制最新主题包..."
  rm -rf package/luci-theme-kucat
  cp -r "$ROOT/kucat-theme/luci-theme-kucat" package/

  # 配置和编译
  if [[ ! -f .config ]]; then
    echo ">>> 生成配置..."
    make defconfig
    sed -i 's/# CONFIG_PACKAGE_luci-theme-kucat is not set/CONFIG_PACKAGE_luci-theme-kucat=m/' .config
    make defconfig
    echo "✅ 配置完成"
  else
    echo "✅ 配置已存在，跳过"
  fi

  echo ">>> 开始编译..."
  make package/luci-theme-kucat/compile V=s -j$(nproc)
  cp bin/packages/*/base/luci-theme-kucat_*.ipk "$OUT/luci-theme-kucat-${KuCat_Version}-$arch.ipk"
  
  echo "✅ $arch 编译完成"
done

# 编译完成后删除主题包
echo "========== 清理工作 =========="
if [[ -d "$ROOT/kucat-theme" ]]; then
  echo ">>> 删除主题包目录..."
  rm -rf "$ROOT/kucat-theme"
  echo "✅ 主题包已删除"
fi

echo "====== 所有架构编译完成 ======"
ls -lh "$OUT"/*.ipk
