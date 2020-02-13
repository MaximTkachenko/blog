rmdir "pretzel" /s /q
git clone -b master git@github.com:Code52/pretzel.git
dotnet build pretzel/src/Pretzel/Pretzel.csproj -c Release
rmdir "bin" /s /q
xcopy "pretzel/src/Pretzel/bin/Release/netcoreapp2.2" "bin" /i /s /y
rmdir "pretzel" /s /q
