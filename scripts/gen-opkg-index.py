#!/usr/bin/env python3
"""生成 OpenWrt opkg 软件源索引（Packages / Packages.gz / Packages.manifest）。

用法: python3 gen-opkg-index.py <feed_dir>
遍历 <feed_dir> 下所有 .ipk，从每个包的 control 提取元信息，结合文件
Size / SHA256sum / MD5Sum，生成 opkg 可识别的索引文件。
"""
import os
import sys
import gzip
import io
import tarfile
import hashlib


def read_control(ipk_path):
    """从 ipk 读取 ./control（兼容 SDK 产物的 gzip-tar 外层）。"""
    with open(ipk_path, "rb") as f:
        data = f.read()
    inner = gzip.decompress(data)
    tf = tarfile.open(fileobj=io.BytesIO(inner))
    ctl_raw = gzip.decompress(tf.extractfile("./control.tar.gz").read())
    ctf = tarfile.open(fileobj=io.BytesIO(ctl_raw))
    return ctf.extractfile("./control").read().decode("utf-8", "replace")


def parse_control(text):
    d = {}
    for line in text.splitlines():
        line = line.rstrip()
        if not line or line.startswith(" "):
            continue
        if ":" in line:
            k, v = line.split(":", 1)
            d[k.strip()] = v.strip()
    return d


def main(feed_dir):
    ipks = sorted(f for f in os.listdir(feed_dir) if f.endswith(".ipk"))
    if not ipks:
        print("no .ipk found in", feed_dir)
        sys.exit(1)
    blocks = []
    for ipk in ipks:
        path = os.path.join(feed_dir, ipk)
        ctl = parse_control(read_control(path))
        with open(path, "rb") as f:
            blob = f.read()
        size = len(blob)
        sha = hashlib.sha256(blob).hexdigest()
        md5 = hashlib.md5(blob).hexdigest()
        lines = [
            "Package: " + ctl.get("Package", ""),
            "Version: " + ctl.get("Version", ""),
            "Depends: " + ctl.get("Depends", ""),
            "Status: unknown ok not-installed",
            "Architecture: " + ctl.get("Architecture", ""),
            "Installed-Size: " + ctl.get("Installed-Size", "0"),
            "Filename: " + ipk,
            "Size: " + str(size),
            "SHA256sum: " + sha,
            "MD5Sum: " + md5,
            "Section: " + ctl.get("Section", "luci"),
            "Priority: optional",
            "Maintainer: " + ctl.get("Maintainer", ""),
            "Description: " + ctl.get("Description", "").strip(),
        ]
        blocks.append("\n".join(lines))
    pkg_text = "\n\n".join(blocks) + "\n"
    with open(os.path.join(feed_dir, "Packages"), "w", encoding="utf-8") as f:
        f.write(pkg_text)
    with open(os.path.join(feed_dir, "Packages.gz"), "wb") as f:
        f.write(gzip.compress(pkg_text.encode("utf-8"), 9))
    with open(os.path.join(feed_dir, "Packages.manifest"), "w", encoding="utf-8") as f:
        f.write(pkg_text)
    print("indexed %d package(s) in %s" % (len(ipks), feed_dir))


if __name__ == "__main__":
    main(sys.argv[1])
