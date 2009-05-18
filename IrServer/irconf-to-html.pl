#!/usr/bin/env perl
# $Id: irconf-to-html.pl,v 1.8 2009/05/18 04:15:07 gjb Exp $ -*- perl -*-
#
# irconf-to-html.pl
#
# Author: Greg J. Badros - badros@cs.washington.edu
# Copyright (C) 2009 Greg J. Badros
#
# This file is part of IrServer
# 
# IrServer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# IrServer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with IrServer.  If not, see <http://www.gnu.org/licenses/>.

require 5.005;
use warnings;
use Getopt::Std;
use File::Basename;
use URI::Escape;
use strict;
#use Carp;

#require Exporter;
#@ISA = qw(Exporter);
#@EXPORT = qw();

my $getopts_option_letters = 'hn:B:rC:c:';
use vars qw($opt_h $opt_n $opt_B $opt_r $opt_C $opt_c);

my $prg = basename("$0");

sub usage () {
  die "@_
Usage: $prg [-$getopts_option_letters] IRCONFIG1 ...
-h               Help. Display this usage information
-n DEVNAME,..    Name the device DEVNAME (use comma-separated list when multiple IRCONFIGs on command line
-B IP:PORT       Use IP:PORT as the Base URL (or just 0 for localhost:8174)
-r               Use raw HTML output, nothing fancy -- better for learning + debugging
-C CHANNELS      Use CHANNELS as a file containing STATION_ID space NUMBER pairs and output codes for them for TV device
-c DEVNAME       Generate channel guide for DEVNAME (requires -C option, too)
Example usage:

perl $prg devices/VSX9300 > pioneer-amp.html

Note that you can pass multiple IRCONFIGs on a single command line

";
}

sub html_escape ($) {
  my $answer = shift;
  $answer =~ s/</&lt;/g;
  $answer =~ s/&/&amp;/g;
  return $answer;
}


if (defined($ARGV[0]) && $ARGV[0] eq "--help") {
  usage();
  exit 0;
}

my $orig_args = join(" ", @ARGV);

getopts($getopts_option_letters);
if ($opt_h) {
  usage();
  exit 0;
}

### Main routine

# this is the IP address my device happens to come up on
# use -B option to override (or -B0 to test with localhost)
my $baseurl = "http://192.168.0.74:8174/";

if (defined($opt_B)) {
  if ($opt_B && $opt_B =~ m%^(http://)?(\S+)/?$%) {
    $baseurl = "http://$2/";
  } else {
    $baseurl = "http://localhost:8174/";
  }
}

my @channels = ();
my %channels = ();
if ($opt_C) {
  parse_channels($opt_C, \@channels, \%channels);
}


## dump the header right away so we only do that once
if (!$opt_r) {
  output_header();
}

my @device_names = ();

if ($opt_n) {
  @device_names = split(/,/, $opt_n);
}

my %show_channel_guide_for_dev = ();

if ($opt_c) {
  map { $show_channel_guide_for_dev{$_}++ } split(/,/, $opt_c);
}

my @setdev_lines;
while (my $lirconf = shift) {
  my $devname = shift @device_names || undef;
  process_config($lirconf, $devname ); # side-effects @setdev_lines, too
}
output_footer(\@setdev_lines);


sub process_config {
  my $lirconf = shift;
  my $devname = shift;

  open(IN, "<", $lirconf)
    or die "Cannot open file \`$lirconf\': $!";


  my ($ir_carrier, $ir_gap, $ir_ptrail, $ir_hdr1, $ir_hdr2, 
      $ir_one1, $ir_one2, $ir_zero1, $ir_zero2, $ir_numbits, $ir_constlen, $ir_repeat);

  # Defaults - TODO check this with LIRC
  $ir_carrier = 40000;
  $ir_numbits = 16;
  $ir_constlen = 0;
  $ir_repeat = 1;
  $ir_ptrail = "nil";

  my $remote_name;
  my %codes = ();
  my @codes = ();

  my $reading_codes = 0;

  while (<IN>) {
    s/#.*$//;
    next if m/^\s*$/;
    if ($reading_codes) {
      if (m%\bend codes\b%) {
	$reading_codes = 0;
      } elsif (m%(\w\S*)\s+(\S+)%) {
	my ($name,$seq) = ($1, $2);
	$seq =~ s/^0x0+/0x/;
	$codes{$name} = $seq;
	push @codes, [$name, $seq];
      } else {
	print STDERR "Could not handle code line \`$_\'\n";
      }
    } else {
      if (m%\bname\s+(\w+)%) {
	$remote_name = $1;
      } elsif (m%\bfrequency\s+(\d+)%) {
	$ir_carrier = $1;
      } elsif (m%\bbits\s+(\d+)%) {
	$ir_numbits = $1;
      } elsif (m%\bptrail\s+(\d+)%) {
	$ir_ptrail = $1;
      } elsif (m%\btoggle_bit\s+(\d+)%) {
	# TODO: don't do anything with this yet
      } elsif (m%\bgap\s+(\d+)%) {
	$ir_gap = $1;
      } elsif (m%\bflags\s+(.*)$%) {
	my $val = $1;
	if ($val =~ m/\bCONST_LENGTH\b/) {
	  $ir_constlen = 1;
	}
	if ($val =~ m/\bSPACE_ENC\b/) {
	  # TODO: don't do anything with this now
	}
      } elsif (m%\bmin_repeat\s+(\d+)%) {
	if ($1 > 0) {
	  $ir_repeat = $1;
	}
      } elsif (m%\bheader\s+(\d+)\s+(\d+)%) {
	($ir_hdr1, $ir_hdr2) = ($1, $2);
      } elsif (m%\bone\s+(\d+)\s+(\d+)%) {
	($ir_one1, $ir_one2) = ($1, $2);
      } elsif (m%\bzero\s+(\d+)\s+(\d+)%) {
	($ir_zero1, $ir_zero2) = ($1, $2);
      } elsif (m%\bbegin codes\b%) {
	$reading_codes = 1;
      } elsif (m%\bend codes\b%) {
	$reading_codes = 0;
      }
    }
  }
  close (IN);


  if (!defined($remote_name) || $remote_name =~ m/^rcv$/i) {
    $remote_name = basename($lirconf);
    $remote_name =~ s/\..*$//;	# remove extension
  }

  if ($devname) {
    $remote_name = $devname;
  }


  my $setdev = "setdev $remote_name " . join(" ", map { sprintf("0x%x", $_) } 
					     ($ir_carrier, $ir_gap, $ir_ptrail, $ir_hdr1, $ir_hdr2, 
					      $ir_one1, $ir_one2, $ir_zero1, $ir_zero2, $ir_numbits, $ir_constlen, $ir_repeat));

  push @setdev_lines, $setdev;

  if ($opt_r) {
    print "<a href='$baseurl". uri_escape($setdev) ."'>".html_escape("$remote_name :-: $setdev")."</a><br>\n";
  } else {
    print "<h1><a href='#' onClick='cmd(\"$setdev\");' title='$setdev'>".html_escape($remote_name)."</a></h1>\n";
  }


  #while (my ($k, $v) = each %codes) {
  for my $aref (@codes) {
    my ($k, $v) = @$aref;
    my $cmd = "devcmd $remote_name $v";
    if ($opt_r) {
      print "<a href='$baseurl". uri_escape($cmd) ."'>".html_escape($k)."</a> &nbsp; \n";
    } else {
      print "<a href='#' onClick='cmd(\"$cmd\");' title='$cmd'>".html_escape($k)."</a> &nbsp;\n";
    }
  }

  if ($opt_c && ($show_channel_guide_for_dev{$remote_name})) {
    my $okay = 1;
    for my $i (0..9) {
      if (!exists($codes{$i})) {
	print STDERR "No code for number \`$i\' device \`$remote_name\'\n";
	$okay = 0;
      }
    }
    if ($okay) {
      print "<h3>Channel guide</h3>\n";
      for my $aref (@channels) {
	my ($name, $num) = @$aref;
	my $cmd = "devcmd $remote_name " . join(" ", map { $codes{$_} } split (//, $num));
	if ($opt_r) {
	  print "<a href='$baseurl". uri_escape($cmd) ."'>".html_escape($name)."</a> &nbsp; \n";
	} else {
	  print "<a href='#' onClick='cmd(\"$cmd\");' title='$cmd'>".html_escape($name)."</a> &nbsp;\n";
	}
      }
    }
  }

  print "<hr>\n";
}


sub output_header {
  print <<END_HEADER ;
<head>
<script type="text/javascript" language="javascript">

var baseurl = "$baseurl";
function cmd(s) {
	var img = new Image();
	img.src = baseurl + s + "#" + Math.random();
}
</script>
END_HEADER
}

sub output_footer {
  my $aref = shift;
  print "<script type='text/javascript' language='javascript'>\n";
  for my $sd (@$aref) {
    print "cmd(\"$sd\");\n";
  }
  print "</script>\n";
  print "<small>This page was generated by <tt>".html_escape("$prg $orig_args")."</tt></small><br>\n";
  print "<small>IrServer and $prg are Copyright (C) 2009 <a href='http://www.badros.com/greg'>Greg J. Badros</a> licensed under the GNU GPL</small>\n";
  print "</html>";
}


sub parse_channels {
  my $f = shift;
  my $aref = shift;
  my $href = shift;

  open(CHIN, "<", $f)
    or die "Cannot open channel file \`$f\': $!";
  my $heading = "";
  while (<CHIN>) {
    chomp;
    s/#.*$//;
    next if (m/^\s*$/);
    my $low_priority = 0;
    if (m/^\*(.*)/) {
      $heading = $1;
    } elsif (s/^-//) {
      $low_priority = 1;
    } else {
      my ($name, $num) = split (/\t/, $_, 2);
      if (!defined($num) || $num !~ m/^\d+$/) {
	print STDERR "Unrecognized channel \`" . ($num || "undef") . "\' line $. in \`$f\': \`$_\'\n";
      } else {
	push @$aref, [$name, $num];
	$$href{$name} = $num;
      }
    }
  }
  close (CHIN);
  return scalar(@$aref);
}
__END__

=head1 NAME

irconf-to-html.pl -- Create a simple HTML page to control remotes given their LIRC irconf config files

=head1 SYNOPSIS 

=head1 DESCRIPTION

I<Disclaimer: You choose to use this script at your own risk!>

=head1 BUGS

Certainly.


=head1 SEE ALSO

Linux Infrared Remote Control (LIRC) Homepage - http://lirc.org

=head1 COPYRIGHT
Copyright (C) 2009, Greg J. Badros

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

=head1 AUTHOR

Greg J. Badros - <Fbadros@cs.washington.edu>


=cut
# cut and paste code to regen
perl irconf-to-html.pl devices\DCT2524 > dct.html
perl irconf-to-html.pl devices\DigitalCable > digcable.html
perl irconf-to-html.pl devices\RM-Y168 > sony.html
perl irconf-to-html.pl devices\VSX9300 > pioneer.html

perl irconf-to-html.pl -cDigCableBox,DCT2524 -C devices\channels.txt -nSonyTV,PioneerAmp,,DigCableBox devices\RM-Y168 devices\VSX9300 devices\DCT2524 devices\DigitalCable > out.html
