##############################################################################
# Author: Glenn Thompson (GT) 2012/05/09, but leaning heavily and lifting much
#         of the code in Antelope contrib project "bulletin2orb" by Jennifer
#	  Eakins of UCSD.
#
##############################################################################
use strict 'vars' ; 
#use warnings ; 
use Datascope ; 
use lib ".";
#use bulletin qw(trim fix_time_values);

use Getopt::Std ;

our ( $opt_p, $opt_v, $opt_V, $opt_f ) ; 
our %magnitude_info =  () ; 
our %parsed_info =  () ; 
our %bulletins =  () ; 
our (@dbtmp)  = () ;
our (@origin_record, @event_record, @netmag_record, @arrival_record, @assoc_record, @stamag_record, @remark_record) = () ;
our ($Pf, $pgm, $parser, $parsed_info) ;
our %HoA = () ;
our ($myauth, $listref, %pfinfo);
 
$pgm = $0 ; 
$pgm =~ s".*/"" ;
elog_init ( $pgm, @ARGV) ;
my $cmd = "\n$0 @ARGV" ;

if ( ! getopts('1p:s:vVf:') || @ARGV < 1 || @ARGV > 1) { 
    die ( "Usage: $0 [-p pf] [-vV] [-f firstid] dbname \n" ) ; 
}

elog_notify($cmd);

$opt_v = "1" if $opt_V ;

my $dbname = shift;
die("Database $dbname already exists: will not overwrite: Aborting.\n") if (-e $dbname);

my $t;
$t = time();
$t = strtime($t);

elog_notify("\nStarting $pgm at: $t");

# get pf info to see what bulletins will be collected

&get_newpf; 

elog_notify("Done with get_newpf\n") if $opt_V;
  
#
# This is the main program:
# Figure out what bulls to collect
# Collect info from remote website
# parse website into readable text
# write origins to database
# sleep, repeat
#

my @keys = sort keys %bulletins;
my $num_keys = @keys;

for my $i (@keys) {
  $HoA{$i} = [ ] ;
}

dbcreate($dbname, "css3.0");
system("touch $dbname.event");
system("touch $dbname.origin");
system("touch $dbname.netmag");
system("touch $dbname.arrival");
system("touch $dbname.assoc");
system("touch $dbname.stamag");
system("touch $dbname.remark");
system("touch $dbname.lastid");
@dbtmp   = dbopen("$dbname","r+");
our @event = dblookup(@dbtmp,"","event","","dbNULL");
our @origin = dblookup(@dbtmp,"","origin","","dbNULL");
our @netmag = dblookup(@dbtmp,"","netmag","","dbNULL");
our @arrival = dblookup(@dbtmp,"","arrival","","dbNULL");
our @assoc = dblookup(@dbtmp,"","assoc","","dbNULL");
our @stamag = dblookup(@dbtmp,"","stamag","","dbNULL");
our @remark = dblookup(@dbtmp,"","remark","","dbNULL");
if ($opt_f) {
	my @lastid = dblookup(@dbtmp,"","lastid","","dbNULL");
	dbaddv(@lastid, "keyname", "arid", "keyvalue", $opt_f);
	dbaddv(@lastid, "keyname", "evid", "keyvalue", $opt_f);
	dbaddv(@lastid, "keyname", "commid", "keyvalue", $opt_f);
	dbaddv(@lastid, "keyname", "orid", "keyvalue", $opt_f);
	dbaddv(@lastid, "keyname", "magid", "keyvalue", $opt_f);
}
our ($evid, $orid, $magid, $arid, $commid);

