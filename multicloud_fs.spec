block_cipher = None

a = Analysis(
    ['src/main.py'],
    pathex=['.'],
    binaries=[('src/*.so', '.')],
    datas=[],
    hiddenimports=[
        'fuse',
        'grpc',
        'redis',
        'google',
        'google.protobuf',
        'google.protobuf.descriptor',
        'google.protobuf.message',
        'argparse',
        'threading',
        'os',
    ],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='multicloud_fs',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
)