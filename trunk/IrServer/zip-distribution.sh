#!/bin/sh -
VERSION=0_2
cd ..
rm -f IrServerSB-$VERSION.zip
zip -Dr IrServerSB-$VERSION.zip IrServer/*.* -x IrServer/CVS/* IrServer/devices/CVS/* IrServer/.cvsignore IrServer/zip-distribution.bat
cd IrServer
