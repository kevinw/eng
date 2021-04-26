@setlocal
if not exist basis_universal git clone https://github.com/BinomialLLC/basis_universal.git
pushd basis_universal
git pull
msbuild /nologo basisu.sln /p:Configuration="Release"
popd
basis_universal\bin\basisu -version
