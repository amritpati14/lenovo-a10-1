#!/usr/bin/env bash


SRC=linux-3.0.36
TGT=linux-3.0.65




for fname in `diff -qr ${SRC} ${TGT} | grep "^Files " | sed "s/Files linux\-3\.0\.36\/\(.*\) and.*/\1/"`; do

	check="r"

	while [ "${check}" == "r" ]; do

		sdiff -o ./.tmp -W -B ${SRC}/${fname} ${TGT}/${fname}

		echo -n "(s)ave, (r)edo, (w)rite and quite, (q)uit ?  "

		read check

		if [ "${check}" == "s" ]; then
			cp -f ./.tmp ${TGT}/${fname}
		fi;

		if [ "${check}" == "w" ]; then
			cp -f ./.tmp ${TGT}/${fname}
			exit;
		fi;

		if [ "${check}" == "q" ]; then
			exit;
		fi;

		if [ "${check}" != "r" ]; then
			break;
		fi;

	done;


done;






