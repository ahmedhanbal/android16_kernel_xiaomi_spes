#!/bin/bash
# Build script: base (16) + suNext (16-ksun)
set -e

# --------------------------
# Argument Required
# --------------------------
if [ -z "$1" ]; then
  echo "Error: No build variant specified!"
  echo
  echo "Usage:"
  echo "  ./build.sh base"
  echo "  ./build.sh suNext"
  echo "  ./build.sh susNext"
  echo "  ./build.sh all"
  exit 1
fi


TARGET="$1"

# --------------------------
# Setup
# --------------------------
KERNEL_ROOT=$(pwd)
OUTDIR="$KERNEL_ROOT/out"
DATE_TIME=$(TZ="Asia/Karachi" date +"%d%m%y-%H%M%S")

MAKE_ARGS="
O=out
CC=clang
LD=ld.lld
LLVM=1
LLVM_IAS=1
ARCH=arm64
SUBARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
CROSS_COMPILE_ARM32=arm-linux-gnueabi-
"

# --------------------------
# Variants to build
# --------------------------
if [ "$TARGET" == "all" ]; then
  VARIANTS=("suNext" "susNext" "base")
elif [ "$TARGET" == "base" ] || [ "$TARGET" == "suNext" ] || [ "$TARGET" == "susNext" ]; then
  VARIANTS=("$TARGET")
else
  echo "Error: Invalid variant '$TARGET'"
  echo
  echo "Valid options: base | suNext | all"
  exit 1
fi

# --------------------------
# Branch mapping
# --------------------------
get_branch() {
  case "$1" in
    base)   echo "16" ;;
    suNext) echo "16" ;;
    susNext) echo "16-ksun-susfs" ;;
  esac
}

# --------------------------
# Clone AnyKernel once
# --------------------------
if [ ! -d "anykernel-template" ]; then
  echo "Cloning AnyKernel template..."
  git clone --depth=1 https://github.com/ahmedhanbal/anykernel anykernel-template
  rm -rf anykernel-template/.git
fi

# --------------------------
# Build Loop
# --------------------------
for VARIANT in "${VARIANTS[@]}"; do
  echo "========================================="
  echo " Building Variant: $VARIANT"
  echo "========================================="

  BRANCH=$(get_branch "$VARIANT")

  echo "Switching to branch: $BRANCH"
  git checkout "$BRANCH"
  if [ "$VARIANT" == "base" ]; then
	rm -rf KernelSU-Next > /dev/null 2>&1
  fi
  # --------------------------
  # Defconfig
  # --------------------------
  make $MAKE_ARGS vendor/spes-perf_defconfig

  # --------------------------
  # Variant LOCALVERSION
  # --------------------------
  LOCALV="-$VARIANT"

  # --------------------------
  # Compile Kernel
  # --------------------------
  echo "Compiling kernel..."
  make -j$(nproc --all) $MAKE_ARGS LOCALVERSION=$LOCALV Image.gz-dtb dtbo.img

  # --------------------------
  # Prepare AnyKernel Folder
  # --------------------------
  ANYKERNEL_DIR="anykernel-$VARIANT"
  rm -rf "$ANYKERNEL_DIR"
  cp -r anykernel-template "$ANYKERNEL_DIR"

  # Copy outputs
  cp "$OUTDIR/arch/arm64/boot/Image.gz-dtb" "$ANYKERNEL_DIR/"
  cp "$OUTDIR/arch/arm64/boot/dtbo.img" "$ANYKERNEL_DIR/"

  # --------------------------
  # Patch kernel.string in anykernel.sh
  # --------------------------
  echo "Patching anykernel.sh kernel string..."
  sed -i "s/^kernel.string=.*/kernel.string=hanbal-murali-$VARIANT/" \
    "$ANYKERNEL_DIR/anykernel.sh"

  # --------------------------
  # Zip Packaging
  # --------------------------
  ZIPNAME="hanbal-murali-${VARIANT}-${DATE_TIME}.zip"

  echo "Creating flashable zip: $ZIPNAME"

  (
    cd "$ANYKERNEL_DIR"
    zip -r9 "../$ZIPNAME" . -x "*.git*"
  )

  echo "Done: $ZIPNAME created!"
  echo
done

echo "========================================="
echo " Build Finished Successfully"
echo "========================================="
ls -lh hanbal-murali-*-${DATE_TIME}.zip