foreach our $key (keys %bulletins)  {		

	my $collector	= "collect_" . $key->{method} ;		
	elog_notify ("\n\tBulletin to collect is: $key \n") ; 
	elog_notify ("collection method is: $collector\n") ; 

	if ( $key->{localdir} && (! -d $key->{localdir} ) ) {
	   my $mkdir = "mkdir -p $key->{localdir} " ;
	   system ( $mkdir ) ;
	   if ($?) {
	      elog_complain ("$mkdir error $? \n") ;
	      exit(1);  
	   }
	}

	my @bulletinlist	= &$collector($HoA{$key},%$key) ;		# collect_$key->{handler} must exist in bulletin.pm

	my $origin_valid = 0; # Mechanism to eliminate null origins (lat,lon = 0)
	foreach my $newline (@bulletinlist) {
	  elog_notify("$newline\n") if ($opt_V);
	  $parser	= "parse_" . $key->{parser} ;
	  our ($p, $m) = &$parser($newline) ;	# $key->{parser} must exist in bulletin.pm # $p and $m could be many things depended on whether origin, arrival or stamag line
	  %parsed_info = %$p; 
	  %magnitude_info = %$m; 
	  while (my ($k, $v) = each(%parsed_info)){
		print "\t$k: $v\n" if ($opt_V);
	  }
	  #my @mag_keys = sort ( keys %magnitude_info ) ;

	  if ($parsed_info{'linetype'} eq "origin") {
		if ($parsed_info{'lat'} == 0.0 && $parsed_info{'lon'} == 0.0) {
			$origin_valid = 0;
		}
		else
		{
			$origin_valid = 1;
		}	
	  	addevent2db() if ($origin_valid);
	  } elsif ($parsed_info{'linetype'} =~ /arrival/) {
	  	addarrival2db() if ($origin_valid);
	  } elsif ($parsed_info{'linetype'} =~ /stamag/) {
	  	addstamag2db() if ($origin_valid);
	  };



	}
}	
#dbclose(@remark);
#dbclose(@stamag);
#dbclose(@assoc);
#dbclose(@arrival);
#dbclose(@netmag);
#dbclose(@origin);
#dbclose(@event);
dbclose(@dbtmp);

  

#
# subroutines under here
#

sub get_newpf {

  if ($opt_p) {
      $Pf = $opt_p;
  } else {
      $Pf = $pgm ;
  }
	print "Pf: $Pf\n" if ($opt_v);

  my $ref		= pfget ($Pf, 'bulletins' );
  %bulletins	= %$ref ;


  foreach my $task (keys %bulletins) {
    %$task = (
	method	=> pfget ($Pf, "bulletins\{$task}\{method\}\}"),
	parser 	=> pfget ($Pf, "bulletins\{$task}\{parser\}\}"),
	extractor 	=> pfget ($Pf, "bulletins\{$task}\{extractor\}\}"),
	src	=> pfget ($Pf, "bulletins\{$task}\{src\}\}"),
	auth	=> pfget ($Pf, "bulletins\{$task}\{auth\}\}"),
	url 	=> pfget ($Pf, "bulletins\{$task}\{url\}\}"), 
	TZ	=> pfget ($Pf, "bulletins\{$task}\{TZ\}\}"), 
	defaultmt	=> pfget ($Pf, "bulletins\{$task}\{defaultmagtype\}\}"), 
	ftphost	=> pfget ($Pf, "bulletins\{$task}\{ftphost\}\}"), 
	ftpdir 	=> pfget ($Pf, "bulletins\{$task}\{ftpdir\}\}"), 
	ftpmatch	=> pfget ($Pf, "bulletins\{$task}\{ftpmatch\}\}"), 
	linestart	=> pfget ($Pf, "bulletins\{$task}\{linestart\}\}"), 
	linelength	=> pfget ($Pf, "bulletins\{$task}\{linelength\}\}"), 
	localdir => pfget ($Pf, "bulletins\{$task}\{localdir\}\}"), 
	account	=> pfget ($Pf, "bulletins\{$task}\{account\}\}"), 
	match	=> pfget ($Pf, "bulletins\{$task}\{match\}\}"), 
	reject	=> pfget ($Pf, "bulletins\{$task}\{reject\}\}"), 
	ndays	=> pfget ($Pf, "bulletins\{$task}\{ndays\}\}"),
	enddate	=> pfget ($Pf, "bulletins\{$task}\{enddate\}\}"),
	db	=> pfget ($Pf, "bulletins\{$task}\{db\}\}"),
	authsubset	=> pfget ($Pf, "bulletins\{$task}\{authsubset\}\}")
    );

    if ($opt_V) { 
	elog_notify sprintf "method: %s \n", $task->{method}  ;
	elog_notify sprintf "parser: %s \n", $task->{parser}  ;
	elog_notify sprintf "src:  %s \n", $task->{src}  ;
	elog_notify sprintf "auth:  %s \n", $task->{auth}  ;
    }

    elog_notify sprintf "\t Task:  $task\n";  

    my $testmethod = "collect_" . $task->{method} ;
    my $testparser = "parse_" . $task->{parser} ;


  }

}

