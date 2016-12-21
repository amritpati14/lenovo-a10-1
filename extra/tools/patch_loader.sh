#!/bin/bash

OFFSET=$((0xA0))
INJECT=$((0x224))

JUMP1=$(( (0x2B0 - (OFFSET + 3*4) - 8) / 4 ))
JUMP1=$(printf "0xEB00%04X" $JUMP1)

cat <<END_PATCH | arm-linux-gnueabi-as -mcpu=cortex-a9 -march=armv7-a -o _patch
MOV     R0, #0
MOV     R1, #0x64000000
ADD     R2, R1, #0x2800
.word   $JUMP1

LDR     R0, =0x10080000
LDR     PC, =0x60000228
END_PATCH

arm-linux-gnueabi-objcopy -O binary _patch _patch.bin

FN=$1
SIZE=$(stat -c %s $FN)
PATCHSIZE=$(stat -c %s _patch.bin)
PATCHED=$FN".patched"
JUMP=$(( 0xFFFFFF - (INJECT - OFFSET + 8) / 4 + 1)) 
JUMP=$(printf "%06X" $JUMP | sed 's/\(..\)\(..\)\(..\)/\3\2\1/')

dd if=$FN ibs=1 count=$OFFSET of=$PATCHED 2>&-
cat _patch.bin >> $PATCHED

dd if=$FN ibs=1 skip=$(( OFFSET+PATCHSIZE )) count=$(( INJECT - (OFFSET+PATCHSIZE) )) of=$PATCHED oflag=append conv=notrunc 2>&-
echo $JUMP | xxd -r -p >> $PATCHED
echo "EA" | xxd -r -p >> $PATCHED

dd if=$FN ibs=1 skip=$((INJECT+4)) of=$PATCHED oflag=append conv=notrunc 2>&-

rm _patch _patch.bin
