"""เขียน manifest สำหรับ build_grf.py: ภาพ login_interface ที่วาดเอง + ฉาก login.rsw

ใช้: python login_manifest.py <โฟลเดอร์ภาพ> <ไฟล์ .rsw ที่จะใช้เป็นฉากล็อกอิน> <manifest ปลายทาง>
"""
import os
import sys

UI_DIR = "data/texture/유저인터페이스/login_interface/"  # 유저인터페이스


def main(asset_dir, rsw, out):
    lines = [f"{rsw}|data/login.rsw"]
    lines += [f"{os.path.join(asset_dir, f)}|{UI_DIR}{f}" for f in sorted(os.listdir(asset_dir))]
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{out}: {len(lines)} entries")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: login_manifest.py <asset_dir> <scene.rsw> <manifest.txt>")
    main(*sys.argv[1:])
