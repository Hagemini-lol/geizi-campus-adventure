"""Fetch official portable Android export tools into the game build directory."""
from pathlib import Path
import hashlib, json, time, urllib.request, zipfile, xml.etree.ElementTree as ET
import io, struct, zlib, concurrent.futures

base=Path(__file__).resolve().parents[1]/'android_tools'
base.mkdir(exist_ok=True)
def request(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'CampusAndroidBuild/1.0'}),timeout=60)
def download(url,path,checksum=None,algorithm='sha256'):
    if path.exists() and (not checksum or hashlib.new(algorithm,path.read_bytes()).hexdigest()==checksum):return
    print('Downloading '+path.name,flush=True)
    temp=path.with_suffix(path.suffix+'.partial')
    with request(url) as response:
        total=int(response.headers.get('Content-Length',0));direct=response.geturl()
        ranges=response.headers.get('Accept-Ranges')=='bytes' and total>8*1048576
        if not ranges:
            with temp.open('wb') as out:
                import shutil
                shutil.copyfileobj(response,out,1048576)
    if ranges:
        offset=temp.stat().st_size if temp.exists() else 0
        def chunk(start):
            end=min(total,start+4*1048576)-1
            for attempt in range(5):
                try:
                    req=urllib.request.Request(direct,headers={'Range':f'bytes={start}-{end}','User-Agent':'CampusAndroidBuild/1.0'})
                    with urllib.request.urlopen(req,timeout=120) as r:
                        assert r.status==206
                        data=r.read();assert len(data)==end-start+1
                        return data
                except Exception:
                    if attempt==4:raise
                    time.sleep(2+attempt)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool,temp.open('ab') as out:
            futures=[pool.submit(chunk,start) for start in range(offset,total,4*1048576)]
            for future in futures:
                data=future.result();out.write(data);out.flush();offset+=len(data)
                print(f'{path.name}: {offset//1048576}/{total//1048576} MB',flush=True)
    if checksum:assert hashlib.new(algorithm,temp.read_bytes()).hexdigest()==checksum,(path.name,'checksum mismatch')
    temp.replace(path)
def unzip(archive,directory):
    directory.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():assert not Path(name).is_absolute() and '..' not in Path(name).parts
        z.extractall(directory)

def extract_remote_template(url,total):
    # Read only the release APK from the official multi-platform template ZIP.
    # Avoid downloading over a gigabyte of unused desktop/iOS templates.
    def part(start,end):
        req=urllib.request.Request(url,headers={'User-Agent':'CampusAndroidBuild/1.0','Range':f'bytes={start}-{end}'})
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req,timeout=120) as response:
                    assert response.status==206,'Server did not support byte ranges'
                    data=response.read()
                    assert len(data)==end-start+1
                    return data
            except Exception:
                if attempt==4:raise
                time.sleep(2+attempt)
    class Remote(io.RawIOBase):
        position=0
        def seekable(self):return True
        def seek(self,offset,whence=0):
            self.position=offset if whence==0 else (self.position+offset if whence==1 else total+offset)
            return self.position
        def tell(self):return self.position
        def read(self,n=-1):
            n=min(n if n>=0 else total-self.position,total-self.position)
            if n<=0:return b''
            data=part(self.position,self.position+n-1);self.position+=n;return data
    with zipfile.ZipFile(Remote()) as archive:
        item=archive.getinfo('templates/android_release.apk')
    header=part(item.header_offset,item.header_offset+29)
    fields=struct.unpack('<4s5H3I2H',header)
    start=item.header_offset+30+fields[-2]+fields[-1]
    step=4*1048576
    chunks=list(range(start,start+item.compress_size,step))
    print(f'Downloading Android release template only: {item.compress_size//1048576} MB',flush=True)
    target=base/'templates/android_release.apk';target.parent.mkdir(exist_ok=True)
    temporary=target.with_suffix('.partial');decoder=zlib.decompressobj(-15);crc=0;size=0
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool,temporary.open('wb') as out:
        futures=[pool.submit(part,p,min(p+step,start+item.compress_size)-1) for p in chunks]
        for index,future in enumerate(futures):
            data=decoder.decompress(future.result());out.write(data);crc=zlib.crc32(data,crc);size+=len(data)
            print(f'Android template: {index+1}/{len(chunks)}',flush=True)
        data=decoder.flush();out.write(data);crc=zlib.crc32(data,crc);size+=len(data)
    assert size==item.file_size and crc==item.CRC,'Template CRC failed'
    temporary.replace(target)

if not (base/'templates/android_release.apk').exists():
    release=json.load(request('https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable'))
    item=next(a for a in release['assets'] if a['name']=='Godot_v4.7.2-stable_export_templates.tpz')
    extract_remote_template(item['browser_download_url'],item['size'])
if not list((base/'jdk').glob('*/bin/java.exe')):
    entries=json.load(request('https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'))
    package=entries[0]['binary']['package']
    download(package['link'],base/'jdk.zip',package['checksum'])
    unzip(base/'jdk.zip',base/'jdk')
sdk=base/'sdk'
if not (sdk/'build-tools/35.0.1/apksigner.bat').exists():
    metadata=ET.fromstring(request('https://dl.google.com/android/repository/repository2-1.xml').read())
    item=next(p for p in metadata if p.tag.endswith('remotePackage') and p.attrib.get('path')=='build-tools;35.0.1')
    a=next(a for a in item.findall('./archives/archive') if a.findtext('host-os')=='windows')
    c=a.find('complete');checksum=c.find('checksum')
    download('https://dl.google.com/android/repository/'+c.findtext('url'),base/'build-tools.zip',checksum.text,checksum.attrib.get('type','sha1'))
    unzip(base/'build-tools.zip',base/'build-tools-unpacked')
    import shutil
    src=next((base/'build-tools-unpacked').iterdir())
    shutil.copytree(src,sdk/'build-tools/35.0.1',dirs_exist_ok=True)
if not (sdk/'platform-tools/adb.exe').exists():
    download('https://dl.google.com/android/repository/platform-tools-latest-windows.zip',base/'platform-tools.zip')
    unzip(base/'platform-tools.zip',sdk)
print('ANDROID_TOOLS_READY',flush=True)
