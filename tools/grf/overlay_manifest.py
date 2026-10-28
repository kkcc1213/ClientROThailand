"""เขียน manifest ของไฟล์ใน overlay ที่ชื่อมีอักขระนอก ASCII (โฟลเดอร์ภาษาเกาหลี) เพื่อแพ็กเข้า GRF

ชื่อใน repo ถูกเก็บเป็น "ไบต์ cp949 ที่ถูกอ่านเป็น cp1252" (เช่น 유저인터페이스 → À¯ÀúÀÎÅÍÆäÀÌ½º)
บางไฟล์ถูกอ่านเป็น cp874 (อักษรไทย) แทน · สคริปต์แปลงกลับเป็นไบต์เดิมทีละอักขระ แล้วตรวจว่าเป็น cp949 ที่ถูกต้อง

ใช้: python overlay_manifest.py <โฟลเดอร์ data ของ overlay> <manifest ปลายทาง>
"""
import os
import sys


def original_bytes(name):
    out = bytearray()
    for ch in name:
        code = ord(ch)
        if code < 0x80:
            out.append(code)
            continue
        for codec in ("cp1252", "latin-1", "cp874"):
            try:
                out += ch.encode(codec)
                break
            except UnicodeEncodeError:
                continue
        else:
            raise ValueError(f"แปลงอักขระ {ch!r} ใน {name!r} ไม่ได้")
    return bytes(out)


def main(data_dir, out):
    count = 0
    skipped = []
    with open(out, "w", encoding="utf-8") as f:
        for root, _dirs, files in os.walk(data_dir):
            for file in files:
                full = os.path.join(root, file)
                rel = os.path.relpath(full, data_dir)
                if rel.isascii():
                    continue  # ชื่อ ASCII client อ่านจากไฟล์หลวมได้อยู่แล้ว
                try:
                    grf_name = ("data\\" + original_bytes(rel.replace("/", "\\")).decode("cp949"))
                except (ValueError, UnicodeDecodeError):
                    skipped.append(rel)
                    continue
                f.write(f"{full}|{grf_name}\n")
                count += 1
    sys.stdout.reconfigure(errors="replace")  # console ไทย (cp874) พิมพ์อักขระบางตัวไม่ได้
    print(f"{out}: {count} entries, skipped {len(skipped)}")
    for s in skipped[:10]:
        print("  ข้าม:", s.encode("unicode_escape").decode())


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: overlay_manifest.py <overlay data dir> <manifest.txt>")
    main(*sys.argv[1:])
