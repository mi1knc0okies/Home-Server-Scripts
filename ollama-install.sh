#!/usr/bin/env bash

set -e

# Color output functions
msg_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
msg_ok() { echo -e "\033[1;32m[OK]\033[0m $1"; }
msg_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# Update 
msg_info "Updating system"
apt update && apt upgrade -y

msg_info "Installing Dependencies"
apt install -y \
  build-essential \
  pkg-config \
  zstd \
  curl \
  gpg
msg_ok "Installed Dependencies"

# Intel GPU Setup
msg_info "Setting up Intel® GPU Repositories"
mkdir -p /usr/share/keyrings

curl -fsSL https://repositories.intel.com/gpu/intel-graphics.key | \
  gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg

cat <<'EOF' >/etc/apt/sources.list.d/intel-gpu.sources
Types: deb
URIs: https://repositories.intel.com/gpu/ubuntu
Suites: jammy
Components: client
Architectures: amd64 i386
Signed-By: /usr/share/keyrings/intel-graphics.gpg
EOF

curl -fsSL https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
  gpg --dearmor -o /usr/share/keyrings/oneapi-archive-keyring.gpg

cat <<'EOF' >/etc/apt/sources.list.d/oneAPI.sources
Types: deb
URIs: https://apt.repos.intel.com/oneapi
Suites: all
Components: main
Signed-By: /usr/share/keyrings/oneapi-archive-keyring.gpg
EOF

apt update
msg_ok "Set up Intel® Repositories"

msg_info "Installing Intel® Level Zero"
if [[ -f /etc/debian_version ]] && [[ $(cat /etc/debian_version | cut -d. -f1) -ge 13 ]]; then
  apt install -y libze1 libze-dev intel-level-zero-gpu || true
else
  apt install -y intel-level-zero-gpu level-zero level-zero-dev || true
fi
msg_ok "Installed Intel® Level Zero"

msg_info "Installing Intel® oneAPI Base Toolkit (This takes a while...)"
apt install -y --no-install-recommends intel-basekit-2024.1
msg_ok "Installed Intel® oneAPI Base Toolkit"

# Ollama Installer 
msg_info "Installing Ollama via Official Installer"
curl -fsSL https://ollama.com/install.sh | sh
msg_ok "Installed Ollama"

# Intel GPU service override 
msg_info "Configuring Ollama for Intel GPU"
mkdir -p /etc/systemd/system/ollama.service.d

cat <<'EOF' >/etc/systemd/system/ollama.service.d/intel-gpu.conf
[Service]
Environment=OLLAMA_INTEL_GPU=true
Environment=OLLAMA_HOST=0.0.0.0
Environment=OLLAMA_NUM_GPU=999
Environment=SYCL_CACHE_PERSISTENT=1
Environment=ZES_ENABLE_SYSMAN=1
Environment=OLLAMA_MAX_LOADED_MODELS=1
Environment=OLLAMA_KEEP_ALIVE=5m
EOF

systemctl daemon-reload
systemctl restart ollama
msg_ok "Configured Ollama for Intel GPU"

# Verify
msg_info "Verifying Installation"
sleep 3
if systemctl is-active --quiet ollama; then
  msg_ok "Ollama is running"
  ollama --version || true
else
  msg_error "Ollama failed to start"
  systemctl status ollama
fi

msg_ok "Installation Complete!"
echo "Access Ollama at: http://$(hostname -I | awk '{print $1}'):11434"
