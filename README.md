# ci_windows_cuda
[![github action](https://github.com/yhmtsai/ci_windows_cuda/workflows/windows-build/badge.svg)](https://github.com/yhmtsai/ci_windows_cuda/actions?query=workflow%3Awindows-build)
[![gitlab ci](https://gitlab.com/yhmtsai/ci_windows_cuda/badges/master/pipeline.svg)](https://gitlab.com/yhmtsai/ci_windows_cuda/pipelines)

This repo creates the dockerfiles for using cuda in windows docker and provides the gitlab CI and github action setting. Moreover, share my experience/questions/failure during make them work.

The docker images are availble in the docker hub https://hub.docker.com/repository/docker/yhmtsai/windows_cuda

Pull images:
`docker pull yhmtsai/windows_cuda:windows_1903` or `docker pull yhmtsai/windows_cuda:windows_server_ltsc2019` or `docker pull yhmtsai/windows_cuda:windows_server_ltsc2022`

Run powershell:
`docker run -it --rm yhmtsai/windows_cuda:tag powershell`

Run cmd:
`docker run -it --rm yhmtsai/windows_cuda:tag cmd`

Build the docker images:
`docker build -t image_name -m 2GB -f dockerfile_name .`

They should work for different windows/cuda version. Changing the MSVC version (2017 or others) needs to find the correct integration path.
# Docker Image
## Windows
Windows containers only needs `choco install cuda` and copy the MSVC related files to the corresponding path.
## Windows Server
According to the [documentation](https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019), use mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022 not mcr.microsoft.com/windows/servercore:ltsc2022 as base image. Otherwise, installing MSVC requires reboot to lead the failure.

Note. using `"` in dockerfile of windows server gives some error.
### CUDA
Use `choco install cuda` or local installer for everything is failed.

Use local installer to install the cuda library without MSVC integration and then copy the files to the corresponding path.
In the Dockerfiles, the installer is downloaded using `Invoke-WebRequest` to avoid
issues seen when using `curl.exe` on some Windows Server configurations.
When using the local installer, use block command and get the return code.

powershell:

`Start-Process -FilePath "path/to/cuda/setup" -ArgumentList "argument -s ...." -Wait -NoNewWindow` and use `echo $?` to get the return code.

cmd:

`start /wait path/to/cuda/setup argument-list-seperated-by-space` and use `echo %errorlevel%` to get the return code.

# Gitlab CI
Gitlab introduces Windows Virtual Machine shared runner.

It only has windows server version, the steps are similar to Docker Windows Server. i.e. `choco install cuda -y` does not work.

Running `choco install cmake -y` with `--installargs '"ADD_CMAKE_TO_PATH=System"'` or `--installargs '"ADD_CMAKE_TO_PATH=User"'` and `refreshenv` doesn't set the CMake Path like docker, so use `$env:PATH="C:\Program Files\CMake\bin;$env:PATH"` to set cmake in powershell.

Note. `$env:..=...` is only valid in current session, so using it in dockerfile does not affect the running environment.

Note. Gitlab CI does not set `refreshenv` properly. Besides `$env:PATH="C:\Program Files\CMake\bin;$env:PATH"`, use the following to set `refreshenv` properly from [reference](https://stackoverflow.com/questions/46758437/how-to-refresh-the-environment-of-a-powershell-session-after-a-chocolatey-instal).
```
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
```

Note. I try to use gitlab variable in powershell cmake, but it does not work by using ${VARNAME} $VARNAME. Thus, need to specify each jobs variable individually.

# Github Action
Because Github action does not use MSVC buildtools, using `choco install cuda -y` works well without copying integration.
The environment in different step are the same, so needs to use `refreshenv` to get correct environmet, set correct environment manually, or use `set-env` from [Github Action](https://help.github.com/en/actions/reference/development-tools-for-github-actions#set-an-environment-variable-set-env)


# Test in Docker: using [Ginkgo Project](https://github.com/ginkgo-project/ginkgo)
The following is run in `cmd`. Runing it in powershell needs to another way to initial environment.

using server version needs the following setting. (I try several ways to update PATH but all leads the failure. Thus, need to set environment of cuda first)
```
set PATH=%ProgramFiles%\NVIDIA GPU Computing Toolkit\CUDA\v12.2\bin;%PATH%
set CUDA_PATH=%ProgramFiles%\NVIDIA GPU Computing Toolkit\CUDA\v12.2
set CUDA_PATH_V12_2=%ProgramFiles%\NVIDIA GPU Computing Toolkit\CUDA\v12.2
```

The test:
```
"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
git clone https://github.com/ginkgo-project/ginkgo && cd ginkgo && mkdir build && cd build
set PATH=C:/ginkgo/build/windows_shared_library;%PATH%
cmake -DGINKGO_BUILD_CUDA=ON -DGINKGO_BUILD_OMP=OFF ..
cmake --build . --config Release
ctest . -C Release
```

The compiliation of cuda works.

Note. the ctest gets error because we do not have cuda device inside the container.

# NOTE: find the corresponding path of MSVC integration
`choco install cuda` install integration into the path mentioned in the cuda documentation. However, it seems to work on MSVC IDE not MSVC buildtools. (I do not find the proper way to install MSVC IDE with `vcvars64.bat` environment. I only found using MSVC buildtools to compile project)

In my experience, if the cmake reports `CUDA Toolkit Not Found`, use `cmake -T cuda=12.2` toolchain setting may give the hint of the path.

Delete the last line of windows_1903.dockerfile, and try to use `cmake -T cuda=12.2 -DCMAKE_CUDA_COMPILER="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v12.2/bin/nvcc.exe" -DGINKGO_BUILD_CUDA=ON -DGINKGO_BUILD_OMP=OFF ..` (cmake can not find CUDA_COMPILER when set -T, so needs `-DCMAKE_CUDA_COMPILER=...`) on Ginkgo Project.

The error message:
```
error MSB4019:
The imported project "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160\BuildCustomizations\CUDA 12.2.props" was not found.
Confirm that the expression in the Import declaration "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160\\BuildCustomizations\CUDA 12.2.props" is correct, and that the file exists on disk.
```

cmake tries to finds `CUDA 12.2.props` in `C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160\BuildCustomizations`

Thus, we need to copy integration in `C:\Program Files (x86)\MSBuild\Microsoft.Cpp\v4.0\BuildCustomizations\*.*` in original correct path or `cuda\CUDAVisualStudioIntegration\extras\visual_studio_integration\MSBuildExtensions\*.*` the extraction of local installer to the corresponding path `C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VC\v160\BuildCustomizations`

