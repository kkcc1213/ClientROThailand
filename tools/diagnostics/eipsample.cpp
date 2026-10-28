// สุ่ม EIP ของทุก thread ใน process 32 บิต (ใช้หาว่า client วนลูปอยู่ตรงไหน)
// eipsample <pid> [samples]
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <map>
#pragma comment(lib, "psapi.lib")

int main(int argc, char** argv)
{
    if (argc < 2) { printf("usage: eipsample <pid> [samples]\n"); return 1; }
    DWORD pid = (DWORD)atoi(argv[1]);
    int samples = argc > 2 ? atoi(argv[2]) : 50;
    HANDLE proc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!proc) { printf("OpenProcess failed %lu\n", GetLastError()); return 1; }

    HMODULE mods[512]; DWORD need = 0;
    EnumProcessModules(proc, mods, sizeof(mods), &need);
    int nmods = (int)(need / sizeof(HMODULE));
    struct Mod { DWORD base, size; char name[64]; };
    Mod* info = new Mod[nmods];
    for (int i = 0; i < nmods; i++) {
        MODULEINFO mi; GetModuleInformation(proc, mods[i], &mi, sizeof(mi));
        info[i].base = (DWORD)(UINT_PTR)mi.lpBaseOfDll; info[i].size = mi.SizeOfImage;
        GetModuleBaseNameA(proc, mods[i], info[i].name, sizeof(info[i].name));
    }

    std::map<DWORD, std::map<DWORD, int>> hits;   // tid -> eip -> count
    for (int s = 0; s < samples; s++) {
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
        THREADENTRY32 te = { sizeof(te) };
        for (BOOL ok = Thread32First(snap, &te); ok; ok = Thread32Next(snap, &te)) {
            if (te.th32OwnerProcessID != pid) continue;
            HANDLE th = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT, FALSE, te.th32ThreadID);
            if (!th) continue;
            CONTEXT ctx = {}; ctx.ContextFlags = CONTEXT_CONTROL;
            if (SuspendThread(th) != (DWORD)-1) {
                if (GetThreadContext(th, &ctx)) {
                    hits[te.th32ThreadID][ctx.Eip]++;
                    // ที่อยู่ใน exe ที่เจอบน stack = ผู้เรียก (นับแยกด้วยบิตบนสุด)
                    DWORD stack[256]; SIZE_T got = 0;
                    if (ReadProcessMemory(proc, (LPCVOID)(UINT_PTR)ctx.Esp, stack, sizeof(stack), &got))
                        for (SIZE_T k = 0; k < got / 4; k++)
                            if (stack[k] >= info[0].base && stack[k] < info[0].base + info[0].size)
                                hits[te.th32ThreadID][0x80000000u | (stack[k] - info[0].base)]++;
                }
                ResumeThread(th);
            }
            CloseHandle(th);
        }
        CloseHandle(snap);
        Sleep(50);
    }

    for (auto& t : hits) {
        printf("thread %lu\n", t.first);
        for (auto& e : t.second) {
            if (e.first & 0x80000000u) { if (e.second >= samples / 2) printf("  stack exe+%lX  x%d\n", e.first & 0x7FFFFFFFu, e.second); continue; }
            const char* mod = "?"; DWORD rva = e.first;
            for (int i = 0; i < nmods; i++)
                if (e.first >= info[i].base && e.first < info[i].base + info[i].size) { mod = info[i].name; rva = e.first - info[i].base; break; }
            printf("  %08lX  %s+%lX  x%d\n", e.first, mod, rva, e.second);
        }
    }
    for (int i = 0; i < nmods && i < 3; i++) printf("module %s base %08lX\n", info[i].name, info[i].base);
    return 0;
}
