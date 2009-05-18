--[[
=head1 NAME

applets.IrServer.IrServerApplet - IrServer Applet for SqueezeBox Duet Controllers

=head1 DESCRIPTION

This applet listens on a TCP port for a simple command language
that in the interprets as commands to send to its infrared transmitter
using /usr/bin/testir.  You can visit:

http://IPADDR:8174/help

for a succinct help message on the command language understood.


Note that Phillips-type (RC5|RC6) commands appear not to be supported
by the underlying irtx driver on the controller -- see this thread:

http://forums.slimdevices.com/showthread.php?t=40367

This includes some rudimentary support for making RC6 remote work,
but I never got it to actually turn on my XBox360.

=head1 AUTHOR

Greg J. Badros - badros@cs.washington.edu
Copyright (C) 2009 Greg J. Badros

=head1 LICENSE

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


=cut
--]]


-- stuff we use
local tostring, ipairs, tonumber = tostring, ipairs, tonumber
local oo                     = require("loop.simple")
local io                     = require("io")
local string                 = require("string")
local math  				  = require("math")

local Applet                 = require("jive.Applet")
local Timer                  = require("jive.ui.Timer")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local log                    = require("jive.utils.log").addCategory("irserver", jive.utils.log.DEBUG)

local socket = require("socket")
local os = require("os")
local Framework              = require("jive.ui.Framework")

module(..., Framework.constants)
oo.class(_M, Applet)

local label = nil
local server = nil
local ip, port
local numCommands = 0
local window, popup
local timer

-- ah = asHex, returns a "space" signal
function ah(n)
	return n and string.format("0x%x", n) or ""
end

-- assumes n < 0x80000000, and returns a "mark" signal
function aH(n)
	return n and ah(n + 0x80000000) or ""
end


-- see http://winlirc.sourceforge.net/technicaldetails.html
function setStrings(d)
	d.str_carrier = ah(d.ir_carrier)
	d.str_gap = ah(d.ir_gap)
	d.str_ptrail = aH(d.ir_ptrail)
	if (d.mode == "rc6") then
		d.str_header = aH(d.ir_header_1) .. " " .. ah(d.ir_header_2) .. " " .. aH(d.ir_one_1) .. " " .. ah(d.ir_one_2)
		if (d.ir_ptrail == 0) then
			d.str_ptrail = ""
		end
	else
		d.str_header = aH(d.ir_header_1) .. " " .. ah(d.ir_header_2)
	end

	if (d.mode == "rc6") then
		-- untested
		-- see http://www.sbprojects.com/knowledge/ir/rc6.htm
		d.str_one =  aH(d.ir_one_1) .. " " .. ah(d.ir_one_2)
		d.str_zero = ah(d.ir_zero_1) .. " " .. aH(d.ir_zero_2)
	elseif (d.mode == "rc5") then
		-- untested
		-- see http://www.sbprojects.com/knowledge/ir/rc5.htm
		d.str_one =  ah(d.ir_one_1) .. " " .. aH(d.ir_one_2)
		d.str_zero = aH(d.ir_zero_1) .. " " .. ah(d.ir_zero_2)
	else
		-- this is tested -- for Sony IR protocol, space-encoding
		d.str_one = aH(d.ir_one_1) .. " " .. ah(d.ir_one_2)
		d.str_zero = aH(d.ir_zero_1) .. " " .. ah(d.ir_zero_2)
	end

	-- must happen after setting d.str_{one,zero}
	d.str_pdata = ""
	if (d.pdata_bits and d.pdata_bits > 0) then
		local pdata_binary = pdataToBinary(d.pdata, d)
		for i,v in ipairs(pdata_binary) do
			d.str_pdata = d.str_pdata .. " " .. v
		end
	end

	log:debug("setstrings: device ir_carrier = " .. tostring(d.ir_carrier))
	log:debug("setstrings: device freq = " .. d.str_carrier)
	log:debug("setstrings: device header = " .. d.str_header)
	log:debug("setstrings: device pdata = " .. d.str_pdata)
end


-- use pioneer amp as the defaults
local device = {}

device.ir_carrier = 40000
device.ir_gap = 25162
device.ir_ptrail = 554

device.ir_header_1, device.ir_header_2 = 8500, 4200
device.ir_one_1, device.ir_one_2 = 550, 1540
device.ir_zero_1, device.ir_zero_2 = 550, 500

device.ctrl_bits = 32
device.ctrl_constlen = false
device.ctrl_repeat = 1
device.pdata_bits = 0

setStrings(device)

local devPioneerAmp = device


local devSonyTV = {}
devSonyTV.ir_carrier = 40000
devSonyTV.ir_gap = 44881
devSonyTV.ir_ptrail = nil
devSonyTV.ir_header_1, devSonyTV.ir_header_2 = 2400, 588
devSonyTV.ir_one_1, devSonyTV.ir_one_2 = 1200, 600
devSonyTV.ir_zero_1, devSonyTV.ir_zero_2 = 600, 600
devSonyTV.ctrl_bits = 12
devSonyTV.ctrl_constlen = true
devSonyTV.ctrl_repeat = 2
devSonyTV.pdata_bits = 0

