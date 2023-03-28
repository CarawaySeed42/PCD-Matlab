# PCD-Matlab
Read and write PCD (Point Cloud Data) files with MATLAB
#
### Features
- Supports reading and writing of PCD files in Matlab
- Supports ascii, binary and binary_compressed data formats

#
### Requirements
- Only Matlab for reading and writing binary or ascii PCD files
- .NET Framework 4.7.2 Runtime installed for binary_compressed PCD files

#
### Build
- .NET dynamic link library already provided (```\lib\CLZF.dll```) and rebuild should not be necessary
- If you want to build it yourself:<br>
  -> Open ```...\src\CLZF\CLZF.sln``` in Visual Studio (2017 - 2022 recommended) with .NET Framework 4.7.2 Developer Pack installed<br>
  -> Build -> Rebuild Solution<br>
  -> Copy from ```\src\CLZF\bin\$(Configuration)\CLZF.dll``` to ```\lib\CLZF.dll```
  <br>
- If you can not target .NET Framework 4.7.2 choose one of the [other supported target frameworks](https://de.mathworks.com/help/compiler_sdk/dotnet/matlab-builder-ne-prerequisites.html)

#
### Credits
LZF De-/Compression algorithms by Oren J. Maurice (2005) <br>
License included in Visual Studio source and Readme.md next to VS project ( ...\src\CLZF )
