#!/usr/bin/env bash


SRC=linux-3.0.36
TGT=linux-3.0.65



CURRENT=
PREVIOUS=
NEXT=


mkdir -p ./.merge


for fname in `diff -qr ${SRC} ${TGT} | grep "^Files " | sed "s/Files linux\-3\.0\.36\/\(.*\) and.*/\1/"`; do

	NEXT=${fname}

	if [ ! -z "${CURRENT}" ]; then

		CHECK="r"

		diff -DOLDKERNEL ${SRC}/${CURRENT} ${TGT}/${CURRENT} > ./.tmp

		FIXED=`echo ${CURRENT} | sed "s/\//_/g"`
		FIXED="./.merge/${FIXED}"

		while [ "${CHECK}" == "r" -a ! -f ${FIXED} ]; do

			clear

			diff ${SRC}/${CURRENT} ${TGT}/${CURRENT}

			echo "( current = ${CURRENT}, next = ${NEXT} )"
			echo "(1) accept the left, (9) accept the right"
			echo "(s) save, (r) redo, (w) write and quit"
			echo "(e) edit the output"
			echo "(d) show the diff"
			echo "(m) merge"
			echo "(n) next (default)"
			echo -n "(q) quit ?   "

			read CHECK

			if [ "${CHECK}" == "m" ]; then
				sdiff -o ./.tmp -W -B ${SRC}/${CURRENT} ${TGT}/${CURRENT}
				CHECK="r";
				continue;
			fi;

			if [ "${CHECK}" == "e" ]; then
				vim ./.tmp
				CHECK="r";
				continue;
			fi;

			if [ "${CHECK}" == "d" -o "${CHECK}" == "r" ]; then
				CHECK="r";
				continue;
			fi;



			if [ "${CHECK}" == "s" ]; then
				cp -f ./.tmp ${TGT}/${CURRENT}
				touch ${FIXED}
				break;
			fi;

			if [ "${CHECK}" == "w" ]; then
				cp -f ./.tmp ${TGT}/${CURRENT}
				touch ${FIXED}
				exit;
			fi;

			if [ "${CHECK}" == "q" ]; then
				exit;
			fi;

			if [ "${CHECK}" == "1" ]; then
				cp -f ${SRC}/${CURRENT} ${TGT}/${CURRENT}
				touch ${FIXED}
				break;
			fi;

			if [ "${CHECK}" == "9" ]; then
				touch ${FIXED}
				break;
			fi;


			if [ "${CHECK}" != "n" ]; then
				break;
			fi;

		done;

	fi

	PREVIOUS=${CURRENT}
	CURRENT=${NEXT}
	NEXT=

done;






