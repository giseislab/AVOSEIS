
##############################################################################
# Author: Glenn Thompson (GT) 2007-2008, 2010
#         Geophysical Institute, University of Alaska Fairbanks
#
# Modifications:
#
# Purpose:
#       Rebroadcast database rows as /pf/orb2dbt packets to 1 or many orbs.
#
# To do:
#	* Create man page from dbsubset2orb
#
# History:
#	* This program uses some code from dbt2pf, a program originally written
#	by Josh Stachnik, and dbsubset2orb, a program originally written by
#	Glenn Thompson with some modifications by Anna Bulanova. The rename to
#	dbt2orbpf was suggested by Kent Lindquist.
#
#
##############################################################################

use Datascope;
use orb;
require "getopts.pl" ;

use strict;
use warnings;
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
our ($opt_v, $opt_V, $opt_l, $opt_m, $opt_o, $opt_p, $opt_s, $opt_S); 
if ( ! &Getopts('vVl:m:o:s:S:') || $#ARGV < 1 ) {
	print STDERR <<"EOU" ;
	
	Usage: $PROG_NAME [-v] [-V] [-l sleeptime] [-m timetowaitformagnitude] [-o "ALL"|"NEW"|"STATE"] [-p pffile] [-s select_expr] [-S statefile] database orb [orb2...]
	
	Also see manpage.
		
EOU
	exit 1 ;
}
$opt_o = "ALL" unless defined($opt_o);
$opt_l = 10 unless defined($opt_l);
$opt_v = 1 if defined($opt_V);
$opt_S = "state/$PROG_NAME" unless defined($opt_S);


# End of  GT Antelope Perl header
##############################################################################
use File::stat;

my $database = shift @ARGV;  # database name
my @orb = @ARGV;

# update time in seconds
my $sleep = $opt_l ; # how long to wait between checks

# time to wait in seconds for a magnitude to arrive
my $timetowait = $opt_m;

my $statefile = $opt_S;

# tables to include in /pf/orb2dbt packet
our @dbtables=qw(origin event assoc arrival origerr netmag stamag);

# process most recent modified row of $opt_d not specified 
my $last_lddate  = 0; # default is to process "ALL" origins
if ($opt_o eq "NEW") {
	# Go to end of database and process new origins
	$last_lddate = now();
} 
$last_lddate = &read_lastlddate($statefile) if ($opt_o eq "STATE");
&write_lastlddate($last_lddate, $statefile) unless (-e $statefile);

# start log file
my $epochnow = str2epoch("now");
my $timestrnow = strydtime( $epochnow ); # epochtime now
print STDERR "\n###########  $PROG_NAME $timestrnow ##############\n\n";
printf STDERR "\n\nStarting with last_lddate = %s ($last_lddate)\n",strtime($last_lddate) ; 

# force first run at startup after sleeping
my $last_mtime  = 0;

# How many records to process at once
my $ORIGINS_PER_ITER = 99;

# Read the database to get the origin file name
my @db      = dbopen($database, "r" ) ;
my @dbor    = dblookup(@db, "", "origin", "", "" ) ;
@dbor = dbsubset(@dbor, $opt_s) if defined($opt_s); # subset if "-s subset_expr" command line option used
my $or_file = dbquery(@dbor,"dbTABLE_FILENAME"); # filename of origin table  
dbclose(@db);

