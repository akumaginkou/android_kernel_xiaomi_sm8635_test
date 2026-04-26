import struct, sys

def extract(boot_path, out_path):
    with open(boot_path, 'rb') as f:
        hdr = f.read(4096)
    magic = hdr[:8]
    ver = struct.unpack('<I', hdr[40:44])[0]
    print('magic:', magic, 'header_version:', ver)
    if ver >= 3:
        ksize, rsize, osver, hsize = struct.unpack('<IIII', hdr[8:24])
        print('kernel_size:', ksize, 'ramdisk_size:', rsize, 'os_version:', hex(osver), 'header_size:', hsize)
        koff = 4096
        with open(boot_path, 'rb') as f:
            f.seek(koff)
            kdata = f.read(ksize)
    else:
        ksize = struct.unpack('<I', hdr[8:12])[0]
        psize = struct.unpack('<I', hdr[36:40])[0]
        print('v<3: kernel_size:', ksize, 'page_size:', psize)
        koff = psize
        with open(boot_path, 'rb') as f:
            f.seek(koff)
            kdata = f.read(ksize)
    with open(out_path, 'wb') as out:
        out.write(kdata)
    print('wrote', out_path, len(kdata), 'bytes')

extract(sys.argv[1], sys.argv[2])
