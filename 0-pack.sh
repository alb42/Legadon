#!/bin/bash -e

mkdir -p lib
# Amiga 68020
echo "compile Amiga 020"
mkdir -p lib/m68k-amiga
rm -f package/Legadon/Legadon
rm -f package/Legadon$1.lha
fpc4amiga.sh -XX -Xs -CX -O3 -B -FUlib/m68k-amiga Legadon.lpr >msg.log
m68k-amigaos-strip --strip-all Legadon
rm -f package/Legadon/*.res
cp Legadon package/Legadon/
cd package
lha ao5 Legadon$1.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1.lha
cd ..

# Amiga 68000
echo "compile Amiga 000"
rm -f package/Legadon/Legadon
rm -f package/Legadon$1_000.lha
fpc4amiga000.sh -XX -Xs -CX -O3 -B -FUlib/m68k-amiga Legadon.lpr -opackage/Legadon/Legadon >>msg.log
m68k-amigaos-strip --strip-all package/Legadon/Legadon
rm -f package/Legadon/*.res
cd package
lha ao5 Legadon$1_000.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1_000.lha
cd ..

# AROS i386
echo "compile AROS i386"
mkdir -p lib/i386-aros
rm -f package/Legadon/Legadon
rm -f package/Legadon$1_AROS.lha
fpc4aros.sh -XX -Xs -CX -O3 -B -FUlib/i386-aros Legadon.lpr -opackage/Legadon/Legadon >>msg.log
rm -f package/Legadon/*.res
cd package
lha ao5 Legadon$1_AROS.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1_AROS.lha
cd ..

# AROS x64
echo "compile AROS x64"
mkdir -p lib/x86_64-aros
rm -f package/Legadon/Legadon
rm -f package/Legadon$1_AROS64.lha
fpc4aros64.sh -XX -Xs -CX -O3 -B -FUlib/x86_64-aros Legadon.lpr -opackage/Legadon/Legadon >>msg.log
rm -f package/Legadon/*.res
cd package
lha ao5 Legadon$1_AROS64.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1_AROS64.lha
cd ..

# AROS ARM
echo "compile AROS ARM"
mkdir -p lib/arm-aros
rm -f package/Legadon/Legadon
rm -f package/Legadon$1_AROSARM.lha
fpc4arosarm.sh -XX -Xs -CX -O3 -B -FUlib/arm-aros Legadon.lpr -opackage/Legadon/Legadon >>msg.log
rm -f package/Legadon/*.res
cd package
lha ao5 Legadon$1_AROSARM.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1_AROSARM.lha
cd ..

# MorphOS
echo "compile MorphOS"
mkdir -p lib/powerpc-morphos
rm -f package/Legadon/Legadon
rm -f package/Legadon$1_MorphOS.lha
fpc4mos.sh -XX -Xs -CX -O3 -B -FUlib/powerpc-morphos Legadon.lpr -opackage/Legadon/Legadon >>msg.log
rm -f package/Legadon/*.res
cd package
lha ao5 Legadon$1_MorphOS.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1_MorphOS.lha
cd ..

# OS4
echo "compile OS 4"
mkdir -p lib/powerpc-amiga
rm -f package/Legadon/Legadon
rm -f package/Legadon$1_OS4.lha
fpc4os4.sh -XX -Xs -CX -O3 -B -XV -Avasm -FUlib/powerpc-amiga Legadon.lpr -opackage/Legadon/Legadon >>msg.log
rm -f package/Legadon/*.res
cd package
lha ao5 Legadon$1_OS4.lha Legadon/ Legadon.info >>../msg.log
du -h Legadon$1_OS4.lha
cd ..

echo "all done."