sub addstamag2db  { 

  return unless ($orid>0);
  my @stamag_record = ();
  $commid = dbnextid(@remark, "commid"),
  push(@stamag_record,	"magid", $magid,
			"sta", $parsed_info{"sta"}, 
			"arid", $arid,
			"orid", $orid,
			"evid", $evid,
			#"phase", $parsed_info{iphase},
			"magtype", $parsed_info{magtype},
			"magnitude", $parsed_info{magnitude},
			"commid", $commid,
			"auth",	$parsed_info{auth}
	);
  elog_notify("stamag_record:\n\t@stamag_record\n") if ($opt_V);
  eval {   
	dbaddv(@stamag,@stamag_record);
  };
  if ($@) {
  	print "Could not write stamag record: @stamag_record\n";
	return;
  }
  &addremark2db();
}

sub addremark2db {
  my @remark_record = ();
  push(@remark_record,	"commid", $commid,
			"lineno", 1, 
			"remark", $parsed_info{"comment"} 
	);
  elog_notify("remark_record:\n\t@remark_record\n") if ($opt_V);
  dbaddv(@remark,@remark_record);
}

sub addarrival2db  { 

  my @arrival_record = ();

  $arid = dbnextid(@arrival, "arid");
  push(@arrival_record,	"sta", $parsed_info{"sta"}, 
			"time", $parsed_info{"atime"}, 
			"arid", $arid,
			"chan", $parsed_info{"chan"},
			"iphase", $parsed_info{"iphase"},
			"azimuth", $parsed_info{"azimuth"},
			"ema", $parsed_info{"ema"},
			"amp", $parsed_info{"amp"},
			"per", $parsed_info{"per"},
			"auth",	$parsed_info{auth}
	);
  elog_notify("arrival_record:\n\t@arrival_record\n") if ($opt_V);
  eval {   
	dbaddv(@arrival,@arrival_record);
  };
  if ($@) {
  	print "Could not write arrival record: @arrival_record\n";
	return;
  }

  my @assoc_record = ();
  push(@assoc_record,	"arid", $arid,
			"orid", $orid, 
			"sta", $parsed_info{"sta"}, 
			"phase", $parsed_info{"iphase"} 
	);
  elog_notify("assoc_record:\n\t@assoc_record\n") if ($opt_V);
  dbaddv(@assoc,@assoc_record);
  my $nass = dbgetv(@origin, "nass");
  dbputv(@origin, "nass", ++$nass);
}




