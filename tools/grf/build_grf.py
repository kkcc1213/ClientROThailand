"""สร้างไฟล์ GRF เวอร์ชัน 0x200 (ไม่เข้ารหัส) จากรายการไฟล์

ทำไมต้องใช้ GRF แทนไฟล์หลวมใน data\\ : ชื่อโฟลเดอร์ภาษาเกาหลี (เช่น 유저인터페이스) client ค้นด้วยไบต์ cp949
ถ้าเป็นไฟล์หลวม Windows จะแปลงไบต์ตาม ANSI codepage ของเครื่อง (เครื่องไทย = 874) ทำให้หาไม่เจอ
ส่วนใน GRF client เทียบชื่อเป็นไบต์ตรง ๆ จึงใช้ได้ทุกเครื่อง

ใช้: python build_grf.py <out.grf> <manifest.txt>
manifest: บรรทัดละ  <ไฟล์ต้นทาง>|<path ใน grf เช่น data\\texture\\유저인터페이스\\login_interface\\bg_login.tga>
บรรทัดว่างหรือขึ้นต้นด้วย # ข้ามได้ · path ใน grf เขียนเป็น UTF-8 แล้วสคริปต์แปลงเป็น cp949 ให้
"""
import struct
import sys
import zlib

HEADER_MAGIC = b"Master of Magic\x00"
HEADER_KEY = bytes(range(1, 15))
HEADER_SIZE = 46
FLAG_FILE = 0x01


def read_manifest(path):
    entries = []
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            src, sep, grf_path = line.partition("|")
            if not sep:
                raise ValueError(f"{path}:{lineno}: ต้องมี | คั่น")
            entries.append((src.strip(), grf_path.strip().replace("/", "\\")))
    return entries


def build(out_path, entries):
    body = bytearray()
    table = bytearray()
    seen = set()
    for src, grf_path in entries:
        name = grf_path.encode("cp949")
        if name.lower() in seen:
            raise ValueError(f"ซ้ำ: {grf_path}")
        seen.add(name.lower())
        with open(src, "rb") as f:
            raw = f.read()
        comp = zlib.compress(raw, 9)
        aligned = (len(comp) + 7) & ~7  # ขนาดปัดขึ้นทีละ 8 ตามรูปแบบ GRF
        offset = len(body)
        body += comp + b"\x00" * (aligned - len(comp))
        table += name + b"\x00" + struct.pack("<IIIBI", len(comp), aligned, len(raw), FLAG_FILE, offset)
    packed_table = zlib.compress(bytes(table), 9)
    header = HEADER_MAGIC + HEADER_KEY + struct.pack("<IIII", len(body), 0, len(entries) + 7, 0x200)
    assert len(header) == HEADER_SIZE
    with open(out_path, "wb") as f:
        f.write(header)
        f.write(body)
        f.write(struct.pack("<II", len(packed_table), len(table)))
        f.write(packed_table)
    return len(entries)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: build_grf.py <out.grf> <manifest.txt>")
    count = build(sys.argv[1], read_manifest(sys.argv[2]))
    print(f"{sys.argv[1]}: {count} files")


if __name__ == "__main__":
    main()
