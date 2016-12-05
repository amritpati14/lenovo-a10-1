#!/usr/bin/env bash


SRC=linux-3.0.36
TGT=linux-3.0.65



CURRENT=
PREVIOUS=
NEXT=


for fname in `diff -qr ${SRC} ${TGT} | grep "^Files " | sed "s/Files linux\-3\.0\.36\/\(.*\) and.*/\1/"`; do

	NEXT=${fname}

	if [ ! -z "${CURRENT}" ]; then

		check="r"

		while [ "${check}" == "r" ]; do

			sdiff -o ./.tmp -W -B ${SRC}/${CURRENT} ${TGT}/${CURRENT}

			echo "( current = ${CURRENT}, next = ${NEXT} )"
			echo "(1) accept the left, (9) accept the right"
			echo "(s)ave, (r)edo, (w)rite and quit"
			echo -n "(q)uit ?   "

			read check

			if [ "${check}" == "s" ]; then
				cp -f ./.tmp ${TGT}/${CURRENT}
			fi;

			if [ "${check}" == "w" ]; then
				cp -f ./.tmp ${TGT}/${CURRENT}
				exit;
			fi;

			if [ "${check}" == "q" ]; then
				exit;
			fi;

			if [ "${check}" == "1" ]; then
				cp -f ${SRC}/${CURRENT} ${TGT}/${CURRENT}
			fi;

			if [ "${check}" != "r" ]; then
				break;
			fi;

		done;

	fi

	PREVIOUS=${CURRENT}
	CURRENT=${NEXT}
	NEXT=

done;






