import re

paths = [
    ('STOCK', '/tmp/stock-boot/Image-stock'),
    ('OUR  ', '/tmp/stock-boot/our-pure/Image'),
]

for label, p in paths:
    p_win = p.replace('/tmp/', 'C:/Users/AKUMAG~1/AppData/Local/Temp/')
    try:
        with open(p_win, 'rb') as f:
            data = f.read()
    except FileNotFoundError:
        with open(p, 'rb') as f:
            data = f.read()
    print(label, 'size:', len(data))
    m = re.search(rb'Linux version [^\x00\n]+', data)
    print(label, 'banner:', m.group(0).decode('latin-1') if m else 'NONE')
    # Look for compiler info
    m2 = re.search(rb'(clang|gcc) version [^\x00\n]+', data)
    print(label, 'compiler:', m2.group(0).decode('latin-1') if m2 else 'NONE')
    print()
