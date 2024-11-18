#! @bash@/bin/sh -e

# copy+paste of copyToKernelsDir https://github.com/NixOS/nixpkgs/blob/904ecf0b4e055dc465f5ae6574be2af8cc25dec3/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.sh#L53

shopt -s nullglob

export PATH=/empty
for i in @path@; do PATH=$PATH:$i/bin; done

src=$(readlink -f "$1")
dst="$2"

# Don't copy the file if $dst already exists.
# Also create $dst atomically to prevent partially copied files
# if this script is ever interrupted.
if ! test -e $dst; then
	dstTmp=$dst.tmp.$$
	cp -r $src $dstTmp
	mv $dstTmp $dst
fi