setStrings(devSonyTV)

-- initialize some built-in devices; these can be overridden later
devices = {}
devices["sonytv"] = devSonyTV
devices["pioneeramp"] = devPioneerAmp


-- from SetupSSHApplet.lua
function _getIPAddress()
	local ipaddr

	local cmd = io.popen("/sbin/ifconfig eth0")
	for line in cmd:lines() do
		ipaddr = string.match(line, "inet addr:([%d%.]+)")
		if ipaddr ~= nil then break end
	end
	cmd:close()

	return ipaddr or "?.?.?.?"
end



function tobinary(n, dev)
	local answer = {}

	if (dev.lsb_first) then
		local i = 0
		while i < dev.ctrl_bits do
			answer[i] = n % 2 == 0 and dev.str_zero or dev.str_one
			n = math.floor(n/2)
			i = i + 1
			if (n == 0 and dev.ctrl_constlen == false) then
				break
			end
		end
	else
		local i = dev.ctrl_bits
		while i > 0 do
			answer[i] = n % 2 == 0 and dev.str_zero or dev.str_one
			n = math.floor(n/2)
			i = i - 1
			if (n == 0 and dev.ctrl_constlen == false) then
				break
			end
		end
	end
	return answer
end


function pdataToBinary(n, dev)
	local answer = {}
	-- this assumes const len pdata sections

	if (dev.lsb_first) then
		local i = 0
		while i < dev.pdata_bits do
			answer[i] = n % 2 == 0 and dev.str_zero or dev.str_one
			n = math.floor(n/2)
			i = i + 1
		end
	else
		local i = dev.pdata_bits
		-- n = n * 2 TODO
		while i > 0 do
			answer[i] = n % 2 == 0 and dev.str_zero or dev.str_one
			n = math.floor(n/2)
			i = i - 1
		end
	end
	return answer
end



function fullcmd(n, dev)
	if (n == nil) then
		return nil
	end
	log:debug("fullcmd: device pdata = " .. dev.str_pdata)
	log:debug("fullcmd: device freq = " .. dev.str_carrier)
	log:debug("fullcmd: device header = " .. dev.str_header)
	log:debug("fullcmd: n = " .. tostring(n))

	local answer = dev.str_carrier .. " "

	local codes = dev.str_header .. dev.str_pdata

	local binary = tobinary(n,dev)
	for i,v in ipairs(binary) do
		codes = codes .. " " .. v
	end
	codes = codes .. " " .. dev.str_ptrail .. " " .. dev.str_gap .. " "

	for r = 1, dev.ctrl_repeat do
		answer = answer .. codes
	end

	log:debug("fullcmd: answer = " .. answer)

	return answer
end


function menu(self, menuItem)
	log:debug("irserver started")
	-- log:debug("fullcmd-amp " .. fullcmd(0xA55A38C7, devPioneerAmp))
	-- log:debug("fullcmd-sony " .. fullcmd(0x070, devSonyTV))

	-- Popup a little display
	popup = Popup("popupIcon")
	-- popup:setAllowScreensaver(false)
	-- popup:setAlwaysOnTop(true)
	-- popup:setAutoHide(true)
	-- popup:setTransparent(false)

	log:info("irserver binding to 8174")
	-- load namespace
	-- create a TCP socket and bind it to the local host, at any port
	server = socket.bind("*", 8174)
	-- find out which port the OS chose for us
	ip, port = server:getsockname()
	ipaddr = _getIPAddress()
	-- print a message informing what's up
	log:info("Please telnet to "..ipaddr..":"..port)

	--FIXME, this window does not layout correctly (Bug 5412)
	local icon = Icon("iconConnecting")
	local text = Label("text", "Httpd IRServer - "..ipaddr..":"..tostring(port))
	label = Label("text", "\nNum commands: "..tostring(numCommands))

	popup:addWidget(icon)
	popup:addWidget(label)
	popup:addWidget(text)

	timer = Timer(500, function()
				log:debug("runserver1")
				self:runServer()
				end, true)

	timer:start()

	popup:addListener(EVENT_KEY_PRESS | EVENT_MOUSE_PRESS,
	 function(event)
		server:close()
		log:debug("closing on key_press")
		popup:hide()
		return EVENT_UNUSED
	 end)


	self:tieAndShowWindow(popup)
	return popup
end


function nonnegnum(w)
	if (w == nil) then
		return nil
	end
	-- n.b. that I need the 16 to specify hex here, else 0x80000000 and up come out negative
	-- (that is not the behaviour I get on my windows box lua 5.1 impl, but is what the squeezeplayer
	--  and the on-board jive seem to do)
	local n = tonumber(w, 16)

	if (n == nil or n < 0) then
		return nil
	end

	return n
end


function handleCommands(client, line, dev)
	for w in string.gmatch(line, "0x%x+") do
		local c = fullcmd(nonnegnum(w), dev)
		if (c ~= nil) then
			sendCommand(client, c)
		end
	end
end


