// พิมพ์ชื่อไฟล์ (ข้อความที่มี . และนามสกุลรู้จัก) ที่อยู่บน stack ของ thread หนึ่ง หรือที่ pointer บน stack ชี้ไป
// stackstr <pid> <tid>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <set>
#include <string>

static bool looks_like_path(const char* s, size_t n)
{
    if (n < 5) return false;
    for (size_t i = 0; i < n; i++) if ((unsigned char)s[i] < 0x20) return false;
    const char* exts[] = { ".bmp", ".tga", ".spr", ".act", ".jpg", ".png", ".str", ".imf", ".gr2", ".rsm", ".rsw", ".gnd", ".gat", ".lub", ".lua", ".txt", ".xml", ".wav", ".mp3", ".pal", ".ebm", ".eot" };
    std::string low(s, n); for (auto& c : low) c = (char)tolower((unsigned char)c);
    for (auto e : exts) if (low.find(e) != std::string::npos) return true;
    return false;
}

static void scan(const unsigned char* buf, size_t len, std::set<std::string>& out)
{
    size_t i = 0;
    while (i < len) {
        size_t j = i;
        while (j < len && buf[j] >= 0x20 && buf[j] != 0x7F) j++;
        if (j > i && looks_like_path((const char*)buf + i, j - i)) out.insert(std::string((const char*)buf + i, j - i));
        i = j + 1;
    }
}

int main(int argc, char** argv)
{
    if (argc < 3) { printf("usage: stackstr <pid> <tid>\n"); return 1; }
    HANDLE proc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, (DWORD)atoi(argv[1]));
    HANDLE th = OpenThread(THREAD_GET_CONTEXT | THREAD_SUSPEND_RESUME, FALSE, (DWORD)atoi(argv[2]));
    if (!proc || !th) { printf("open failed %lu\n", GetLastError()); return 1; }
    CONTEXT ctx = {}; ctx.ContextFlags = CONTEXT_CONTROL;
    SuspendThread(th); GetThreadContext(th, &ctx);
    static unsigned char stack[0x20000]; SIZE_T got = 0;
    ReadProcessMemory(proc, (LPCVOID)(UINT_PTR)ctx.Esp, stack, sizeof(stack), &got);
    std::set<std::string> found;
    scan(stack, got, found);
    // pointer บน stack ที่ชี้ไปยังข้อความ (std::string ยาวเก็บบน heap)
    for (SIZE_T k = 0; k + 4 <= got; k += 4) {
        DWORD p = *(DWORD*)(stack + k);
        if (p < 0x10000) continue;
        unsigned char tmp[260]; SIZE_T g2 = 0;
        if (ReadProcessMemory(proc, (LPCVOID)(UINT_PTR)p, tmp, sizeof(tmp), &g2) && g2) scan(tmp, g2, found);
    }
    ResumeThread(th);
    for (auto& s : found) printf("%s\n", s.c_str());
    return 0;
}
