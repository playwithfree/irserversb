#!/usr/bin/perl -w
# Author: Greg J. Badros
# Copyright (C) 2009 Greg J. Badros
#
# See License at bottom of file in POD format
#
# IrServer-test.pl
# -d    Use real device (else use localhost)
# -i    Interactive (sonypower|sonymenu|amppower|ampmute)
#
# (Args are order dependent)
#
# TODO: make this more comprehensive
# TODO: use getopt

use strict;
use LWP::Simple;

sub do_get {
	my $u = shift;
	$u =~ s/ /+/g;
	print "URL = $u\n";
	print "Response = ", (get($u) || ""), "\n";
}

my $base_url = "http://localhost:8174/";
if ($ARGV[0] eq "-d") {
	shift(@ARGV);
	$base_url = "http://192.168.0.252:8174/";
}


my $url_help = $base_url . "help";
my $url_quit = $base_url . "quit";

# These are strings because they must be hex in the command
# send to irserver
my $sony_code_power = "0xA90";
my $sony_code_menu = "0x070";

my $pioneeramp_code_mute = "0xA55A48B7";
my $pioneeramp_code_power = "0xA55A38C7";


my $sony_power_on = $base_url . "devcmd sonytv $sony_code_power";
my $sony_menu = $base_url . "devcmd sonytv $sony_code_menu";

my $pioneeramp_power = $base_url . "devcmd pioneeramp $pioneeramp_code_power";
my $pioneeramp_mute = $base_url . "devcmd pioneeramp $pioneeramp_code_mute";


my $content = get($url_help);

if ($content =~ m/IrServer Help/) {
	print "SUCCESS - $url_help\n";
}

if ($ARGV[0] eq "-i") {
	shift @ARGV;
	while (<STDIN>) {
		if (m/sonypower/) {
			do_get($sony_power_on);
		} elsif (m/sonymenu/) {
			do_get($sony_menu);
		} elsif (m/amppower/) {
			do_get($pioneeramp_power);
		} elsif (m/ampmute/) {
			do_get ($pioneeramp_mute);
		} elsif (m/quit/) {
			last;
		} else {
			print "Unknown command\n";
		}
		print "\n";
	}
} elsif ($ARGV[0] eq "-q") {
	#
} else {
	do_get($sony_power_on);
	do_get($sony_menu);
	do_get($pioneeramp_power);
	do_get($pioneeramp_mute);
}

$content = get($url_quit);
print "$content\n";



__END__

--[[
=head1 NAME

IrServer-test.pl - Example HTTP invocations of IrServer for SqueezeBox Duet Controllers

=head1 DESCRIPTION

Test the applet that listens on a TCP port for a simple command language
that in the interprets as commands to send to its infrared transmitter
using /usr/bin/testir.  You can visit:

http://IPADDR:8174/help

for a succinct help message on the command language understood.

=head1 AUTHOR

Greg J. Badros - badros@cs.washington.edu

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

