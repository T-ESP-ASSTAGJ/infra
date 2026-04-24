#!/bin/bash
set -e

# Define Python version upfront
PY_V=3.12.1

# Update the ca-certificates package
sudo yum update ca-certificates

# Refresh the certificate bundle
sudo update-ca-trust extract  

# Check if Python is already installed through pyenv
if [ -f "$HOME/.pyenv/shims/python" ] && [ "$($HOME/.pyenv/shims/python --version 2>&1)" == "Python $PY_V" ]; then
  echo "Python $PY_V is already installed via pyenv. Skipping installation."
  exit 0
fi

# Proceed with installation if Python is not installed
# Prerequisite
yum install -y epel-release || echo "EPEL already installed, continuing..."

# Install development tools and dependencies
yum install -y git zlib-devel ncurses-devel bzip2-devel libffi-devel readline-devel sqlite-devel \
    xz-devel libdb-devel gdbm-devel tk-devel uuid-devel "@Development Tools"

# Install OpenSSL 1.1
yum install -y openssl11 openssl11-devel

# Install pyenv with certificate validation disabled
if [ ! -d "$HOME/.pyenv" ]; then
  curl -k https://pyenv.run | bash
else
  echo "pyenv already installed, continuing..."
fi

# Configure shell environment for pyenv
if ! grep -q "PYENV_ROOT" "$HOME/.bash_profile"; then
  cat <<'EOF' >> $HOME/.bash_profile
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"
EOF
fi

# Apply changes to current shell session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)" || true
eval "$(pyenv virtualenv-init -)" || true

# Install Python with certificate validation disabled and using OpenSSL 1.1
CPPFLAGS="$(pkg-config --cflags openssl11)" \
LDFLAGS="$(pkg-config --libs openssl11)" \
PYTHON_CONFIGURE_OPTS="--enable-shared" \
PYTHON_BUILD_ARIA2_OPTS="-k" \
pyenv install -v $PY_V

# Set as global Python version
pyenv global $PY_V