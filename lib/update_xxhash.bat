@setlocal
if not exist xxHash git clone https://github.com/Cyan4973/xxHash.git
pushd xxHash
git pull
cl /nologo /c /O2 /D_HAS_EXCEPTIONS=0 xxhash.c && lib /nologo xxhash.obj /out:xxhash.lib

