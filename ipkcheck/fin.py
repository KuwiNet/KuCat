import tarfile, io, gzip
def parse_ar(data):
    # handle both !<arch> and BSD-style ar
    if data[:8]==b'!<arch>\n':
        off=8
    else:
        off=0
    members={}
    while off+60<=len(data):
        name=data[off:off+16].decode().strip().rstrip('/')
        # BSD ar uses '#1/123' long name or blank; skip blank pads
        if not name:
            break
        try:
            size=int(data[off+48:off+58].decode().strip())
        except:
            break
        off+=60
        members[name]=data[off:off+size]
        off+= size + (0 if size%2==0 else 1)
    return members
b=open('theme.ipk','rb').read()
m=parse_ar(b)
print('ar members:', list(m.keys()))
if 'data.tar.gz' in m:
    tf=tarfile.open(fileobj=io.BytesIO(gzip.decompress(m['data.tar.gz'])))
    names=tf.getnames()
    print('total files in data:', len(names))
    print('--- files under /www/luci-static/kucat/fonts ---')
    for n in names:
        if '/fonts/' in n or n.endswith('.ttf') or n.endswith('.woff') or n.endswith('.woff2') or 'kucat.' in n:
            info=tf.getmember(n)
            print('  %-80s %s' % (n, info.size))
    print('--- any name containing kucat ---')
    for n in names:
        if 'kucat' in n.lower():
            print('  ', n)
