# IRServer - IrServer for the SqueezeBox Duet Controller #
(a.k.a IrServerSB)
> (SqueezeBox is a TM of Logitech and this has no affiliation with them)

# README.txt #
(see the svn repository for the very latest version)

Author: Greg J. Badros - badros@cs.washington.edu
(please mention IrServer in the subject if you write me about this)

Copyright (C) 2009 Greg J. Badros

Date: 17 May 2009
Version: 0.2 - USE AT YOUR OWN RISK - SEE LICENSE - THERE IS NO WARRANTY, NOT EVEN IMPLIED


# SUMMARY #

Send infrared remote control signals using this HTTP-like server for SqueezeBox Duet controllers.


# DESCRIPTION #

IrServerSB is a Lua-based simple HTTP-like server that runs on the
Jive framework on a Logitech SqueezeBox Duet Controller.  It listens
to commands on port 8174 and runs the experimental "/bin/testir"
program with the right arguments to send Infrared signals to your
audio/visual equipment using the Duet Controller device's IR
transmitter.  Recommended use is in conjunction with iPeng for the
iPod-touch/iPhone.  Simple conversion of Linux Infrared Remote Control
(LIRC) configuration files to a rudimentary static HTML interface
is also included.


# Files included in this distribution: #

README.txt
- This file

IrServerApplet.lua, IrServerAppletMeta.lua, strings.txt
- The source and execuatable for the IrServer applet on the SqueezeBox Duet Controller

IrServer-test.pl
- Simple test code to talk to the IrServer (either on device or on SqueezePlay emulator/soft-device)

infrared-remote-example.html
- Rudimentary and simple example of using the IrServer from an HTML page

COPYING\_GPL.txt
- The GNU Public License under which all these files are released

copy-to-device.bat copy-to-device.sh (and copy-applet-to-device.bat copy-applet-to-device.sh)
- Simple copy script (presumes you've turned remote login on on the controller you're targeting)
> to move the applet and supporting files to the right spot on the device.
> First, as root on the controller device, do a: mkdir /usr/share/jive/applets/IrServer

devices/**- RM-Y168, VSX9300 - some device files I used for testing (for a Sony TV and a Pioneer Amp)**


# GETTING STARTED #

1) Configure your SqueezeBox Duet Controller for remote login (Control Settings -> Advanced -> Remote Login -> Enable SSH).

2) ssh to the controller's IP using the root password 1234 (unless you've changed it)

3) [Optional](Optional.md) Run '/sbin/ifconfig' to find the MAC address and configure your WAP to have a consistent IP address assigned
via DHCP to the controller. I use 192.168.0.74, but you can use something different if you make the obvious changes
to the code (just search for that IP or use the flags when running the code).

4) Copy the IrServerApplet.lua, IrServerAppletMeta.lua, and strings.txt to the controller in this directory:
/usr/share/jive/applets/IrServer

(You can do this by running:
> mkdir /usr/share/jive/applets/IrServer
on the device and then running copy-to-device.bat or copy-to-device.sh on your PC)

5) Start the new Menu Item on the Duet Controller by selecting it from the top level menu using
the controller's physical keys.  The screen should switch to a display showing you the IP address
of the controller and a message that the HTTPD IRServer is running, along with the count of
IR commands it has sent.

6) [Troubleshooting](Troubleshooting.md) If the menu item just jiggles the screen and doesn't switch to the display
described above, look at the end of /var/log/messages on the controller for an explanation.

7) Try out the HTTP server by making a request of it for "/help", e.g., any of these lines:

lynx -mime\_header "http://192.168.0.74:8174/help"
GET "http://192.168.0.74:8174/help"
lwp-request "http://192.168.0.74:8174/help"

Or just:

telnet 192.168.0.74 8174
help

8) Now find your remote's irconf files (or use LIRC's irrecord to create them) and then run irconf-to-html.pl
to create a rudimentary HTML file containing the correct commands to give to the server.  You may
want to:

tail -200 -f /var/log/messages

on the controller to watch the debug log.


9) Be sure to point your controller at the components you're trying to control.

Note that Phillips-type (RC5|RC6) commands appear not to be supported
by the underlying irtx driver on the controller -- see this thread:

http://forums.slimdevices.com/showthread.php?t=40367

This includes some rudimentary support for making RC6 remote work,
but I never got it to actually turn on my XBox360.


Report successes (and fixes to failures :-) ) to the project online at

http://code.google.com/p/irserversb/



# ANNOTATED REFERENCES #

Linux Infrared Remote Control - http://www.lirc.org/
- Has database of remotes.tar.bz2 with lots of details of the codes IR remotes send
- can also install the recorder and learn from your actual remotes iff you have an IR Receiver hooked up

SqueezePlay from Logitech - http://wiki.slimdevices.com/index.php/SqueezePlay
- Useful for testing IrServer, faster than copying to the device

iPeng iPhone Plugin for SqueezeCenter - http://penguinlovesmusic.de/ipeng-the-iphone-skin-for-squeezecenter/
- Great to use instead of your Duet controller


# LICENSE DETAILS #

This file is part of IrServer

IrServer is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

IrServer is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with IrServer.  If not, see <http://www.gnu.org/licenses/>.