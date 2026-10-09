import tarfile, io, gzip
def load(p):
    b=open(p,'rb').read()
    if b[:2]==b'\x1f\x8b':
        b=gzip.decompress(b)
        open(p+'.ar','wb').write(b)
    return b
def parse_ar(data):
    off=8 if data[:8]==b'!<arch>\n' else 0
    members={}
    while off+60<=len(data):
        name=data[off:off+16].decode('ascii','replace').strip().rstrip('/')
        if not name: break
        try: size=int(data[off+48:off+58].decode().strip())
        except: break
        off+=60
        members[name]=data[off:off+size]
        off+= size + (0 if size%2==0 else 1)
    return members
b=load('theme.ipk')
m=parse_ar(b)
print('ar members:', list(m.keys()))
if 'data.tar.gz' in m:
    tf=tarfile.open(fileobj=io.BytesIO(gzip.decompress(m['data.tar.gz'])))
    names=tf.getnames()
    print('total files in data:', len(names))
    print('--- fonts/kucat 相关文件 ---')
    for n in names:
        if '/fonts/' in n or n.lower().endswith('.ttf') or n.lower().endswith('.woff') or n.lower().endswith('.woff2') or 'kucat' in n.lower():
            print('  %-80s %s' % (n, tf.getmember(n).size))
