"""Build the renamed Windows launcher without moving assets or player saves."""
from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text(encoding='utf-8-sig').strip()
compiler=Path('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe')
metadata=root/'runtime/LauncherAssemblyInfo.cs'
metadata.write_text('using System.Reflection;\n'
    '[assembly: AssemblyTitle("gei子的冒险")]\n'
    '[assembly: AssemblyProduct("gei子的冒险")]\n'
    f'[assembly: AssemblyVersion("{version}.0")]\n'
    f'[assembly: AssemblyFileVersion("{version}.0")]\n',encoding='utf-8-sig')
temporary=root/'runtime/launcher-new.exe'
subprocess.run([str(compiler),'/nologo','/target:winexe','/reference:System.Windows.Forms.dll',
    '/out:'+str(temporary),str(root/'tools/Launcher.cs'),str(metadata)],check=True)
temporary.replace(root/'gei子的冒险.exe')
legacy=root/'校园自由漫游.exe'
if legacy.exists():legacy.unlink()
print('gei子的冒险.exe',version)
