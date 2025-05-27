# Build the Windows Server 2022 CUDA Docker image

# Invoke docker build using the Windows Server 2022 dockerfile.
# The resulting image is tagged with `windows_server_ltsc2022`.

docker build -m 2GB -f windows_server_ltsc2022.dockerfile -t windows_server_ltsc2022 .
