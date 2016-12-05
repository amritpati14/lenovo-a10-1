#!/usr/bin/env bash

FILES=`ls -1d linux*`

for dir in ${FILES}; do

	FL=`diff -qr linux-3.0.36 $dir | wc -l`
	TL=`diff -r linux-3.0.36 $dir | wc -l`

	echo "${dir} ---->  ${FL}    ${TL}";

done;