sub addevent2db  { # &addevent2db() ;

  ########### WRITE THE EVENT ROW
  my @event_record = ();
  my @origin_record ; 
  my @netmag_record ; 
  $evid = dbnextid(@event, "evid");
  $orid = dbnextid(@origin, "orid");
  push(@event_record, 	"evid",		$evid,
			"prefor",	$orid,
			"auth",		$parsed_info{auth}
	);
  elog_notify("event_record:\n\t@event_record\n") if ($opt_V);
  dbaddv(@event,@event_record);
  
  ########### WRITE THE NETMAG ROWS
  my ($magval, $magtype, $magkey, $magnsta, $magauth ) ;
  my $magcnt = 0 ;
  #my $magid = -1;
  my $mlid = -1;
  my $msid = -1;
  my $mbid = -1;

  foreach my $magkey (keys %magnitude_info) {
     next if (length($magkey) < 2); # ignore if "m" or ""
     if ( $magnitude_info{$magkey} =~ /:/ ) {
        ($magval, $magauth, $magnsta) = split(':',$magnitude_info{$magkey}) ;
	$magtype = $magkey ; 
     } else {
        $magval  = $magnitude_info{$magkey} ; 
        $magtype = $magkey ; 
        $magnsta = $parsed_info{mag_nsta} ; 
	$magauth = $parsed_info{auth} ;
     }
     $magid = dbnextid(@netmag, "magid");
     $mlid = $magid if ($magtype eq "ml");
     $msid = $magid if ($magtype eq "ms");
     $mbid = $magid if ($magtype eq "mb");

     elog_notify(sprintf "mag: $magval$magtype  time: %s auth: $magauth\n", strtime($parsed_info{or_time}) )  if $opt_v ;
     push(@netmag_record, 	"orid",		$orid,
			"evid",		$evid,
			"magtype",	$magtype,
			"magnitude",	$magval,
			"magid",	$magid ,
			"nsta",		$magnsta,
			"uncertainty",	$parsed_info{mag_uncert},
			"auth",		$magauth
     );

     elog_notify("netmag:\n\t@netmag_record\n") if ($opt_V);
     dbaddv(@netmag,@netmag_record);
     $magcnt++ ;
  }

  # WRITE THE ORIGIN ROW
  elog_notify("Magnitudes in create_origin: \n \t\tml: $parsed_info{ml}\n \t\tmb: $parsed_info{mb}\n \t\tms: $parsed_info{ms}\n") if ($opt_V);

  my $ml = ( defined $magnitude_info{'ml'} ) ? $magnitude_info{'ml'} : "-999.0" ;
  my $mb = ( defined $magnitude_info{'mb'} ) ? $magnitude_info{'mb'} : "-999.0" ;
  my $ms = ( defined $magnitude_info{'ms'} ) ? $magnitude_info{'ms'} : "-999.0" ;
	$commid = dbnextid(@remark, "commid"),


  push(@origin_record,
  		"lat",          $parsed_info{lat},
		"lon",          $parsed_info{lon},
		"depth",        $parsed_info{depth},
		"time",         $parsed_info{or_time},
		"orid",         $orid,
		"evid",         $evid,
		"jdate",        yearday("$parsed_info{or_time}"),
		"nass",         $parsed_info{nass},
		"ndef",         $parsed_info{ndef},
		"ndp",          $parsed_info{ndp},
		"grn",          grn("$parsed_info{lat}","$parsed_info{lon}"),
		"srn",          srn("$parsed_info{lat}","$parsed_info{lon}"),
		"dtype",        $parsed_info{dtype},
		"etype",        $parsed_info{etype},
		"review",       $parsed_info{review},
		"depdp",        $parsed_info{depdp},
		#"mbid",         $parsed_info{mbid},
		#"ms",           $parsed_info{ms},
		#"mb",           $parsed_info{mb},
		#"ml",           $parsed_info{ml},
		#"msid",         $parsed_info{msid},
		#"mlid",         $parsed_info{mlid},
		"mbid",         $mbid,
		"ms",           $ms,
		"mb",           $mb,
		"ml",           $ml,
		"msid",         $msid,
		"mlid",         $mlid,
		"auth",         $parsed_info{auth},
		"algorithm",    $parsed_info{algorithm},
		"commid", $commid
	);

  elog_notify("origin_record:\n\t@origin_record\n") if ($opt_V);
  $origin[3] = dbaddv(@origin,@origin_record);
  $parsed_info{comment} = $parsed_info{auth};
  &addremark2db();

}


