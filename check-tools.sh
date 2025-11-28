#!/bin/bash
# Tool availability checker - requires NO sudo access
# Run this on lab machines to see what RISC-V tools are available

echo "=========================================="
echo "RISC-V SimpleOS Tool Checker"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FOUND_ALL=1

# Check RISC-V compiler
echo -n "RISC-V Compiler: "
if command -v riscv64-unknown-elf-gcc &> /dev/null; then
    VERSION=$(riscv64-unknown-elf-gcc --version | head -n1)
    echo -e "${GREEN}✓ Found${NC}"
    echo "  $VERSION"
else
    echo -e "${RED}✗ Not found${NC}"
    FOUND_ALL=0
    # Check alternatives
    if command -v riscv64-linux-gnu-gcc &> /dev/null; then
        echo -e "${YELLOW}  But found: riscv64-linux-gnu-gcc (alternative)${NC}"
        riscv64-linux-gnu-gcc --version | head -n1 | sed 's/^/  /'
    fi
fi
echo ""

# Check QEMU
echo -n "QEMU RISC-V: "
if command -v qemu-system-riscv64 &> /dev/null; then
    VERSION=$(qemu-system-riscv64 --version | head -n1)
    echo -e "${GREEN}✓ Found${NC}"
    echo "  $VERSION"
else
    echo -e "${RED}✗ Not found${NC}"
    FOUND_ALL=0
fi
echo ""

# Check Make
echo -n "Make: "
if command -v make &> /dev/null; then
    VERSION=$(make --version | head -n1)
    echo -e "${GREEN}✓ Found${NC}"
    echo "  $VERSION"
else
    echo -e "${RED}✗ Not found${NC}"
    FOUND_ALL=0
fi
echo ""

# Check module system
echo "Module System:"
if command -v module &> /dev/null; then
    echo -e "${GREEN}✓ Module system available${NC}"
    echo ""
    echo "  Available modules related to RISC-V or compilers:"
    module avail 2>&1 | grep -i "riscv\|gcc\|compiler" | head -10 || echo "    (none found)"
else
    echo -e "${RED}✗ Module system not available${NC}"
fi
echo ""

# Check for pre-compiled toolchains in common locations
echo "Checking common installation paths:"
FOUND_CUSTOM=0
for dir in /opt /usr/local /opt/risc-v*; do
    if [ -d "$dir" ] && [ -f "$dir/bin/riscv64-unknown-elf-gcc" 2>/dev/null ]; then
        echo -e "${GREEN}✓ Found at: $dir${NC}"
        FOUND_CUSTOM=1
        echo "  $($dir/bin/riscv64-unknown-elf-gcc --version | head -n1)"
    fi
done
if [ $FOUND_CUSTOM -eq 0 ]; then
    echo -e "${YELLOW}  No pre-compiled RISC-V toolchains found in /opt${NC}"
fi
echo ""

# Check if docker is available
echo -n "Docker: "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Available${NC}"
    echo "  You can use Docker images for RISC-V tools"
else
    echo -e "${RED}✗ Not available${NC}"
fi
echo ""

# Summary
echo "=========================================="
if [ $FOUND_ALL -eq 1 ]; then
    echo -e "${GREEN}All tools found!${NC}"
    echo "You can run: make && make run"
else
    echo -e "${RED}Some tools are missing.${NC}"
    echo "Next steps:"
    echo "  1. Check LABS_NO_SUDO.md for solutions"
    echo "  2. Contact IT to request package installation"
    echo "  3. Try: module load gcc (or module avail to see available modules)"
    echo "  4. Check if Docker is available for a container-based solution"
fi
echo "=========================================="
