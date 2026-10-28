// stub ของ STOVE PC SDK (basesdk.dll / iapsdk.dll) สำหรับรัน client kRO กับ server ในเครื่อง
// ไม่มีโค้ดของ Smilegate — ทุกฟังก์ชันตอบ "ไม่สำเร็จ/ว่าง" และจด log ลง stove_stub.log
//
// การจับคู่ calling convention (x86):
//   - export แบบ C (Base_*, IAP_*) เป็น __cdecl: ผู้เรียกล้าง stack เอง จึงรับอาร์กิวเมนต์แรกตัวเดียวพอ
//   - method แบบ __thiscall (this ใน ecx, callee ล้าง stack) จับคู่ด้วย __fastcall(ecx, edx, ...)
//     โดย edx เป็นตัวหลอก ทำให้อาร์กิวเมนต์บน stack ตรงกันและ callee ล้างจำนวนไบต์เท่ากัน
//   - method ที่คืน struct by value รับ pointer ซ่อนเป็นอาร์กิวเมนต์แรกบน stack และคืน pointer นั้นใน eax
#include <windows.h>
#include <stdio.h>

// จดเฉพาะครั้งแรกของแต่ละฟังก์ชัน (บางตัวอาจถูกเรียกทุกเฟรม) · name เป็น string literal เทียบ pointer ได้
static void stub_log(const char* name)
{
    static const char* seen[64];
    static int seen_count = 0;
    for (int i = 0; i < seen_count; i++)
        if (seen[i] == name) return;
    if (seen_count < 64) seen[seen_count++] = name;

    FILE* f = nullptr;
    if (fopen_s(&f, "stove_stub.log", "a") == 0 && f) {
        SYSTEMTIME t;
        GetLocalTime(&t);
        fprintf(f, "%02d:%02d:%02d.%03d %s\n", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds, name);
        fclose(f);
    }
}

// ให้ IsSuccessful ตอบ true ได้ถ้ามีไฟล์ stove_stub_success.txt ข้าง exe (ไว้ทดลอง)
static bool stub_success()
{
    return GetFileAttributesA("stove_stub_success.txt") != INVALID_FILE_ATTRIBUTES;
}

struct PurchaseOption24 { unsigned char bytes[24]; };

extern "C" {

// ---- C exports (__cdecl) ----
void* __cdecl S_Base_Initialize(void* a)            { stub_log("Base_Initialize"); return a; }
void* __cdecl S_Base_UnInitialize(void* a)          { stub_log("Base_UnInitialize"); return a; }
void* __cdecl S_Base_GetUser(void* a)               { stub_log("Base_GetUser"); return a; }
void* __cdecl S_Base_GetAccessToken(void* a)        { stub_log("Base_GetAccessToken"); return a; }
void* __cdecl S_Base_GetShutdown(void* a)           { stub_log("Base_GetShutdown"); return a; }
void* __cdecl S_Base_RunCallback(void)              { stub_log("Base_RunCallback"); return nullptr; }
// คืน 1 = ให้ client ปิดตัวไปเปิดใหม่ผ่าน launcher ของ STOVE จึงต้องคืน 0 เสมอ
int   __cdecl S_Base_RestartAppIfNecessary(void*)   { stub_log("Base_RestartAppIfNecessary"); return 0; }
void* __cdecl S_IAP_Initialize(void* a)             { stub_log("IAP_Initialize"); return a; }
void* __cdecl S_IAP_UnInitialize(void* a)           { stub_log("IAP_UnInitialize"); return a; }
void* __cdecl S_IAP_FetchProducts(void* a)          { stub_log("IAP_FetchProducts"); return a; }
void* __cdecl S_IAP_FetchTermsAgreement(void* a)    { stub_log("IAP_FetchTermsAgreement"); return a; }
void* __cdecl S_IAP_StartPurchase(void* a)          { stub_log("IAP_StartPurchase"); return a; }
void* __cdecl S_IAP_ConfirmPurchase(void* a)        { stub_log("IAP_ConfirmPurchase"); return a; }

// ---- __thiscall ไม่มีอาร์กิวเมนต์บน stack ----
void* __fastcall S_Ctor(void* self, void*)          { stub_log("ctor"); return self; }
void  __fastcall S_Dtor(void*, void*)               { }
bool  __fastcall S_IsSuccessful(void*, void*)       { stub_log("Result::IsSuccessful"); return stub_success(); }
int   __fastcall S_GetInt(void*, void*)             { stub_log("get int"); return 0; }
void* __fastcall S_GetPtr(void*, void*)             { stub_log("get ptr"); return nullptr; }
const wchar_t* __fastcall S_GetWStr(void*, void*)   { stub_log("get wstr"); return L""; }
unsigned __int64 __fastcall S_GetU64(void*, void*)  { stub_log("get u64"); return 0; }
double __fastcall S_GetDouble(void*, void*)         { stub_log("get double"); return 0.0; }

// ---- __thiscall มีอาร์กิวเมนต์บน stack (callee ล้างตามขนาด) ----
void  __fastcall S_Set4(void*, void*, void*)        { stub_log("set (4)"); }
void  __fastcall S_Set8(void*, void*, unsigned __int64) { stub_log("set (8)"); }
void  __fastcall S_SetIntPtr(void*, void*, int, const void*) { stub_log("set (int,ptr)"); }
void  __fastcall S_SetPurchaseOption(void*, void*, PurchaseOption24) { stub_log("SetPurchaseOption"); }
void* __fastcall S_Assign(void* self, void*, const void*) { stub_log("operator="); return self; }
void* __fastcall S_GetResult(void*, void*, void* ret) { stub_log("CallbackResult::GetResult"); return ret; }

}

BOOL APIENTRY DllMain(HMODULE, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) stub_log("DLL loaded");
    return TRUE;
}
