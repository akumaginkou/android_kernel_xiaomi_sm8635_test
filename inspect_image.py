import re, sys
data = open(sys.argv[1],'rb').read()
m = re.search(rb'Linux version [^\x00\n]+', data)
print('size:', len(data))
print('banner:', m.group(0).decode('latin-1') if m else 'NONE')
m2 = re.search(rb'(clang|gcc) version [^\x00\n]+', data)
print('compiler:', m2.group(0).decode('latin-1') if m2 else 'NONE')
