#!/bin/sh
XFR=`which "${XFR:-cat}"`
TTY="${TTY:-/dev/ttyUSB0}"
WIDTH="${WIDTH:-800x600}"
SPEED="${SPEED:-115200}"
PROG="${PROG}"

if [ "${IMAGE}" = "" ] ; then
	echo Image filename empty
	exit -1
fi

if [ ! -f "${IMAGE}" ] ; then
	echo Image file "${IMAGE}" not found ;
	exit -1
fi

if [ ! -c "${TTY}" ] ; then
	echo Serial port "${TTY}" not found
	exit -1
fi

if [ ! -f "${XFR}" ] ; then
	echo Binary transfer "${XFR}" no found
	exit -1
fi

echo make
make all

if [ "${PROG}" != "" ] ; then
	echo "${PROG}"
	$PROG
	sleep 1;
fi

echo Setting serial port "${TTY}"
stty -F  "${TTY}" sane
stty -F  "${TTY}" "${SPEED}" cs8 -cstopb -parenb raw -onlcr
sleep 1

echo Blanking screen 
$XFR < ./src/blank.strm > "${TTY}"
sleep 1

echo Converting "${IMAGE}" to "${WIDTH}" and sending to "${TTY}"
convert -resize "${WIDTH}" -size "${WIDTH}" "${IMAGE}" rgb:- |./bin/rgb8topixel rgb565|./bin/format 16|./bin/stream|$XFR > "${TTY}"
