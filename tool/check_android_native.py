"""Check every packaged 64-bit ELF LOAD segment for 16KB alignment."""
import struct
import sys
import zipfile

failures = []
count = 0
with zipfile.ZipFile(sys.argv[1]) as archive:
    for name in archive.namelist():
        if not name.endswith('.so') or not any(abi in name for abi in ('arm64-v8a', 'x86_64')):
            continue
        data = archive.read(name)
        assert data[:5] == b'\x7fELF\x02', name
        endian = '<' if data[5] == 1 else '>'
        offset = struct.unpack_from(endian + 'Q', data, 32)[0]
        size, number = struct.unpack_from(endian + 'HH', data, 54)
        loads = []
        for index in range(number):
            header = struct.unpack_from(endian + 'IIQQQQQQ', data, offset + index * size)
            if header[0] == 1:
                loads.append(header[-1])
        valid = bool(loads) and all(value >= 16384 for value in loads)
        print(('PASS' if valid else 'FAIL'), name, 'LOAD alignment', loads)
        count += 1
        if not valid:
            failures.append(name)
assert count, 'No 64-bit native libraries found'
print(f'{count} libraries checked, {len(failures)} failures')
sys.exit(bool(failures))
