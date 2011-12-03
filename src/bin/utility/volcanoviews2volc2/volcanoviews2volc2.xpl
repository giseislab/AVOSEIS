# Author: Glenn Thompson (GT) 2011
#         ALASKA VOLCANO OBSERVATORY
#
# History:
#       2011-10-01: Original version of this script read a CSV file 
#       2011-11-01: Ported to use a Datascope PF file 
#	2011-11-28: Adapted so it will source events from Datascope or VALVE
#
# To do:
#
##############################################################################

use Datascope;
use Getopt::Std;
use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our $opt_p;
if ( ! &getopts('p:') || $#ARGV != -1   ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME [-p pffile]

    For more information:
        > man $PROG_NAME
	> pfecho $PROG_NAME
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
use Avoseis::SwarmAlarm qw(getPf);
my $epochtime_1weekago = (time() + 8 * 60 * 60) - 7 * 24 * 60 * 60;
my $epochtime_1yearago = (time() + 8 * 60 * 60) - 365 * 24 * 60 * 60;

my ($EVENTDB, $STATIONDB, $XMLDIR, $VALVEJSP, $HYPOCENTERSDBNAME, $SOURCE, $volcanoviewsref) = &getParams(); 
system("mkdir -p $XMLDIR");
open(FOUT,">$XMLDIR/volcanoviews.xml") or die $!; 
print FOUT "<volcanoes>\n";
foreach my $volcanoview (@$volcanoviewsref) {
	print "$volcanoview\n";
		my @fields = split(/ /, $volcanoview);
		my $volcano = $fields[0];
		my $lat = $fields[1];
		my $lon = $fields[2];
		my $zoom = $fields[3];
		my $dist = (2.0 ** (12 - $zoom)) * 5.0;
		print "volcano = $volcano, lat = $lat, lon = $lon, zoom = $zoom, distance = $dist\n";
		my $lastweekxml = "$XMLDIR/origins_$volcano"."_lastweek.xml";
		my $lastyearxml = "$XMLDIR/origins_$volcano.xml";
		unless ($SOURCE eq "VALVE") {
			system("db2googlemaps -x 2 -b -f -e \"time>$epochtime_1weekago && deg2km(distance($lat, $lon, lat, lon))<$dist\" $EVENTDB  > $lastweekxml");
			system("db2googlemaps -x 2 -b -f -e \"time>$epochtime_1yearago && deg2km(distance($lat, $lon, lat, lon))<$dist\" $EVENTDB  > $lastyearxml");
		} else {
			my $nowstr = `epoch '+%Y%m%d%H%M%S' now`; chomp($nowstr);
			my $weekagostr = `epoch '+%Y%m%d%H%M%S' $epochtime_1weekago`; chomp($weekagostr);
			my $yearagostr = `epoch '+%Y%m%d%H%M%S' $epochtime_1yearago`; chomp($yearagostr);
			my $distDegrees = $dist * 360 / 40008; 
			my $minlat = $lat - $distDegrees;
			my $maxlat = $lat + $distDegrees;
			my $minlon = $lon - $distDegrees / cos($lat * 3.1416 / 180);
			my $maxlon = $lon + $distDegrees / cos($lat * 3.1416 / 180);
			system("valve2googlemaps $VALVEJSP $HYPOCENTERSDBNAME $minlat $maxlat $minlon $maxlon $weekagostr $nowstr $lastweekxml");
			system("valve2googlemaps $VALVEJSP $HYPOCENTERSDBNAME $minlat $maxlat $minlon $maxlon $yearagostr $nowstr $lastyearxml");
		}
		system("db2googlemaps  -x 2 -s -f -e \"deg2km(distance($lat, $lon, lat, lon))<$dist\" $STATIONDB  > $XMLDIR/stations_$volcano.xml");
		print FOUT "<volcano name=\"$volcano\" lat=\"$lat\" lon=\"$lon\" zoomlevel=\"$zoom\" />\n";
}
print FOUT "</volcanoes>\n";
close(FOUT);


sub getParams {
        my $pfobjectref = &getPf($PROG_NAME, $opt_p, 0);
	my $volcanoviewsref = $pfobjectref->{'volcanoviews'};
	my $EVENTDB = $pfobjectref->{'eventdb'};
	my $STATIONDB = $pfobjectref->{'stationdb'};
	my $XMLDIR = $pfobjectref->{'xmldir'};
	my $VALVEJSP = $pfobjectref->{'valvejsp'};
	my $HYPOCENTERSDBNAME = $pfobjectref->{'hypocentersDatabaseName'};
	my $SOURCE = $pfobjectref->{'source'};
        return ($EVENTDB, $STATIONDB, $XMLDIR, $VALVEJSP, $HYPOCENTERSDBNAME, $SOURCE, $volcanoviewsref); 
}
