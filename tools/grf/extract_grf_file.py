"""ดึงไฟล์เดียวออกจาก GRF (เวอร์ชัน 0x200 หรือ 0x300) — รองรับเฉพาะไฟล์ที่ไม่เข้ารหัส

ใช้: python extract_grf_file.py <data.grf> <path ใน grf เช่น data/prontera.rsw> <ไฟล์ปลายทาง>
"""
import struct
import sys
import zlib

HEADER_SIZE = 46
FLAG_FILE = 0x01
FLAG_ENCRYPTED = 0x02 | 0x04


def read_table(f):
    header = f.read(HEADER_SIZE)
    version = struct.unpack_from("<I", header, 42)[0]
    if version == 0x300:
        table_offset = struct.unpack_from("<Q", header, 30)[0]
        count = struct.unpack_from("<I", header, 38)[0]
        offset_format, offset_size = "<Q", 8
        f.seek(HEADER_SIZE + table_offset + 4)  # 0x300 มี 4 ไบต์ว่างก่อนขนาดตาราง
    elif version == 0x200:
        table_offset, seed, raw_count = struct.unpack_from("<III", header, 30)
        count = raw_count - seed - 7
        offset_format, offset_size = "<I", 4
        f.seek(HEADER_SIZE + table_offset)
    else:
        raise ValueError(f"ไม่รองรับ GRF เวอร์ชัน 0x{version:X}")
    packed_size, real_size = struct.unpack("<II", f.read(8))
    table = zlib.decompress(f.read(packed_size))
    if len(table) != real_size:
        raise ValueError("ตารางไฟล์ไม่ครบ")
    return table, count, offset_format, offset_size


def find_entry(table, count, offset_format, offset_size, wanted):
    pos = 0
    for _ in range(count):
        end = table.index(b"\x00", pos)
        name = table[pos:end]
        pos = end + 1
        comp, aligned, real, flags = struct.unpack_from("<IIIB", table, pos)
        offset = struct.unpack_from(offset_format, table, pos + 13)[0]
        pos += 13 + offset_size
        if name.lower() == wanted:
            return comp, aligned, real, flags, offset
    return None


def extract(grf_path, inner_path, out_path):
    wanted = inner_path.replace("/", "\\").encode("cp949").lower()
    with open(grf_path, "rb") as f:
        table, count, offset_format, offset_size = read_table(f)
        entry = find_entry(table, count, offset_format, offset_size, wanted)
        if entry is None:
            raise FileNotFoundError(f"ไม่พบ {inner_path} ใน {grf_path}")
        comp, aligned, real, flags, offset = entry
        if not flags & FLAG_FILE:
            raise ValueError(f"{inner_path} ไม่ใช่ไฟล์")
        if flags & FLAG_ENCRYPTED:
            raise ValueError(f"{inner_path} เข้ารหัสอยู่ — สคริปต์นี้ไม่ถอดรหัส")
        f.seek(HEADER_SIZE + offset)
        data = zlib.decompress(f.read(aligned)[:comp])
    if len(data) != real:
        raise ValueError(f"{inner_path}: ขนาดไม่ตรง ({len(data)} != {real})")
    with open(out_path, "wb") as out:
        out.write(data)
    return len(data)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: extract_grf_file.py <data.grf> <path-in-grf> <out>")
    print(f"{sys.argv[3]}: {extract(*sys.argv[1:])} bytes")
