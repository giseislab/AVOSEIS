##############################################################################
# Author: Glenn Thompson (GT) 2011/11/11
#         ALASKA VOLCANO OBSERVATORY
#
# Modifications:
#       2011-11-11: Created by GT
#
##############################################################################
use strict;
use warnings;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage
if ( $#ARGV !=8  ) {
    print STDERR <<"EOU" ;

    $PROG_NAME is used to read hypocenters from VALVE and export them to an XML file
    for use by \"VOLC2\".

    Usage: $PROG_NAME valvejsp hypocentersDatabaseName minlat maxlat minlon maxlon start_time end_time xmlfile

    Command line arguments: 
	valvejsp - the URL of the VALVE Java Server Page, e.g. http://avosouth.wr.usgs.gov/valve3.4/valve3.jsp
	hypocentersDatabaseName - the name of the VALVE hypocenters database which contains the source hypocenters table. This is specified in the VALVE/VDX config files.
	minlat
	maxlat
	minlon
	maxlon - select events with epicenters within a square box igiven by minlat, maxlat, minlon, maxlon (given in decimal degrees)
	start_time, end_time - select events with origin times between start_time and end_time (given as YYYYMMDDhhmmss) 
	xmlfile - the path of the XML file to export the selected hypocenter data to. 

    Example: All events with epicenters within the Redoubt geographical filter, between 2011-09-01 and 2011-11-22
	$PROG_NAME \"http://avosouth.wr.usgs.gov/valve3.4/valve3.jsp\" avo_seismic_hypocenters 60.2606 60.7094 -153.1967 -152.2873 20110901 20111122  myvolc2.xml

EOU
    exit 1 ;
}
my ($VALVEJSP, $HYPOCENTERSDBNAME, $MINLAT, $MAXLAT, $MINLON, $MAXLON, $STARTTIME, $ENDTIME, $XMLFILE) = @ARGV;
while (length($STARTTIME)<17) {
	$STARTTIME .= "0";
}
while (length($ENDTIME)<17) {
	$ENDTIME .= "0";
}
my $VALVEURL = $VALVEJSP."?a=rawData&o=csv&tz=GMT&src.0=avo_seismic_hypocenters&st.0=$STARTTIME&et.0=$ENDTIME&north.0=$MAXLAT&south.0=$MINLAT&east.0=$MAXLON&west.0=$MINLON&rk.0=2&minDepth.0=20&maxDepth.0=-800"; # note rank=10 are finalized solutions, but somehow in BVALVE URL this is tranlsated to rank=2
print $VALVEURL."\n";

use LWP::Simple; # includes the get module which acts like wget
our $xmlstr = ""; # Use this to store XML output
&xmlstart;
our $evid = 0; # evid field not included in VALVE export, so just count from 0
my (@epoch, @datestr, @lat, @lon, @depth, @mag);

# get the typee. should be "rawData" otherwise it is probably "error" as in no data returned
my @typelines = grep(/type/, split('\n',get($VALVEURL)));
if ($#typelines==0) { # there should only be 1 type line! 
	my $type = $typelines[0];
	$type =~ s/<type>//g; # remove lead <type> tag
	$type =~ s/<\/type>//g; # remove trailing </type> tag
	$type =~ s/\s+//g; # remove spaces
	print "Type of URL returned: $type\n";
	if ($type eq "rawData") {

		# get csv - I make no attempt here to parse the XML, I simply use a Unix grep
		my @lines = grep(/url/, split('\n',get($VALVEURL)));
		if ($#lines==0) { # there should only be 1 url line! It looks like    <url>url_to_csv_file</url>
			my $url = $lines[0];
			$url =~ s/<url>//g; # remove lead <url> tag
			$url =~ s/<\/url>//g; # remove trailing </url> tag
			$url =~ s/\s+//g; # remove spaces
			print "URL to CSV file: $url\n";

			# Now we have the url for the CSV file, need to download the CSV file
			# Use LWP::Simple::get again
			my @csvlines = split('\n',get($url));
			printf "CSV file has %d lines\n", ($#csvlines+1); # this includes a few header lines

			# parse the CSV
			foreach my $line (@csvlines){ # process each line in the CSV file
				chomp($line); # remove the new line
				$line=~s/\s+//g; # remove white space, so that "    52.34" becomes "52.34" for example
				my @field = split  /,/, $line; # split the CSV line on commas to separate fields
				next unless $field[0]=~/^(\d+\.?\d*|\.\d+)/;  # match valid number - gets rid of header lines
				if ($#field == 5) { # there should be 6 fields [0..5]
					push @epoch, $field[0];
					push @datestr, $field[1];
					push @lat, $field[2];
					push @lon, $field[3];
					push @depth, $field[4];
					push @mag, $field[5];
				}	
			}

			# Write the data to XML
			&xmlwriterecords;
		
		} else {
			printf("%d lines found with a url tag. Confused. Will write no data.\n", $#lines+1);
		}
	} else {
		print "rawData was not returned. Will write no data.\n";
	}
		

} else {
	printf("%d lines found with a type tag. Confused. Will write no data.\n", $#typelines+1);
}
&xmlfinish;

# Write XML string to file
open(FXML,">$XMLFILE");
print FXML $xmlstr;
close(FXML);

# Success
1;

######################################################################
sub xmlstart {          ##### Write the starting portion of a xml file
        $xmlstr .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
        my $localtimestr = `date`;
	chomp($localtimestr);
        my $utctimestr = `date -u`;
	chomp($utctimestr);
        $xmlstr .= "\t<!-- created by $PROG_NAME at $utctimestr UTC -->\n";
        $xmlstr .= "<merge fileTime_loc=\"$localtimestr\" fileTime_utc=\"$utctimestr\">\n";
}


sub xmlfinish { ##### close a xml file
	$xmlstr .= "</merge>\n";
}

sub xmlwriterecords {
	foreach my $epoch (@epoch) {
		my $datestr = pop(@datestr);
		my $lat = pop(@lat);
		my $lon = pop(@lon);
		my $depth = (-1) * pop(@depth);
		my $magnitude = pop(@mag);
		my $year = substr($datestr, 0, 4);
		my $month = substr($datestr, 5, 2);
		my $day = substr($datestr, 8, 2);
		my $hour = substr($datestr, 10, 2);
		my $minute = substr($datestr, 13, 2);
		my $second = substr($datestr, 16, 2);
                my $time_stamp = "$year/$month/$day $hour:$minute:$second";
		my $localtime = $time_stamp;
		# evid, nass and ndef not available in VALVE feed. Need to get these from AQMS.
		$evid++;
		my $nass=-1;
		my $ndef=-1;
		$xmlstr .= "<event id=\"$evid\" network-code=\"AK\" time-stamp=\"$time_stamp\" version=\"1\">
<param name=\"year\" value=\"$year\"/>
<param name=\"month\" value=\"$month\"/>
<param name=\"day\" value=\"$day\"/>
<param name=\"hour\" value=\"$hour\"/>
<param name=\"minute\" value=\"$minute\"/>
<param name=\"second\" value=\"$second\"/>
<param name=\"latitude\" value=\"$lat\"/>
<param name=\"longitude\" value=\"$lon\"/>
<param name=\"depth\" value=\"$depth\"/>
<param name=\"magnitude\" value=\"$magnitude\"/>
<param name=\"num-stations\" value=\"$nass\"/>
<param name=\"num-phases\" value=\"$ndef\"/>
<param name=\"local-time\" value=\"$localtime\"/>
<param name=\"icon-style\" value=\"1\"/>
</event>\n";
	} # end foreach
}