# Sit and wait for new origin db rows
for (;;) {
	sleep $sleep if ( $last_mtime != 0 );
	my $inode = stat("$or_file");
	my $mtime = $inode->mtime ; # when was origin table last modified?
	if ($mtime > $last_mtime ) {
		printf STDERR "\n\n$or_file modified at %s\n",strydtime($mtime);
		my $number_new_origins=-1;
		# LOOP OVER "ORIGINS_PER_ITER"  NEW ORIGINS AT A TIME, UNTIL DONE
		do{
			
			@db = dbopen($database, "r");
			@dbor = dblookup(@db, "", "origin", "", "");
			# Update last_lddate from state file, if using this mode. Provides for manual override to earlier lddate.
			$last_lddate = &read_lastlddate($statefile) if ($opt_o eq "STATE");
			printf STDERR "Subsetting for origins with lddate > %s\n", strydtime($last_lddate);
			@dbor = dbsubset(@dbor, "lddate > $last_lddate");
			@dbor = dbsubset(@dbor, $opt_s) if defined($opt_s); # subset if "-s subset_expr" command line option used
			@dbor = dbsort(@dbor, "lddate");
			$number_new_origins = dbquery(@dbor, "dbRECORD_COUNT");
			print STDERR "There are $number_new_origins new origins in $or_file\n";
			printf STDERR "These will be processed %d at a time, to prevent memory leaks", $ORIGINS_PER_ITER if ($number_new_origins > $ORIGINS_PER_ITER);
			my $new_lddate=0;

			# CRUNCH THROUGH NEXT "ORIGINS_PER_ITER" ORIGINS
			for ( my $rownum = 0 ; $rownum < $number_new_origins &&  $rownum < $ORIGINS_PER_ITER; $rownum++ ) { # Process only "ORIGINS_PER_ITER" records
				$dbor[3] = $rownum ;
				printf STDERR "\nThis is new origin %d (there are %d remaining)\n", ($rownum+1), ($number_new_origins - $rownum - 1) if $opt_v;
				$new_lddate = dbgetv(@dbor, "lddate") ;
				my $mb = dbgetv(@dbor, "mb");
				my $ml = dbgetv(@dbor, "ml");
				my $nass = dbgetv(@dbor, "nass");
				my $orid = dbgetv(@dbor, "orid");
				my $evid = dbgetv(@dbor, "evid");
				my $auth = dbgetv(@dbor, "auth");
				my $otime = dbgetv(@dbor, "time");

				print STDERR "new_lddate = $new_lddate, last_lddate = $last_lddate\n" if $opt_V;
				my $timenow = str2epoch("now");
			
				print STDERR "This is orid $orid  belonging to evid $evid\n" if ($opt_v);
				printf STDERR "Origin time: %s\n",strtime($otime) if ($opt_v);
				print STDERR "Author: $auth, Nass: $nass, mb: $mb, ml: $ml\n" if ($opt_V);		 		
				printf STDERR "Time now: %s,  new_lddate = %s, last_lddate = %s  ...\n",strtime( $timenow ), strtime($new_lddate), strtime($last_lddate) if ($opt_V);


				#### THIS WHOLE SECTION DEALS WITH WAITING FOR MAGNITUDES TO APPEAR IN A REAL-TIME SYSTEM
				#### THERE IS A LATENCY BETWEEN ORBASSOC PACKETS AND ORBMAG PACKETS SO INITIALLY DBT MIGHT
				#### HAVE origin ROW BUT NO ml OR mb
				if (defined($opt_m)) {	
					my $seconds = 0;
					my $retry_secs = 1;
					while ($ml == -999.00 && $mb == -999.00 && $seconds < $opt_m) {
						printf STDERR "Origin has no magnitude data: will wait up to another %d seconds\n",$opt_m - $seconds;
						sleep($retry_secs); 
						$seconds +=$retry_secs; # wait X seconds between rechecks
								
						# re-open and re-read the database 
						# (our view is static, and we want to see if new magnitudes added)
						my @dbor2 = dblookup(@db, "", "origin", "", "");
						@dbor2 = dbsubset(@dbor2, "lddate > $last_lddate");
						@dbor2 = dbsubset(@dbor2, $opt_s) if defined($opt_s); # subset if "-s subset_expr" command line option used
						@dbor2 = dbsort(@dbor2, "lddate");
						$dbor2[3] = dbfind(@dbor2, "orid==$orid");
						$mb = dbgetv(@dbor2, "mb");
						$ml = dbgetv(@dbor2, "ml");
						if ($ml > -999.00 || $mb > -999.00) {	
							print STDERR "Revised ml = $ml, mb = $mb after $seconds seconds\n" ;
						}
						dbclose(@dbor2);
					}
				}
							
				# THIS IS WHERE WE CREATE A /PF/ORB2DBT PACKET (USING run_event)			
				print STDERR "Create packet\n" if $opt_V;
				my ($pfout,$packet) = &run_event($orid, @db) ;

				# if nothing to send, go to next iteration of the loop
				if ($pfout eq "") {
					print STDERR "Empty packet - nothing to send\n" ;
					next;
				}
				print STDERR "Sending orid $orid ...\n" if ($opt_v);
				my $t = now();
				print STDERR "$packet\n" if $opt_V;
								
				# write to multiple orbs (at least one)
				my $orbname;
				foreach $orbname (@orb) {
					my $orbptr = orbopen("$orbname", "w");
					if ( $orbptr < 0 ) { 
						die ( "Can't open $orbname\n" ) ; 
					}	
					my $nby = length($packet);
					my $pktid;
					eval {
						$pktid = orbputx($orbptr, "/pf/orb2dbt", $t, $packet, $nby);
						print STDERR "packet $pktid written to $orbname with $nby bytes\n";
						orbclose($orbptr);
					};
					if ( $@ ne "" ){
						open(FPACKET,">logs/packet");
						print FPACKET $packet;
						close(FPACKET);
						die("Packet $pktid not written to $orbname. See logs/packet\n");
					}	
				}
								
				# Only want to update last_lddate file each time a new record is sent
				&write_lastlddate($new_lddate,$statefile);
				
			} # END OF FOR LOOP FOR SET OF "ORIGINS_PER_ITER"
			
			dbclose(@db);
			$last_mtime = $mtime;
			#STDERR->flush;

		} while($number_new_origins > $ORIGINS_PER_ITER); # END OF DO...WHILE LOOP
		print STDERR "Pausing until modification time for $or_file changes\n";
		
	}
	else
	{
		sleep $sleep;
	}

	# Perhaps something AB added to flush database?
	@db = dbopen($database, "r");
	dbclose(@db);
	
}
1;


#############################################################################################################

