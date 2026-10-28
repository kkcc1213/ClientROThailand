# ClientROThailand (fork: เล่นกับ server ในเครื่อง)

Fork ของ [rAthena-Thailand/ClientROThailand](https://github.com/rAthena-Thailand/ClientROThailand) ที่แก้ให้ client `Client-2025-06-04` (Renewal) เล่นกับ [rAthena-Thailand](https://github.com/rAthena-Thailand/rathenaThailand) (`PACKETVER 20250604`) ได้บน **Windows ภาษาไทย** โดยใช้ client ฐานของ Gravity ที่โหลดได้ (ทดสอบกับ **iRO** patch ก.ย. 2025)

ทดสอบแล้ว (2026-10-28): ล็อกอิน → สร้างตัวละคร → เข้าแผนที่ กับ server ในเครื่อง `127.0.0.1`

## สิ่งที่ต้องมี
- client ฐานของ Gravity (เช่น iRO จาก playragnarok.com) — ใช้ `data.grf`, DLL, BGM, ฟอนต์, `Setup.exe` · **ไม่มีใน repo นี้** (ลิขสิทธิ์ Gravity)
- Visual Studio 2022 Build Tools (C++) — build DLL ตัวแทน
- Python 3 + Pillow — วาดภาพหน้าล็อกอินและสร้าง GRF

## ติดตั้ง
```powershell
.\tools\setup-client.ps1 -BaseClient "F:\Gravity\Ragnarok Online" -OutDir "F:\ROThailand\client"
```
ถ้าเครื่องยังไม่เคยตั้งค่ากราฟิก ให้เปิด `Setup.exe` ในโฟลเดอร์ client หนึ่งครั้งแล้วกด OK (client รอ registry `HKLM\SOFTWARE\WOW6432Node\Gravity Soft\RenewSetup`) แล้วเปิดเกมด้วย `start-client.cmd`

`data\clientinfo.xml` ชี้ `127.0.0.1:6900` · `langtype 5` (ไทย — ถ้าเป็น 0 ข้อความไทยจะกลายเป็น `???`)

## แก้อะไรจากต้นฉบับ
| ปัญหา | ทางแก้ |
|---|---|
| exe ต้องการ `basesdk.dll` / `iapsdk.dll` (STOVE PC SDK ของ kRO) | `tools/stove-stub` — DLL ตัวแทนที่ตอบ "ไม่สำเร็จ" ทุกฟังก์ชัน (เล่นกับ server ในเครื่องไม่ได้เรียกใช้) · `Base_RestartAppIfNecessary` คืน 0 |
| `binkw32.dll` รุ่นเก่าไม่มี `_BinkShouldSkip@4` | `tools/bink-proxy` — ส่งต่อทุก export ไปตัวเดิม + เพิ่มฟังก์ชันนี้ |
| ฉากล็อกอินแบบใหม่ (`login.rsw`, `login_interface\*`) มีเฉพาะใน kRO → client ล้ม | `tools/grf` — วาดภาพหน้าล็อกอินเอง + ฉากจาก prontera แพ็กเป็น `rothai.grf` |
| ไฟล์ Lua ใน overlay ไม่ตรงกันเอง (`jobname.lub` อ้าง ID ที่ไม่มี) และขาดไฟล์ที่ต้องมาจาก kRO | comment บรรทัดที่อ้าง ID ที่ไม่มีใน `npcidentity` ของ iRO (`-- [no-iRO-id]`) · เพิ่ม `pcjobnamegender*`, `shadowtable_f`, CashEmotion, `common.lub`, navigation, damageskin (บรรทัดแรกของแต่ละไฟล์บอกที่มา) |
| exe ตั้ง `requireAdministrator` แต่ไม่จำเป็น | `start-client.cmd` ใช้ `__COMPAT_LAYER=RunAsInvoker` |
| exe รุ่นนี้เขียนทับ header ของ `data.grf` บางรุ่น | สคริปต์คัดลอก `data.grf` แล้วตั้ง read-only |

## ข้อจำกัดที่รู้
- ภาพ UI ที่แปลไทยในโฟลเดอร์ชื่อเกาหลีของ overlay (`À¯ÀúÀÎÅÍÆäÀÌ½º` ฯลฯ) ตั้งชื่อตาม codepage 1252 → บน Windows ภาษาไทย client หาไม่เจอ (ใช้ภาพจาก `data.grf` แทน) · ทางแก้ที่วางไว้: แพ็กเข้า GRF ด้วย `tools/grf/build_grf.py`
- error Lua ที่ยังเหลือแต่ไม่ทำให้ล้ม: `SystemEN\Rune\System_table.lub` / `CRuneSystemMgr file Init`
- ภาพหน้าล็อกอินเป็นภาพแทนที่วาดง่าย ๆ

## เครื่องมือหาปัญหา (`tools/diagnostics`)
`dismiss-dialogs.ps1` (จด+ปิดกล่อง error ของ client) · `snap-client.ps1` (ภาพหน้าต่างเกม) · `watch-conn.ps1` (connection ไป server) · `eipsample.cpp` / `excscan.cpp` / `stackstr.cpp` (หาจุดที่วนลูป/ล้ม) — ตัว C++ อ่านหน่วยความจำ process อื่น โปรแกรมป้องกันไวรัส (เช่น Kaspersky) อาจบล็อก