sub parse_HYPOSHA {	

  my $line = shift ; 
  # need to split line here to determine what kind of line it is!
  my @field = split(",", $line);
  my $linetype = $field[0];

 
  if ($linetype eq "origin") { 
  	our %magnitude_info = () ;

  	my ($linetype, $lat, $lon, $depth, $or_time, $nsta, $mag_type, $mag, $extevid, $eventtype) = split(",",$line); 
  	%magnitude_info = (
                $mag_type  	=> $mag
  	) ;

  	my ($ml,$mlid,$mb,$mbid,$ms,$msid,$magid) = &default_mags(%magnitude_info) ;

  	%parsed_info = (
		linetype	=> $linetype,
                or_time		=> $or_time ,
                lat             => $lat ,
                lon             => $lon ,
                depth           => $depth ,
                ndef		=> $nsta,
		orid		=> "1" ,
        	evid		=> "1" ,
                nass		=> "0"   ,
                ndp 		=> "-1"   ,
                etype		=> $eventtype   ,
                depdp		=> "-999.0"   ,
                review		=> "-"   ,
                dtype 		=> "-"   ,
                mag_nsta        => "-1" ,
                mag_uncert	=> "-1" ,
                magid		=> $magid ,
                mb		=> $mb ,
                mbid		=> $mbid ,
                ml		=> $ml ,
                mlid		=> $mlid ,
                ms		=> $ms ,
                msid		=> $msid ,
                magtype		=> $mag_type,
                magnitude	=> $mag,
		auth		=> $myauth . ":" . $extevid, 
		algorithm	=> "hypo2000" 
  	) ;   

 	
  	return (\%parsed_info, \%magnitude_info) ;
  } elsif ($linetype =~ /arrival/) { 

      	my ($linetype, $sta, $chan, $net, $ar_time, $iphase, $azimuth, $ema, $amp, $per, $auth) = split(",", $line);

  	%parsed_info = (
		linetype	=> $linetype,
                sta		=> $sta ,
                chan             => $chan ,
                net             => $net ,
                atime           => $ar_time ,
                iphase		=> $iphase,
		azimuth		=> $azimuth ,
        	ema		=> $ema ,
                amp		=> $amp   ,
                per 		=> $per   ,
                auth		=> $auth   
  	) ;   
 	
  	return (\%parsed_info, "") ;
  } elsif ($linetype =~ /stamag/) { 

      	my ($linetype, $sta, $magtype, $mag, $auth, $comment) = split(",", $line);

  	%parsed_info = (
		linetype	=> $linetype,
                sta		=> $sta ,
                magtype             => $magtype ,
                magnitude             => $mag ,
                auth           => $auth ,
                comment		=> $comment
  	) ;   
 	
  	return (\%parsed_info, "") ;

  }
}

