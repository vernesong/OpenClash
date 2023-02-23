#!/bin/bash


PLATFORM_LIST=(linux-386 linux-amd64 linux-amd64-v3 linux-armv5 linux-armv6 linux-armv7 linux-arm64 linux-mips-softfloat linux-mips-hardfloat linux-mipsle-softfloat linux-mipsle-hardfloat linux-mips64 linux-mips64le)
#VERSION=$(curl -si https://tmpclashpremiumbindary.cf |grep "clash-linux-amd64" |awk -F '.gz' '{print $1}' |awk -F '-' '{print $4}')

DOWNLOAD_PATH_1="https://tmpclashpremiumbindary.cf"
DOWNLOAD_PATH_2="https://github.com/Dreamacro/clash/releases/download/premium/"
DOWNLOAD_PATH_3="https://release.dreamacro.workers.dev/latest/"
CRTDIR=$(cd $(dirname $0); pwd)

if [ -n "$1" ]; then
	VERSION=$(curl -sL -m 10 --retry 2 https://github.com/Dreamacro/clash/releases/tag/premium |grep "/Dreamacro/clash/releases/download/premium/clash-linux-386-" |awk -F '"' '{print $2}' |awk -F 'clash-linux-386-' '{print $2}'|awk -F '.gz' '{print $1}')
else
	GZNAME="clash-latest.gz"
	curl -sL -m 10 --retry 2 "$DOWNLOAD_PATH_3"/clash-linux-amd64-latest.gz -o $CRTDIR/$GZNAME
	gzip -d $CRTDIR/$GZNAME
	chmod +x $CRTDIR/clash-latest
	VERSION=$($CRTDIR/clash-latest -v |awk -F ' ' '{print $2}')
	echo "$VERSION"
fi

rm -rf $CRTDIR/clash-linux-*
rm -rf $CRTDIR/clash-latest

for i in ${PLATFORM_LIST[@]}; do
	GZNAME="clash-$i-$VERSION.gz"
	if [ -n "$1" ]; then
		curl -sL -m 10 --retry 2 "$DOWNLOAD_PATH_2"/clash-"$i"-"$VERSION".gz -o $CRTDIR/$GZNAME
	else
		curl -sL -m 10 --retry 2 "$DOWNLOAD_PATH_3"/clash-"$i"-"latest".gz -o $CRTDIR/$GZNAME
	fi
	
	gzip -d $CRTDIR/$GZNAME
	chmod +x $CRTDIR/clash-$i-$VERSION
	mv $CRTDIR/clash-$i-$VERSION $CRTDIR/clash
	if [ "$i" == "linux-mipsle-softfloat" ] || [ "$i" == "linux-mipsle-hardfloat" ]; then
		${upx} --best $CRTDIR/clash 2>/dev/null
	else
		${upx} --lzma --best $CRTDIR/clash 2>/dev/null
	fi
	gzip -c $CRTDIR/clash > $CRTDIR/$GZNAME
	rm -rf $CRTDIR/clash
done
echo "$VERSION"

