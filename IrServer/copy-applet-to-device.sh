#!/bin/sh -
# This is used for even faster iteration -- see copy-to-device.sh for the first copy
# On device, as root must do:
# mkdir /usr/share/jive/applets/IrServer
scp IrServer*.lua root@192.168.0.74:/usr/share/jive/applets/IrServer/.
