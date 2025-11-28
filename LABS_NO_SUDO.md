# Running RISC-V SimpleOS on Lab Machines Without Sudo Access

## Problem
Lab machines often restrict sudo access. You cannot run:
```bash
sudo apt install gcc-riscv64-unknown-elf
```

## Solutions

### Option 1: Request System Administrator
Contact your lab's IT/system administrator with this request:

> I need the following packages installed for OS development coursework:
> - gcc-riscv64-unknown-elf (RISC-V compiler)
> - qemu-system-misc (QEMU emulator)
> - make (build tool)
>
> These are standard packages in Ubuntu/Debian repositories:
> ```bash
> sudo apt update
> sudo apt install gcc-riscv64-unknown-elf qemu-system-misc make
> ```

**Why this works**: Most labs have pre-installed versions or can install system-wide.

---

### Option 2: Use Module/Module System

Many labs use `module` or `lmod` for managing software versions. Try:

```bash
# List available modules
module avail

# Look for RISC-V compiler or cross-compilers
module avail riscv
module avail gcc

# Load if available
module load gcc-riscv64-unknown-elf
module load qemu

# Verify
riscv64-unknown-elf-gcc --version
```

---

### Option 3: Use Pre-Compiled Binaries

Some universities host pre-compiled RISC-V toolchains:

```bash
# Check if your institution provides one
# Often at: /opt/risc-v/ or /usr/local/risc-v/

ls /opt/risc-v*/bin/riscv64-unknown-elf-gcc 2>/dev/null || echo "Not found"
```

---

### Option 4: Use Docker/Container (If Available)

If your lab has Docker or Singularity:

```bash
# Check if Docker is available
docker --version

# Pull pre-built RISC-V image
docker pull riscv/riscv-tools:latest

# Run the OS project inside container
docker run -v $(pwd):/workspace -it riscv/riscv-tools:latest
cd /workspace && make && make run
```

---

### Option 5: Build from Source (Last Resort)

**Only do this if absolutely necessary - takes 1-2 hours**

```bash
# Clone RISC-V toolchain
git clone https://github.com/riscv/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain

# Configure for user install (no sudo needed)
./configure --prefix=$HOME/.local/riscv-tools

# Build (takes 1-2 hours)
make

# Add to PATH
echo 'export PATH=$HOME/.local/riscv-tools/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Verify
riscv64-unknown-elf-gcc --version
```

For QEMU:
```bash
git clone https://github.com/qemu/qemu.git
cd qemu
./configure --prefix=$HOME/.local/qemu --target-list=riscv64-softmmu
make -j$(nproc)
make install
echo 'export PATH=$HOME/.local/qemu/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

---

## Step-by-Step for Option 1 (Recommended)

### For Students
1. Open a terminal on the lab machine
2. Run:
   ```bash
   cat > /tmp/install-request.txt << 'EOF'
   Requested packages for RISC-V OS coursework:
   - gcc-riscv64-unknown-elf
   - qemu-system-misc
   - make

   Installation command:
   sudo apt update && sudo apt install -y gcc-riscv64-unknown-elf qemu-system-misc make
   EOF
   ```
3. Email to IT or submit through your lab's support system
4. Usually approved within 1 business day

### For TAs/Instructors
You have several options:

**A) Pre-install on lab machines**
```bash
#!/bin/bash
# Run as root once to set up for all students
sudo apt update
sudo apt install -y gcc-riscv64-unknown-elf qemu-system-misc make
```

**B) Create lab setup script**
Create `/opt/setup-risc-v.sh` (root-owned, executable):
```bash
#!/bin/bash
apt update && apt install -y gcc-riscv64-unknown-elf qemu-system-misc make
```

Then students can request sudo for just this script:
```
/opt/setup-risc-v.sh
```

**C) Use Docker image**
Create a Dockerfile and pre-build image for all students.

---

## Checking What's Already Installed

Try these commands first - your lab might already have RISC-V tools:

```bash
# Check for RISC-V compiler
which riscv64-unknown-elf-gcc
which riscv64-linux-gnu-gcc

# Check for QEMU
which qemu-system-riscv64

# Check for Make
which make

# Check environment modules
module list
module avail | grep -i riscv
module avail | grep -i gcc
```

---

## If Tools Are Unavailable

### Temporary Workaround (For Testing/Submission)
You can still view and understand the code, but won't be able to compile/run:

```bash
# Review the code
cat kernel.c | head -50

# Run tests on submitted code (if available)
ls -la *.c *.S *.h *.ld

# Understand build process
cat makefile
```

### For Submission
Submit your code and explain in README:
- Lab machine constraints
- Which tools were unavailable
- How you tested (if you had access elsewhere)
- Build commands that would be used if tools were available

Most instructors understand lab constraints and will not penalize for environment limitations.

---

## Quick Checklist

- [ ] Check if `riscv64-unknown-elf-gcc` is installed: `which riscv64-unknown-elf-gcc`
- [ ] Check if `qemu-system-riscv64` is installed: `which qemu-system-riscv64`
- [ ] Check available modules: `module avail`
- [ ] Ask IT to install packages (provide email/form)
- [ ] Check /opt/ directories for pre-compiled tools
- [ ] Use Docker if available
- [ ] Build from source only as last resort

---

## Example Lab IT Request Email

Subject: Software Installation Request for CS Course (RISC-V OS Development)

> Dear IT Support,
>
> I am requesting the installation of the following open-source packages for a coursework assignment in RISC-V Operating Systems development:
>
> **Packages to install:**
> - gcc-riscv64-unknown-elf (RISC-V cross-compiler)
> - qemu-system-misc (CPU emulator)
> - make (build automation tool)
>
> **Installation command:**
> ```bash
> sudo apt update
> sudo apt install -y gcc-riscv64-unknown-elf qemu-system-misc make
> ```
>
> These are standard packages available in Ubuntu repositories with no security concerns.
>
> **Use case:** Educational OS development project demonstrating boot sequences, memory management, interrupts, multitasking, and syscalls.
>
> Thank you,
> [Your Name]
> [Lab Machine ID: cocsce-l3d22-18]
> [Course: OS Development]

---

## Still Stuck?

If none of these options work:

1. **Ask your instructor** - They may have special arrangements or test systems
2. **Use personal machine** - Most modern laptops can run QEMU
3. **Use cloud VM** - Digital Ocean, AWS, etc. have free/cheap Ubuntu VMs
4. **Virtual machine** - VirtualBox/VMware with Ubuntu on your laptop
5. **WSL2 on Windows** - Windows Subsystem for Linux (if Windows machine available)

You'll get RISC-V tools working - it's just a matter of finding the right environment!
