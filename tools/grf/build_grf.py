"""สร้างไฟล์ GRF เวอร์ชัน 0x200 (ไม่เข้ารหัส) จากรายการไฟล์ · เขียนลงดิสก์ทีละไฟล์ จึงใช้กับข้อมูลหลาย GB ได้

ทำไมต้องใช้ GRF แทนไฟล์หลวมใน data\\ : ชื่อโฟลเดอร์ภาษาเกาหลี (เช่น 유저인터페이스) client ค้นด้วยไบต์ cp949
ถ้าเป็นไฟล์หลวม Windows จะแปลงไบต์ตาม ANSI codepage ของเครื่อง (เครื่องไทย = 874) ทำให้หาไม่เจอ
ส่วนใน GRF client เทียบชื่อเป็นไบต์ตรง ๆ จึงใช้ได้ทุกเครื่อง

ใช้: python build_grf.py <out.grf> <manifest.txt> [manifest2.txt ...]
manifest: บรรทัดละ  <ไฟล์ต้นทาง>|<path ใน grf เช่น data\\texture\\유저인터페이스\\login_interface\\bg_login.tga>
บรรทัดว่างหรือขึ้นต้นด้วย # ข้ามได้ · path ใน grf เขียนเป็น UTF-8 แล้วสคริปต์แปลงเป็น cp949 ให้
ถ้า path ซ้ำกัน ไฟล์ที่มาทีหลังชนะ (manifest หลัง ๆ ทับตัวก่อน)
"""
import struct
import sys
import zlib

HEADER_MAGIC = b"Master of Magic\x00"
HEADER_KEY = bytes(range(1, 15))
HEADER_SIZE = 46
FLAG_FILE = 0x01
MAX_BODY = 0xFFFFFFFF  # 0x200 เก็บ offset เป็น 32 บิต


def read_manifest(path):
    entries = []
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            src, sep, grf_path = line.rpartition("|")
            if not sep:
                raise ValueError(f"{path}:{lineno}: ต้องมี | คั่น")
            entries.append((src.strip(), grf_path.strip().replace("/", "\\").encode("cp949")))
    return entries


def build(out_path, entries, level=6):
    """entries: [(ไฟล์ต้นทาง, ชื่อใน grf เป็น bytes cp949)] · คืนจำนวนไฟล์ที่เขียน"""
    unique = {}
    for src, name in entries:
        unique[name.lower()] = (src, name)  # ตัวหลังชนะ
    table = bytearray()
    offset = 0
    with open(out_path, "wb") as out:
        out.write(b"\x00" * HEADER_SIZE)  # header ตัวจริงเขียนตอนท้าย
        for src, name in unique.values():
            with open(src, "rb") as f:
                raw = f.read()
            comp = zlib.compress(raw, level)
            aligned = (len(comp) + 7) & ~7  # ขนาดปัดขึ้นทีละ 8 ตามรูปแบบ GRF
            if offset + aligned > MAX_BODY:
                raise ValueError("ข้อมูลเกิน 4 GB — GRF 0x200 รับไม่ได้ ให้แบ่งเป็นหลายไฟล์")
            out.write(comp + b"\x00" * (aligned - len(comp)))
            table += name + b"\x00" + struct.pack("<IIIBI", len(comp), aligned, len(raw), FLAG_FILE, offset)
            offset += aligned
        packed_table = zlib.compress(bytes(table), level)
        out.write(struct.pack("<II", len(packed_table), len(table)))
        out.write(packed_table)
        out.seek(0)
        out.write(HEADER_MAGIC + HEADER_KEY + struct.pack("<IIII", offset, 0, len(unique) + 7, 0x200))
    return len(unique)


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: build_grf.py <out.grf> <manifest.txt> [manifest2.txt ...]")
    entries = [e for m in sys.argv[2:] for e in read_manifest(m)]
    count = build(sys.argv[1], entries)
    print(f"{sys.argv[1]}: {count} files")


if __name__ == "__main__":
    main()
