// binkw32 ตัวกลาง: ส่งต่อทุก export ไป binkw32_th.dll (ตัวเดิมของ client ฐาน) และเพิ่ม BinkShouldSkip
// ที่ exe kRO 2025 ต้องใช้แต่ binkw32 รุ่นเก่า (1.5J ของ thRO/iRO) ไม่มี
// รายการ export สร้างตอน build ด้วย tools/build-native.ps1 (อ่านจาก dumpbin /exports ของตัวเดิม)
extern "C" int __stdcall BinkShouldSkipStub(void*) { return 0; }  // 0 = ไม่ข้ามเฟรม