sub run_event {
	my ($orid, @db2) = @_ ;
	# GTHO 2010-11-23: Corrected this routine to use $orid from calling loop, rather than record number.
	# This is necessary since subsetting by 
	# lastid > $lastid and "$opt_s" in calling row.
	# Before it was using row number - but referring to different views so sending wrong packet.

	# Build a view for this origin by joining all available tables
	my @dbproc;
	@dbproc = dblookup(@db2, "", "origin", "", "");
	@dbproc = dbsubset(@dbproc, "orid==$orid");
	foreach my $tbl (@dbtables) {
		next if ($tbl eq "origin");
		eval{
			my @dbproc2;
			# Add table if its there
			printf STDERR "Got %d records before adding $tbl\n", dbquery(@dbproc, "dbRECORD_COUNT") if ($opt_V);
			@dbproc2 = dbprocess(@dbproc,"dbjoin $tbl");
			if (dbquery(@dbproc2, "dbRECORD_COUNT") > 0){
				(@dbproc = @dbproc2);
			}
			# if there are no records in dbproc view, then return empty lines
			if ( $@ ne "" || dbquery(@dbproc, "dbRECORD_COUNT") <= 0){ 
				print STDERR "dbprocess failed adding table $tbl for origin $orid\n";
				return ("", "");
			}
		};
	}
	
	my $pfout = "";
	foreach my $tbl (@dbtables) {
			eval {
				# Here we take the dbview for the current origin and separate to print out relevant info to a /pf/orb2dbt packet
				my @dbsep = dbseparate(@dbproc, "$tbl");
				if ($tbl eq "arrival") {
					$pfout .= "arrivals  &Literal{\n" ;
						@dbsep = dbsort(@dbsep, "sta", "iphase");
				} elsif ($tbl eq "assoc") {
					$pfout .= "assocs  &Literal{\n" ;
						@dbsep = dbsort(@dbsep, "sta", "phase");
				} elsif ($tbl eq "event" ) {
					$pfout .= "event  &Literal{\n";
				} elsif ($tbl eq "origin") {
					$pfout .= "origin  &Literal{\n";
				} elsif ($tbl eq "netmag") {
					$pfout .= "magnitude_update        yes\nnetmags  &Literal{\n";
				} elsif ($tbl eq "stamag") {
					$pfout .= "stamags  &Literal{\n";
				} elsif ($tbl eq "origerr") {
					$pfout .= "origerr  &Literal{\n";
				}
				my $num_sep = dbquery(@dbsep, "dbRECORD_COUNT");
				my @sep_fields = dbquery(@dbsep, "dbTABLE_FIELDS");
				my $nfields =  $#sep_fields;
				#print STDERR "$tbl TABLE with $num_sep records and $nfields Fields\n" if $opt_v;
				for ($dbsep[3] = 0; $dbsep[3] < $num_sep; $dbsep[3]++) {
					my $row = "";
					foreach  my $fld (@sep_fields) {
						
						my @dbfld = dblookup(@dbsep, "", "", "$fld", "");
						my $fmt = dbquery(@dbfld, "dbFIELD_FORMAT");
						
						my $nul = dbquery(@dbfld, "dbNULL");
						my $fldval = dbgetv(@dbfld, "$fld");
						if ( ($fldval eq "") && ( (substr($fmt, -1) eq "f") || (substr($fmt, -1) eq "d") ) ) {
							$fldval = $nul;
						}	
						
						# must have space after fmt string for orb2dbt to read pf file
						eval {
							$row .= sprintf("$fmt ", $fldval);
						};
						if ( $@ ne "" ) {
							print STDERR "Error: fld = $fld, fmt = $fmt, fldval = $fldval, nul = $nul\n";
						}
						
					} # end foreach
					
					chop $row ;
					#print STDERR "$row\n" if $opt_v;
					$pfout .= "$row\n";
					
				} # end for
				
				$pfout .= "}\n";
				print STDERR "Added $tbl to /pf/orb2dbt packet\n" if $opt_V;
					
			}; # end try
			if ( $@ ne "" ){
				print STDERR "dbseparate failed: No $tbl table for this origin\n" if ($opt_V);
			}
		
	} # end foreach
	
	my $packet = s2pfpkt($pfout);
	# 20071214: added $pfout to return variables, so we can output packets
	
	return ($pfout,$packet) ;
}


# This is the trick to get a string into packet format (see rtorbcmd)
sub s2pfpkt { 
	my ( $s ) = @_ ; 
	my $packet = chr(0) ;
	$packet .= chr(1) ;
	$packet .= $s ;
	$packet .= chr(0) ;
	return $packet ;
}

sub write_lastlddate {
	($last_lddate,$statefile) = @_;
	print STDERR "write_lastlddate: writing $last_lddate to $statefile\n" if $opt_v;
	if (open(FOUT,">$statefile")) { 
		print FOUT $last_lddate;
		close FOUT;
	}
	else
	{
		print STDERR "Could not write to $statefile";
	}
	
}

sub read_lastlddate {
	my $statefile = $_[0];
	my $last_lddate = 0;
	if (-e $statefile) {
		open(FIN,$statefile);
		$last_lddate = <FIN>;
		close(FIN);
	}
	return $last_lddate; 		
} 

