"""วาดภาพหน้าล็อกอินแบบใหม่ (login_interface) ที่ exe kRO 2025 ต้องใช้ แต่ไม่มีใน grf ของ iRO/thRO

ภาพทั้งหมดวาดขึ้นเองจากโค้ดนี้ (ไม่ได้คัดลอกจาก Gravity) ขนาด/ตำแหน่งอ้างอิงจาก
roBrowserLegacy WinLoginV2 (src/UI/Components/WinLogin/WinLoginV2/WinLoginV2.css)

ใช้: python make_login_assets.py <โฟลเดอร์ปลายทาง>
ได้ไฟล์ชื่อตามที่ exe เรียก (bg_login.tga, bt_*_normal/over/press.bmp, checkbox_*.bmp ...)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

MAGENTA = (255, 0, 255)  # สีโปร่งใสของ BMP ใน RO

PANEL_SIZE = (301, 132)
FIELD_BOXES = ((17, 39, 127, 18), (17, 61, 127, 18))  # x, y, w, h ของช่อง ID / PW

BUTTONS = {
    # ชื่อไฟล์ (ไม่รวม _normal/_over/_press): (ขนาด, ข้อความ, สีพื้น)
    "bt_start": ((84, 84), "START", (52, 112, 196)),
    "bt_join": ((84, 21), "JOIN", (70, 90, 120)),
    "bt_otp": ((84, 21), "OTP", (70, 90, 120)),
    "bt_close": ((24, 23), "X", (150, 60, 60)),
    "bt_close2": ((24, 23), "X", (150, 60, 60)),
}
STATE_SHIFT = {"normal": 0, "over": 30, "press": -30}


def _font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "tahomabd.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _shade(rgb, delta):
    return tuple(max(0, min(255, c + delta)) for c in rgb)


def _centered_text(draw, box, text, font, fill):
    x0, y0, x1, y1 = box
    l, t, r, b = draw.textbbox((0, 0), text, font=font)
    draw.text((x0 + (x1 - x0 - (r - l)) / 2 - l, y0 + (y1 - y0 - (b - t)) / 2 - t), text, font=font, fill=fill)


def make_panel(path):
    w, h = PANEL_SIZE
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(h):  # พื้นไล่สีน้ำเงินเข้ม
        c = _shade((24, 36, 64), int(30 * y / h))
        d.line([(0, y), (w, y)], fill=c + (225,))
    d.rectangle([0, 0, w - 1, h - 1], outline=(140, 170, 230, 255))
    small = _font(10)
    d.text((10, 10), "ROThailand Local", font=_font(12), fill=(230, 236, 250, 255))
    for (x, y, fw, fh), label in zip(FIELD_BOXES, ("ID", "PW")):
        d.rectangle([x - 1, y - 1, x + fw, y + fh], fill=(245, 247, 252, 255), outline=(90, 110, 160, 255))
        d.text((x + fw + 6, y + 3), label, font=small, fill=(200, 210, 235, 255))
    img.save(path)  # TGA 32 บิต มี alpha


def make_button(base, size, text, color, out_dir):
    for state, delta in STATE_SHIFT.items():
        img = Image.new("RGB", size, MAGENTA)
        d = ImageDraw.Draw(img)
        fill = _shade(color, delta)
        if size[0] == size[1] and size[0] >= 60:  # ปุ่มกลมใหญ่ (START)
            d.ellipse([1, 1, size[0] - 2, size[1] - 2], fill=fill, outline=(220, 230, 255))
        else:
            d.rectangle([0, 0, size[0] - 1, size[1] - 1], fill=fill, outline=(220, 230, 255))
        _centered_text(d, (0, 0, size[0], size[1]), text, _font(max(9, min(16, size[1] // 2))), (255, 255, 255))
        img.save(os.path.join(out_dir, f"{base}_{state}.bmp"))


def make_checkbox(path, checked, size=12):
    img = Image.new("RGB", (size, size), MAGENTA)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size - 1, size - 1], fill=(245, 247, 252), outline=(90, 110, 160))
    if checked:
        d.line([(2, size // 2), (size // 2 - 1, size - 3), (size - 3, 2)], fill=(40, 90, 200), width=2)
    img.save(path)


def make_dropdown(out_dir, size=18):
    """ปุ่มลูกศรของ combobox ในหน้าล็อกอิน (btn_dropdown_out/over/press) · ถ้าไม่มี กล่องจะสูงติดลบแล้ว client ล้ม"""
    for state, delta in (("out", 0), ("over", 30), ("press", -30)):
        img = Image.new("RGB", (size, size), MAGENTA)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, size - 1, size - 1], fill=_shade((70, 90, 120), delta), outline=(220, 230, 255))
        m = size // 4
        d.polygon([(m, m + 2), (size - m, m + 2), (size // 2, size - m)], fill=(255, 255, 255))
        img.save(os.path.join(out_dir, f"btn_dropdown_{state}.bmp"))


def make_plain(path, size, text):
    img = Image.new("RGB", size, (30, 42, 72))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size[0] - 1, size[1] - 1], outline=(140, 170, 230))
    _centered_text(d, (0, 0, size[0], size[1]), text, _font(12), (230, 236, 250))
    img.save(path)


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    make_panel(os.path.join(out_dir, "bg_login.tga"))
    for base, (size, text, color) in BUTTONS.items():
        make_button(base, size, text, color, out_dir)
    for name, checked in (("checkbox_on", True), ("checkbox_off", False)):
        make_checkbox(os.path.join(out_dir, f"{name}.bmp"), checked)
    make_dropdown(out_dir)
    make_plain(os.path.join(out_dir, "bg_newotp1.bmp"), PANEL_SIZE, "OTP")
    print("\n".join(sorted(os.listdir(out_dir))))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: make_login_assets.py <out_dir>")
    main(sys.argv[1])
