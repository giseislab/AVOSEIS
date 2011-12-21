package Avoseis::Utils;

#use 5.000000;
use strict;
use warnings;

require Exporter; 

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Avoseis::Utils ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

# variable names
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# subroutines
our @EXPORT = qw( 
getPf 
prettyprint
median 
floorMinute
runCommand 
watchtable	
);

#our $VERSION = '0.01';
our $VERSION = sprintf "%d.%03d", q$Revision: 1.5 $ =~ /: (\d+)\.(\d+)/;

use Datascope;
use POSIX qw(log10 ceil);

# globals


# Preloaded methods go here.

###############################################################################
### LOAD PARAMETER FILE                                                      ##
###    $pfobjectref = getPf($PROG_NAME, $opt_p, $opt_v);                     ##
###                                                                          ##
### Glenn Thompson, 2009/04/20                                               ##
###                                                                          ##
### Load the parameter file for this program, given it's path                ##
###############################################################################
sub getPf {
	my ($PROG_NAME, $opt_p, $opt_v) = @_;

	my ($pfile, $pfobjectref);

	# Get parameter file object reference from all files that match $PROG_NAME.pf along PFPATH cascade
	my @pfilearr = `pfwhich $PROG_NAME`; # get a list of all pfiles in cascade
	if ($#pfilearr > -1) {
		$pfile = $pfilearr[$#pfilearr]; chomp($pfile); # get the last pfile in the cascade
		if (-e $pfile) { # if pfile exists, read from it
			$pfobjectref = pfget($pfile, ""); # read all parameters from pfile into a hash ref
		}
	}

	# Override with parameters from a parameter file of a different name if -p option used
	if ($opt_p) {
	     	$pfile = $opt_p;
			if (-e $pfile) { # if pfile exists, read from it
			$pfobjectref = pfget($pfile, ""); # read all parameters from pfile into a hash ref
		}
	}
	
	# Display parameters if verbose mode is on
	if ($opt_v) {
		prettyprint($pfobjectref);
	} 
 
	return $pfobjectref;

}


######################################################
### PRETTY PRINT A HASH                             ##
### prettyprint(\%myhash);                          ##
###                                                 ##
### Glenn Thompson, 2009/05/04 after code from BRTT ##
###                                                 ##
######################################################
sub prettyprint {
        my $val = shift;
        my $prefix = "";
        if (@_) { $prefix = shift ; }

        if (ref($val) eq "HASH") {
                my @keys = sort ( keys  %$val );
                my %hash = %$val;
                foreach my $key (@keys) {
                        my $newprefix = $prefix . "{". $key . "}" ;
                        prettyprint ($hash{$key}, $newprefix) ;
                }
        } elsif (ref($val) eq "ARRAY") {
                my $i = 0;
                my @arr = @$val;
                foreach my $entry ( @$val ) {
                        my $newprefix = $prefix . "[". $i . "]" ;
                        prettyprint ($arr[$i], $newprefix) ;
                        $i++;
                }
        } else {
                print $prefix, " = ", $val, "\n";
        }
}

##########################################################
### MEDIAN                                              ##
### $median = median(@values);                          ##
###                                                     ##
### Mike West, 2009/01                                  ##
###                                                     ##
### Calculate the median value of a numeric array       ##
##########################################################
sub median {
	#@_ == 1 or die ('Sub usage: $median = median(\@array);');
	my (@array) = @_;
	@array = sort { $a <=> $b } @array;
	my $count = $#array;
	if ($count % 2) {
		return ($array[$count/2] + $array[$count/2 - 1]) / 2;  # odd
	} else {
		return $array[int($count/2)];	# even no. of elements in array ($count is odd!)
	}
} 

##########################################################
### FLOORMINUTE                                         ##
### $floorEpoch = floorMinute($epoch, $interval)        ##
###                                                     ##
### Glenn Thompson, 2012/12/07                          ##
###                                                     ##
### Round down the epoch time based on interval minutes ##
##########################################################
sub floorMinute {
    my ($etime, $interval) = @_;
    my $newetime;
    return $interval * int($etime / $interval);
}

#############################################################
### RUNCOMMAND                                             ##
### $result = runCommand($cmd, $mode);                     ##
###                                                        ##
### Glenn Thompson, 2009/04/20                             ##
###                                                        ##
### Run a command safely at Unix shell, and return result. ##
### mode==0 just echoes the command and is for debugging.  ##
### mode==1 echoes & runs the command.                     ##
#############################################################
sub runCommand {     
     my ( $cmd, $mode ) = @_ ;
     our $PROG_NAME;

     print "$0: $cmd\n";
     system("echo \"$cmd\" >> logs/runCommand.log") if (-e "logs");
	
     my $result = "";
     $result = `$cmd` if $mode;
     chomp($result);
     $result =~ s/\s*//g;

     if ($?) {
         print STDERR "$cmd error $? \n" ;
	 system("echo \"- error $?\" >> logs/runCommand.log") if (-e "logs");
     	 # unknown error
         exit(1);
     }

     return $result;
}

##########################################################################################################
### WATCHTABLE                                                                                          ##
### ($row_to_start_at, $numnewrows) = &watchtable($database, $table, $last_row_only, $opt_v, $trackpf)  ##
###                                                                                                     ##
### Glenn Thompson, 2009/05/13 based on dbwatchtable                                                    ##
###                                                                                                     ##
### Watch a database table, returning row to start at and number of new rows                            ##
##########################################################################################################
sub watchtable {

	use File::stat;
	use Avoseis::SwarmAlarm;

	my ($database, $table, $last_row_only, $opt_v, $trackpf) = @_;
	my $nrowsprev = 0;
	my $mtimeprev = 0;
	if (-e $trackpf) {
		$nrowsprev = pfget($trackpf, "nrowsprev");
		$mtimeprev = pfget($trackpf, "mtimeprev");
	}
	my $row_to_start_at = $nrowsprev + 1;

	my $nrowsnow = 0;
  	my $numnewrows = 0;

	my $watchfile = "$database.$table"; 
	my $inode = stat("$watchfile");
	my $mtimenow = $inode->mtime ; # when was origin table last modified?
	if ($mtimenow > $mtimeprev) {
		my $mtimestr = epoch2str($mtimenow,"%Y-%m-%d %H:%M:%S");
		print "$watchfile has changed: modification time $mtimestr\n" if $opt_v;
		$nrowsnow = &counttablerows($database, $table);
		$numnewrows =  ($nrowsnow - $nrowsprev);
		print "Number of table rows now is $nrowsnow, previously had $nrowsprev\n" if $opt_v;

		if ($numnewrows > 0) {
			printf "Detected %d new rows added to $watchfile\n",$numnewrows;

			# Get to row to start at, which is either the first new row, or the last row, depending
			# on the value of $last_row_only in the parameter file
			$row_to_start_at = $nrowsnow if ($last_row_only);
			# note db[3] should be set to row_to_start_at - 1
		}
	}

	if (open(FOUT, ">$trackpf")) {
		printf FOUT "nrowsprev\t$nrowsnow\n";
		printf FOUT "mtimeprev\t$mtimenow\n";
		close(FOUT);
	}

	return ($row_to_start_at, $numnewrows);
}
# count the rows in the table of the database
sub counttablerows {
	our $opt_v;
	my ($database, $table) = @_;
	print "Counting rows in $database.$table\n" if $opt_v;
	my @db     = dbopen( $database, "r" ) ;
	@db    = dblookup(@db, "", $table, "", "" ) ;
	my $nrows  = dbquery( @db, "dbRECORD_COUNT") ; # number of records in table
	dbclose(@db);
	return $nrows;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Avoseis::Utils - Perl library used by AVOSEIS programs

=head1 SYNOPSIS

  use Avoseis::Utils;


=head1 DESCRIPTION

Avoseis::Utils was created with h2xs -AXc -n Avoseis::Utils. 

=head2 EXPORT

None by default.

=head2 FUNCTIONS

# read the program parameter file
($pfobjectref) = getPf($PROG_NAME, $opt_p, $opt_v);

# Pretty print a hash 
prettyprint(\%myhash);

# compute the median
$median = median(@values);                          

# round down an epoch time based on an interval of minutes 
$floorEpoch = floorMinute($epoch, $interval);                          

# run a command at the command line
$result = runCommand($cmd, $mode);  

# watch a database table
($row_to_start_at, $numnewrows) = watchtable($database, $table, $last_row_only, $opt_v, $trackpf);    
               
=head2 DATA STRUCTURES

=head1 SEE ALSO

=head1 AUTHOR

Glenn Thompson, E<lt>glenn@giseis.alaska.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Glenn Thompson, University of Alaska Fairbanks

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
