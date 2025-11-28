#!/bin/bash
# RISC-V SimpleOS Lab Setup Script
# This script automates the installation of all required tools on Ubuntu/Debian
# Usage: bash setup-lab.sh

set -e  # Exit on any error

echo "======================================"
echo "RISC-V SimpleOS Lab Environment Setup"
echo "======================================"
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running on Ubuntu/Debian
if ! command -v apt-get &> /dev/null; then
    print_error "This script requires Ubuntu or Debian"
    echo "For other systems, manually install:"
    echo "  - gcc-riscv64-unknown-elf (RISC-V compiler)"
    echo "  - qemu-system-misc (QEMU)"
    echo "  - make (build tool)"
    exit 1
fi

print_status "Detected Ubuntu/Debian system"
echo ""

# Step 1: Update package list
echo "Step 1/4: Updating package list..."
sudo apt update
print_status "Package list updated"
echo ""

# Step 2: Install RISC-V compiler
echo "Step 2/4: Installing RISC-V compiler..."
if command -v riscv64-unknown-elf-gcc &> /dev/null; then
    print_status "RISC-V compiler already installed"
else
    sudo apt install -y gcc-riscv64-unknown-elf
    if command -v riscv64-unknown-elf-gcc &> /dev/null; then
        print_status "RISC-V compiler installed successfully"
    else
        print_warning "gcc-riscv64-unknown-elf not found, trying alternative..."
        sudo apt install -y gcc-riscv64-linux-gnu
        print_status "Alternative compiler installed (gcc-riscv64-linux-gnu)"
    fi
fi
echo ""

# Step 3: Install QEMU
echo "Step 3/4: Installing QEMU..."
if command -v qemu-system-riscv64 &> /dev/null; then
    print_status "QEMU already installed"
else
    sudo apt install -y qemu-system-misc
    print_status "QEMU installed successfully"
fi
echo ""

# Step 4: Install build tools
echo "Step 4/4: Installing build tools..."
if command -v make &> /dev/null; then
    print_status "Make already installed"
else
    sudo apt install -y build-essential
    print_status "Build tools installed successfully"
fi
echo ""

# Verify installation
echo "======================================"
echo "Verifying Installation"
echo "======================================"
echo ""

INSTALL_SUCCESS=true

if command -v riscv64-unknown-elf-gcc &> /dev/null; then
    COMPILER_VERSION=$(riscv64-unknown-elf-gcc --version | head -n1)
    print_status "Compiler: $COMPILER_VERSION"
elif command -v riscv64-linux-gnu-gcc &> /dev/null; then
    COMPILER_VERSION=$(riscv64-linux-gnu-gcc --version | head -n1)
    print_warning "Compiler: $COMPILER_VERSION (alternative)"
else
    print_error "No RISC-V compiler found"
    INSTALL_SUCCESS=false
fi

if command -v qemu-system-riscv64 &> /dev/null; then
    QEMU_VERSION=$(qemu-system-riscv64 --version | head -n1)
    print_status "QEMU: $QEMU_VERSION"
else
    print_error "QEMU not found"
    INSTALL_SUCCESS=false
fi

if command -v make &> /dev/null; then
    MAKE_VERSION=$(make --version | head -n1)
    print_status "Make: $MAKE_VERSION"
else
    print_error "Make not found"
    INSTALL_SUCCESS=false
fi

echo ""

if [ "$INSTALL_SUCCESS" = true ]; then
    echo "======================================"
    print_status "Installation Complete!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "  1. cd myos"
    echo "  2. make"
    echo "  3. make run"
    echo ""
    echo "To exit QEMU: Press Ctrl+A, then X"
    exit 0
else
    echo "======================================"
    print_error "Installation had issues"
    echo "======================================"
    echo ""
    echo "Please check the output above for errors"
    exit 1
fi
