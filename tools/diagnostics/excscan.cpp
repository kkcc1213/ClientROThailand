// หา EXCEPTION_RECORD (0xC0000005 ฯลฯ) บน stack ของทุก thread ใน process 32 บิต
// ใช้ตอนที่กล่อง "Gravity Error Handler" ค้างอยู่ เพื่อรู้ว่า exception เกิดที่ไหน
// excscan <pid>
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
#pragma comment(lib, "psapi.lib")

static void describe(HANDLE proc, DWORD addr)
{
    HMODULE mods[512]; DWORD need = 0;
    EnumProcessModules(proc, mods, sizeof(mods), &need);
    for (DWORD i = 0; i < need / sizeof(HMODULE); i++) {
        MODULEINFO mi; GetModuleInformation(proc, mods[i], &mi, sizeof(mi));
        DWORD base = (DWORD)(UINT_PTR)mi.lpBaseOfDll;
        if (addr >= base && addr < base + mi.SizeOfImage) {
            char name[64]; GetModuleBaseNameA(proc, mods[i], name, sizeof(name));
            printf("%s+%lX", name, addr - base);
            return;
        }
    }
    printf("?");
}

int main(int argc, char** argv)
{
    if (argc < 2) { printf("usage: excscan <pid>\n"); return 1; }
    DWORD pid = (DWORD)atoi(argv[1]);
    HANDLE proc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!proc) { printf("OpenProcess failed %lu\n", GetLastError()); return 1; }

    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    THREADENTRY32 te = { sizeof(te) };
    static DWORD stack[0x8000];
    for (BOOL ok = Thread32First(snap, &te); ok; ok = Thread32Next(snap, &te)) {
        if (te.th32OwnerProcessID != pid) continue;
        HANDLE th = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT, FALSE, te.th32ThreadID);
        if (!th) continue;
        CONTEXT ctx = {}; ctx.ContextFlags = CONTEXT_CONTROL;
        SuspendThread(th);
        GetThreadContext(th, &ctx);
        SIZE_T got = 0;
        ReadProcessMemory(proc, (LPCVOID)(UINT_PTR)ctx.Esp, stack, sizeof(stack), &got);
        ResumeThread(th); CloseHandle(th);
        for (SIZE_T k = 0; k + 6 < got / 4; k++) {
            DWORD code = stack[k];
            if (code != 0xC0000005 && code != 0xC0000094 && code != 0xC00000FD && code != 0xC0000409 && code != 0xE06D7363) continue;
            DWORD flags = stack[k + 1], addr = stack[k + 3], nparams = stack[k + 4];
            if (flags > 1 || nparams > 15) continue;
            printf("thread %lu: code %08lX at %08lX (", te.th32ThreadID, code, addr);
            describe(proc, addr);
            printf(")");
            if (code == 0xC0000005 && nparams >= 2) printf(" %s %08lX", stack[k + 5] ? "write" : "read", stack[k + 6]);
            printf("\n");
        }
    }
    CloseHandle(snap);
    return 0;
}
