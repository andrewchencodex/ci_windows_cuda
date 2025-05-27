# Build and test the Windows Server 2022 CUDA Docker image

# Build the Docker image from the Windows Server 2022 dockerfile.
docker build -m 2GB -f windows_server_ltsc2022.dockerfile -t windows_server_ltsc2022 .

# Run the image interactively and execute nvidia-smi to verify CUDA installation.
docker run -it --rm windows_server_ltsc2022 powershell -Command "nvidia-smi"
