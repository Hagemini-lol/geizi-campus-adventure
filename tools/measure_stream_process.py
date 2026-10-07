from pathlib import Path
import ctypes, ctypes.wintypes as wt, json, os, subprocess, time, argparse

root=Path(__file__).resolve().parents[1]
engine=root.parent/'Godot_v4.7.2-stable_win64.exe'
parser=argparse.ArgumentParser(description='Compare an explicitly preserved previous PCK with current source.')
parser.add_argument('--baseline-pack',type=Path,required=True)
args=parser.parse_args()
assert args.baseline_pack.is_file(),'Provide the previous version PCK, not the already updated runtime pack'
class Memory(ctypes.Structure):
    _fields_=[('cb',wt.DWORD),('faults',wt.DWORD)]+[(name,ctypes.c_size_t) for name in ['peak_working','working','peak_paged','paged','peak_nonpaged','nonpaged','pagefile','peak_pagefile','private']]
kernel=ctypes.WinDLL('kernel32',use_last_error=True)
kernel.OpenProcess.restype=wt.HANDLE
psapi=ctypes.WinDLL('psapi')
psapi.GetProcessMemoryInfo.argtypes=[wt.HANDLE,ctypes.POINTER(Memory),wt.DWORD]
kernel.GetProcessTimes.argtypes=[wt.HANDLE]+[ctypes.POINTER(wt.FILETIME)]*4
kernel.CloseHandle.argtypes=[wt.HANDLE]
env=os.environ.copy();env['APPDATA']=str(root/'runtime/mobile-check-appdata')
measurements={}
for tag in ['before','after']:
    command=[str(engine),'--position','-2000,-2000']
    command+=['--main-pack',str(args.baseline_pack.resolve())] if tag=='before' else ['--path',str(root/'source')]
    command+=['--script',str(root/'source/tests/stream_probe.gd'),'--','--probe='+tag,'--game-root='+str(root),'--save-dir='+str(root/'runtime/stream-process-saves'),'--settings-path='+str(root/'runtime/stream-process-settings.json')]
    with (root/'runtime'/f'stream-process-{tag}.log').open('w',encoding='utf-8') as log:
        started=time.monotonic();process=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
        handle=kernel.OpenProcess(0x1000|0x10,False,process.pid)
        assert handle,'Cannot open test process counters'
        peak_rss=0;peak_private=0;cpu_seconds=0
        while process.poll() is None:
            mem=Memory();mem.cb=ctypes.sizeof(mem)
            if psapi.GetProcessMemoryInfo(handle,ctypes.byref(mem),mem.cb):
                peak_rss=max(peak_rss,mem.working);peak_private=max(peak_private,mem.private)
            stamps=[wt.FILETIME() for _ in range(4)]
            if kernel.GetProcessTimes(handle,*[ctypes.byref(stamp) for stamp in stamps]):
                cpu_seconds=sum((stamp.dwHighDateTime<<32)+stamp.dwLowDateTime for stamp in stamps[2:])/10000000
            if time.monotonic()-started>120:process.kill();raise RuntimeError('Performance probe timeout')
            time.sleep(.05)
        kernel.CloseHandle(handle)
        assert process.returncode==0,(tag,process.returncode)
    samples=json.loads((root/'runtime'/f'stream_{tag}.json').read_text(encoding='utf-8'))
    measurements[tag]={'peak_working_set_bytes':peak_rss,'peak_private_bytes':peak_private,'cpu_seconds':cpu_seconds,'wall_seconds':time.monotonic()-started,'samples':samples}
    print(tag,json.dumps({k:v for k,v in measurements[tag].items() if k!='samples'}),flush=True)
(root/'runtime/stream_process_comparison.json').write_text(json.dumps(measurements,ensure_ascii=False,indent=2),encoding='utf-8')
