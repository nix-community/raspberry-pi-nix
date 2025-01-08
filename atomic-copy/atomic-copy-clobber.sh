#! @bash@/bin/sh -e

# copy+paste of copyToKernelsDir https://github.com/NixOS/nixpkgs/blob/904ecf0b4e055dc465f5ae6574be2af8cc25dec3/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.sh#L53
# but without the check which skips the copy if the destination exists

shopt -s nullglob

export PATH=/empty
for i in @path@; do PATH=$PATH:$i/bin; done

src=$(readlink -f "$1")
dst="$2"

# Create $dst atomically to prevent partially copied files
# if this script is ever interrupted.
dstTmp=$dst.tmp.$$
cp -r $src $dstTmp
mv $dstTmp $dst
