cd ..
del IrServerSB-0_2.zip
zip -Dr IrServerSB-0_2.zip IrServer/*.* -x IrServer/CVS/* IrServer/devices/CVS/* IrServer/.cvsignore IrServer/zip-distribution.bat
cd IrServer