sub extract_HYPOSHA	{	# BK and CI HYPO2000 versions mostly the same

  my @saved = ();
  foreach my $line (@_) { 

	if ($line =~ /^\n|^<|#/) {
		next;
	} elsif ($line =~ /^[19|20]/) { # a summary line, starting with a year
      
      		my $year	= substr($line, 0, 4);
      		my $month	= substr ($line, 4, 2);
      		my $day	= substr ($line, 6, 2);
      		my $hr	= substr ($line, 8, 2);
      		my $min	= substr ($line, 10, 2);
      		my $sec	= substr ($line, 12, 4);

      		my $latd	= substr ($line, 16, 2);
      		my $latNS	= substr ($line, 18, 1);
      		my $latm	= substr ($line, 19, 4);

      		my $lond	= substr ($line, 23, 3);
      		my $lonEW	= substr ($line, 26, 1);
      		my $lonm	= substr ($line, 27, 4);

      		my $depth	= substr ($line, 31, 5);

      		my $nsta	= (substr ($line,118, 3));

      		my $extevid	= (substr ($line,136,10)); 
      		my $mag_type = "";
      		my $mag = "";
      		if (lc(substr ($line,146, 1)) =~ /[a-z]/) {
      			$mag_type	= "m" . lc(substr ($line,146, 1)); 
      			$mag	= substr($line,147, 3); 
        		$mag = trim($mag)/100;
      		}

		# NC uses version number:
		# Version number of information: 0=25 pick; 1=Final EW with MD;
		#                   2=ML added, etc. 0-9, then A-Z. Hypoinv. passes this through.
		# seems to be 0 -> 5?

      		my $revlevel	= substr ($line,162, 1); 

		# Version # of last human review. blank=unreviewed, 1-9, A-Z.
		# seems to be either "F" or "A"?

	   	my $humanrevlevel	= substr ($line,163, 1); 

		$sec	= $sec/100 ;
		$latm = $latm/100;
		$lonm = $lonm/100; 
		$depth = trim($depth)/100; 
		$nsta = trim($nsta);

		$extevid = trim($extevid) . $revlevel . $humanrevlevel ;

		if (!$nsta) {
			$nsta= "0"; 
		}
  
		my ($lat,$lon) = fix_lat_lon ($latd,$latm,$latNS,$lond,$lonm,$lonEW) ; 

		my $value =  fix_time_values ($year,$month,$day,$hr,$min,$sec)  ; 

		my $or_time = str2epoch( fix_time_values ($year,$month,$day,$hr,$min,$sec) ) ; 
		my $eventtype = trim(substr($line, 80, 2));
		$eventtype = "-" if (length($eventtype) == 0);

		push (@saved, join(',', ("origin", $lat, $lon, $depth, $or_time, $nsta, $mag_type, $mag, $extevid, $eventtype) ) ) ; 
	    
	} elsif ($line =~ /^[A-Z][A-Z][A-Z]/) { # arrival line, starting with station name
		my $sta = trim(substr($line, 0, 5));
		my $net = trim(substr($line, 5, 2));
		my $chan = trim(substr($line, 9, 3));
		my $premark = trim(substr($line, 13, 2));
		my $piphase = "P"; 
		my $pfirstmotion = trim(substr($line, 15, 1));
		my $pweightcode = trim(substr($line, 16, 1));
		my $pyear = trim(substr($line, 17, 4));
		my $pmonth = trim(substr($line, 21, 2));
		my $pday = trim(substr($line, 23, 2));
		my $phour = trim(substr($line, 25, 2));
		my $pmin = trim(substr($line, 27, 2));
		my $psec = trim(substr($line, 29, 5));
		$psec /= 100 if ($psec > 0);
		my $p_ar_time = str2epoch( fix_time_values ($pyear,$pmonth,$pday,$phour,$pmin,$psec) ) ; 
		my $presidual = trim(substr($line, 34, 4))/100;
		my $pweight = trim(substr($line, 38, 3))/100;
		my $ssec = trim(substr($line, 41, 5));
		$ssec /= 100 if ($ssec > 0);
		my $s_ar_time = str2epoch( fix_time_values ($pyear,$pmonth,$pday,$phour,$pmin,$ssec) ) ; 
		my $sremark = trim(substr($line, 46, 2));
		my $siphase = "S"; 
		my $sweightcode = trim(substr($line, 49, 1));
		my $sresidual = trim(substr($line, 50, 4))/100;
		my $amplitude = trim(substr($line, 54, 7));
		$amplitude /= 100 if (length($amplitude) > 0);
		my $ampcode = trim(substr($line, 61, 2));
		my $amp = -1.0; # null value
		if ($ampcode eq "1") { 
			$amp = $amplitude; 
		} elsif ($ampcode eq "0") { 
			$amp = $amplitude/2; 
		} # should be instrument corrected and integrated to displacement
		my $sweight = trim(substr($line, 63, 3))/100;
		my $pdelaytime = trim(substr($line, 64, 4))/100;
		my $sdelaytime = trim(substr($line, 70, 4))/100;
		my $epidist = trim(substr($line, 74, 4));
		$epidist /= 10 if (length($epidist) > 0); 
		my $ema = trim(substr($line, 78, 3));
		if (length($ema)==0) {
			$ema = -1;
		}
		my $per= trim(substr($line, 83, 3));
		if (length($per)>0) {
			$per /= 100;
		} else {
			$per = -1;
		}
		my $codaduration = trim(substr($line, 87, 4));
		my $azimuth = trim(substr($line, 91, 3));
		if (length($azimuth)==0) {
			$azimuth = -1;
		}
		my $md= trim(substr($line, 94, 3));
		my $ma= trim(substr($line, 97, 3));
		my $mdcode= trim(substr($line, 109, 1));
		my $macode= trim(substr($line, 110, 1));
		my $amptype= trim(substr($line, 113, 2));
		#my $maused= !defined(trim(substr($line, 118, 1)));
		#my $mdused= !defined(trim(substr($line, 119, 1)));
		my $auth= "hypo2000";

		# Create arrival line
		if (defined($premark)) { # P
			push (@saved, join(',', ("P_arrival", $sta, $chan, $net, $p_ar_time, $piphase, $azimuth, $ema, $amp, $per, $auth)));
		}
		if (defined($sremark)) { # S
			push (@saved, join(',', ("S_arrival", $sta, $chan, $net, $s_ar_time, $siphase, $azimuth, $ema, $amp, $per, $auth)));
		}

		# Create stamag line
		if (length($md)>0) { # md for this sta
			my $comment = "codaduration=$codaduration";
			push (@saved, join(',', ("stamag", $sta, "md", $md/100, $auth, $comment)));
		}
		if (length($ma)>0) { # ma for this sta
			my $comment = "amp=$amp";
			push (@saved, join(',', ("stamag", $sta, "ml", $ma/100, $auth, $comment)));
		}

	}
  }
  
  return @saved; 
}

