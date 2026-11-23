#!/usr/bin/env python3
# 把 Homebrew 的 FFmpeg 动态库及其依赖一起打包进 app 的 Contents/Frameworks/ffmpeg，
# 并把 install name 改成 @loader_path 相对引用，保证在没装 Homebrew FFmpeg 的机器上也能导出 MP4。
import os
import shutil
import subprocess
import sys


def get_deps(path):
    out = subprocess.check_output(['otool', '-L', path]).decode()
    deps = []
    for line in out.splitlines()[1:]:
        line = line.strip()
        if not line:
            continue
        dep = line.split('(')[0].strip()
        if dep.startswith('/opt/homebrew') or dep.startswith('/usr/local'):
            deps.append(dep)
    return deps


def main(app_path):
    ffdir = os.path.join(app_path, 'Contents', 'Frameworks', 'ffmpeg')
    core = {
        'libavformat.62.dylib': '/opt/homebrew/lib/libavformat.62.dylib',
        'libavcodec.62.dylib': '/opt/homebrew/lib/libavcodec.62.dylib',
        'libavutil.60.dylib': '/opt/homebrew/lib/libavutil.60.dylib',
        'libswscale.9.dylib': '/opt/homebrew/lib/libswscale.9.dylib',
        'libswresample.6.dylib': '/opt/homebrew/lib/libswresample.6.dylib',
    }

    os.makedirs(ffdir, exist_ok=True)

    # 清理上次打包残留，避免只读文件导致覆盖失败
    for name in os.listdir(ffdir):
        if name.endswith('.dylib'):
            p = os.path.join(ffdir, name)
            os.chmod(p, 0o644)
            os.remove(p)

    bundled = {}
    for plain, link in core.items():
        real = os.path.realpath(link)
        shutil.copy2(real, os.path.join(ffdir, plain))
        bundled[real] = plain

    queue = list(bundled.keys())
    while queue:
        p = queue.pop()
        for d in get_deps(p):
            real = os.path.realpath(d) if os.path.exists(d) else d
            if real in bundled:
                continue
            base = os.path.basename(real)
            shutil.copy2(real, os.path.join(ffdir, base))
            bundled[real] = base
            queue.append(real)

    for real, plain in bundled.items():
        dest = os.path.join(ffdir, plain)
        subprocess.run(['install_name_tool', '-id', f'@loader_path/{plain}', dest], check=True)

    for real, plain in bundled.items():
        dest = os.path.join(ffdir, plain)
        for d in get_deps(dest):
            dreal = os.path.realpath(d) if os.path.exists(d) else d
            if dreal in bundled:
                dep_plain = bundled[dreal]
                subprocess.run(['install_name_tool', '-change', d, f'@loader_path/{dep_plain}', dest], check=True)

    print(f'bundle_ffmpeg: bundled {len(bundled)} dylibs into {ffdir}')


if __name__ == '__main__':
    main(sys.argv[1])