function sendCommand(client, cmd)
	log:info("/usr/bin/testir "..cmd)
	os.execute("/usr/bin/testir "..cmd)
	client:send(cmd .. "\n")
	numCommands = numCommands + 1
	label:setValue("\nNum commands: "..tostring(numCommands))
	log:debug("set num commands ", numCommands)
end


function runServer(self)
	local full_command = nil
	local response = nil
	-- wait for a connection from any client
	server:settimeout(0.5)
	local client = server:accept()
	repeat
		if client ~= nil then
			-- make sure we don't block waiting for this client's line
			client:settimeout(4)
			-- receive the line
			local line, err = client:receive()
			log:debug("raw line = "..(line or "nil")..", err="..(err or "nil"))
			-- if there was no error, send it back to the client
			if not err then
				line, changes = string.gsub(line, "^GET /", "", 1)
				line, changes = string.gsub(line, " HTTP/1.[0-9]$", "", 1)
				line, changes = string.gsub(line, "+", " ")
				line, changes = string.gsub(line, "%%20", " ")
				line, changes = string.gsub(line, "?", " ")
				line = string.lower(line)
				if line == "quit" then
					client:close()
					server:close()
					popup:hide()
					window:hide()
					return nil
				end

				if line == "help" then
					client:send("HTTP/1.0 200 OK\r\n\r\nIrServer Help:\n"
								.. "testir RAW ARGUMENTS TO /usr/bin/testir\n"
								.. "setdev [NEWDEVNAME] [mode:rc[56]] CARRIER GAP PTRAIL HDR1 HDR2 ONE1 ONE2 ZERO1 ZERO2 NUMBITS CONSTLEN REPEAT PDATABITS PDATA...\n"
								.. "devcmd DEVNAME CMD1 ...\n"
								.. "command CMD1 ...\n"
								.. "quit\n"
								.. "\n\n All '...'s can be replaced by hex commands (e.g. 0x070)")
					break
				end

				line, changes = string.gsub(line, "^testir ", "", 1)
				if (changes > 0) then
					log:debug("testir ".. line)
					full_command = line
					break
				end

				-- "setdev" newdevname carrier gap ptrail hdr1 hdr2 one1 one2 zero1 zero2 numbits constlen repeat
				line, changes = string.gsub(line, "^setdev ", "", 1)
				if (changes > 0) then
					log:debug("setdev ".. line)
					local devparams = {}
					local i = 1
					local devname = nil
					local mode = ""
					line, changes = string.gsub(line, "^([_%w]+) ", function (s)
						devname=s
						return ""
					end)

					line, changes = string.gsub(line, "^mode:(rc[56]) ", function (s)
						mode = s
						return ""
					end)

					for w in string.gmatch(line, "0x%x+") do
						devparams[i] = nonnegnum(w)
						i = i + 1
					end
					device = {}
					device.mode = mode
					device.ir_carrier = devparams[1]
					device.ir_gap = devparams[2]
					device.ir_ptrail = devparams[3]
					device.ir_header_1, device.ir_header_2 = devparams[4], devparams[5]
					device.ir_one_1, device.ir_one_2 = devparams[6], devparams[7]
					device.ir_zero_1, device.ir_zero_2 = devparams[8], devparams[9]
					device.ctrl_bits = devparams[10] or 16
					device.ctrl_constlen = devparams[11] or true
					device.ctrl_repeat = devparams[12] or 1
					device.pdata_bits = devparams[13] or 0
					device.pdata = devparams[14] or 0

					log:debug("device mode = " .. device.mode)
					log:debug("devparams[1] = " .. devparams[1])
					log:debug("devparams[2] = " .. devparams[2])
					log:debug("device.ir_carrier = " .. device.ir_carrier)
					setStrings(device)

					if (devname ~= nil) then
						devices[devname] = device
						log:debug("stored new device as devname="..devname)
					end

					response = "did setdev " .. line
					local command = nonnegnum(devparams[15])
					if (command ~= nil) then
						full_command = fullcmd(command, device)
					end
					break
				end

				-- "devcmd" DEVICENAME   command [or 0x0]
				line, changes = string.gsub(line, "^devcmd ", "", 1)
				if (changes > 0) then
					log:debug("devcmd ".. line)
					local devname = nil
					line, changes = string.gsub(line, "^([_%w]+) ", function(s)
						devname = s
						return ""
					end)
					if (devname and devices[devname] ~= nil) then
						device = devices[devname]
						handleCommands(client, line, device)
					else
						log:error("could not handle devname from line = "..line)
					end
					break
				end

				-- "command" 0xHEX
				line, changes = string.gsub(line, "^command ", "", 1)
				if (changes > 0) then
					log:debug("command ".. line)
					handleCommands(client, line, device)
					break
				end
			end
			log:debug("line = '" .. (line or "nil") .. "'")
		end
	until true


	if (full_command ~= nil and client ~= null) then
		sendCommand(client, full_command)
	else
		if (response ~= nil) then
			log:debug("no command - " .. response)
		end
		if (client ~= nil and response ~= nil) then
			client:send(response)
		end
	end

	-- done with client, close the object
	if (client ~= null) then
		client:close()
	end

	timer = Timer(500, function()
				-- log:debug("runserver1")
				self:runServer()
				end, true)
	timer:start()

end