sub collect_file	{		

  ($listref,%pfinfo) = @_ ;

  #my $myfile	= $pfinfo{file} ;
  my $myfile	= "results.hyp" ;
  $myauth	= $pfinfo{auth};
  my $linestart	= $pfinfo{linestart};
  my $extract_handler = ( defined $pfinfo{'extractor'} ) ? "extract_" . $pfinfo{extractor} : 0   ;
  elog_notify("myfile = $myfile\nmyauth=$myauth\nlinestart=$linestart\nextract_handler=$extract_handler\n") if ($opt_V);

  my ($mb, $ms, $partcnt, $ok, $ymd, $hour  ) ; 
  my ($lat, $lon, $depth, $or_time) ;

  my @outlist ;
  my @saved ;

# now have to populate @saved
# open each file and make sure first line starts with "GS", or "E", or "whatever"

  open FILE, "<$myfile";
  while (<FILE>) {
      my $line = $_ ;
      next if ( $line !~/^($linestart)/ ) ;	
#      next if ( ($linelength > 0 ) && (length($line) < $linelength) ) ; 
      push @saved, $line ;	# put all lines from file into @saved
  }

  my $x = $#saved + 1 ;
  elog_notify("   Found $x events from recovered file\(s\)\n");
  close FILE ;
  @saved = &$extract_handler(@saved) if ($extract_handler) ;
  @outlist = list2search(@saved) ;

  return @outlist ;

} 

sub trim {

  my @out = @_;
  for (@out) {
     s/^\s+//;
     s/\s+$//;
  }

  return wantarray ? @out : $out[0];
}


sub fix_time_values {
  my ($yr,$month,$day,$hr,$min,$sec) = @_;

  if ($day < 10) {
    $day =~ s/^\s+//; 
  }

  if ($month < 10) {
    $month =~ s/^\s+//; 
  }

  if ( ($min =~ /\d/) &&  ($min < 10) ){
    $min =~ s/^\s+//; 
  } elsif (!$min) {
    $min = "00" ; 
  }

  if ( ($sec =~ /\d/) && ($sec < 10) ) {
    $sec =~ s/^\s+//; 
  } elsif (!$sec || $sec =~ /\s+/) {
    $sec = "0.0";
  }

  if ( ($hr =~ /\d/) && ($hr < 10) ) {
    $hr =~ s/^\s+//; 
  } elsif (!$hr || $hr =~ /\s+/) {
    $hr = "00" ;
  }

#							#
# Attepmt to cover the case where sec or min = 60 	#
# or hr = 24. 						#
# (i.e. the input is slightly foobar).			#
#							#
  while ($sec < 0.0) {	# deal with negative seconds
    $sec 	= 60.0 + $sec ; 
    $min 	= $min - 1;
  }

  while ($sec >= 60.0) {
    $sec 	= $sec - 60.0; 
    $min 	= $min + 1;
  }

  while ($min <   0.0) {
    $min 	= 60.0 + $min ; 
    $hr 	= $hr - 1;
  }

  while ($min >= 60.0) {
    $min 	= $min - 60.0; 
    $hr 	= $hr + 1;
  }

  while ($hr  <   0.0) {
    $hr  	= 24.0 + $min ; 
    $day 	= $day - 1;
  }

  while ($hr >= 24.0) {
    $hr 	= $hr - 24.0; 
    $day 	= $day + 1;
  }

  my $mytime	= sprintf ("%s\/%s\/%s %s:%s:%s", $month, $day, $yr, $hr, $min, $sec) ;

  return ($mytime);
	    
}

