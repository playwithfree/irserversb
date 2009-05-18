
--[[
=head1 NAME

aepplets.IrServer.IrServerMeta - IrServer for SqueezeBox Duet Controller

=head1 DESCRIPTION

See L<applets.IrServer.IrServerApplet>.

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


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end

function defaultSettings(meta)
      return {
              currentSetting = 0,
      }
end

function registerApplet(meta)

	jiveMain:addItem(meta:menuItem('IrServerApplet', 'home', "IRSERVER", function(applet, ...) applet:menu(...) end, 900))

end


--[[

=head1 LICENSE

Use at your own risk!  No promises of what this does or doesn't do of any kind.


=cut
--]]