sub fix_lat_lon {

  my ($latd,$latm,$latNS,$lond,$lonm,$lonEW) = @_;
  my ($lat, $lon);
	
  if ($latNS =~ /S|s/)  {
    $lat = -1 * $latd; 
    $lat = $lat - ($latm/60.0);
  } else {
    $lat = $latd + ($latm/60.0);
  }

  if ($lonEW =~ /E|e/) {
    $lon = $lond + ($lonm/60.0);
  } else {
    $lon = -1 * $lond; 
    $lon = $lon - ($lonm/60.0);
  }

  return ($lat,$lon); 
}

sub fix_or_time {	#	@fix_or_time($ymd, $hour, $TZ) ;

 my ($ymd, $hr, $tz) = @_ ;
 my $epoch;
 
 if ($tz =~ /PDT|PST/) {
   $epoch = str2epoch ( "$ymd $hr US/Pacific" ) ;
 } elsif ($tz =~ /MDT|MST/) {
   $epoch = str2epoch ( "$ymd $hr US/Mountain" ) ;
 } elsif ($tz =~ /CDT|CST/) {
   $epoch = str2epoch ( "$ymd $hr US/Central" ) ;
 } elsif ($tz =~ /EDT|EST/) {
   $epoch = str2epoch ( "$ymd $hr US/Eastern" ) ;
 } else {
   $epoch = str2epoch ( "$ymd $hr" );
 }

 return ($epoch) ; 

}

sub list2search {	# list2search(@text)  returns @outlist

  my (@textlist)  = @_; 
  my @out = () ;	# this may cause multi-ftp grabs to fail miserably

  foreach my $newline (@textlist) {
    my $linematch = 0;
    foreach my $oldline (@{$listref}) {
        if ($newline eq $oldline) {
            $linematch = 1;
            last;
        }
    }   
    if ($linematch == 0) {
        push @{$listref}, $newline ;
        push @out, $newline ;
    }   
  }

  my $n = @out;
  elog_notify ("\t $n new origins to be included\n\n") ; 

  return @out ;
}

sub default_mags {	# ($ml,$mb,$ms) = default_mags(%magnitude_info)

  my (%get_magnitude_info) = @_ ; 

  my ($afoo, $bfoo) ;

  $magid = 1; 	# always the case if only a single magnitude is reported

  my $ml = ( defined $get_magnitude_info{'ml'} ) ? $get_magnitude_info{'ml'} : "-999.0" ;
  my $mb = ( defined $get_magnitude_info{'mb'} ) ? $get_magnitude_info{'mb'} : "-999.0" ;
  my $ms = ( defined $get_magnitude_info{'ms'} ) ? $get_magnitude_info{'ms'} : "-999.0" ;

  my $mlid = ( (defined $get_magnitude_info{'ml'}) ) ? 1 : -1 ;
  my $mbid = ( (defined $get_magnitude_info{'mb'}) ) ? 1 : -1 ;
  my $msid = ( (defined $get_magnitude_info{'ms'}) ) ? 1 : -1 ;

  if ($ml =~ /:/) {
     ($ml,$afoo,$bfoo) = split (':',$ml) ; 
  } 
  if ($mb =~ /:/) {
     ($mb,$afoo,$bfoo) = split (':',$mb) ; 
  } 
  if ($ms =~ /:/) {
     ($ms,$afoo,$bfoo) = split (':',$ms) ; 
  }

  return ($ml,$mlid,$mb,$mbid,$ms,$msid,$magid) ;

}


