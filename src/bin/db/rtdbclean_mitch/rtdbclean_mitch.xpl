
#   Copyright (c) 2003 Boulder Real Time Technologies, Inc.           
#                                                                     
#   This software module is wholly owned by Boulder Real Time         
#   Technologies, Inc. Any use of this software module without        
#   express written permission from Boulder Real Time Technologies,   
#   Inc. is prohibited.                                               


#    use diagnostics;

    use Datascope ;
    require "getopts.pl" ;
    require "pf2.pl" ;

    my ($cmd,$pid,$new_pid,$problem_child,$nrecs,$wfname,$tmbytes,$nbytes,$two_days,$line);
    my (@dbwfdisc);

    $LOG = "logs";
    $Pf   = "rtdbclean";

    $prog_name = "rtdbclean";
    $rt_db     = "";
    $orb       = "";
    $mail_to   = "";
    $maillog   = "";

    if ( ! &Getopts('p:m:nvVw') || @ARGV != 2 )  {
        $line = "Usage: $0 [-n] [-w] [-v] [-V] [-m mail_to] [-p parameter_file] orb rt_db "  ; 
        &bad_exit ( $line ) ; 
    }

    $orb        = $ARGV[0] ;
    $rt_db      = $ARGV[1];

    if ($opt_m) {
        $mail_to   = $opt_m ;
    }

    if ($opt_p) {
        $Pf   = $opt_p;
    }

    &check_lock($prog_name);

    open (MAILLOG, ">$LOG/rtdbclean_mail" )  || &bad_exit ("Can't open $LOG/rtdbclean_mail") ;
    select((select(MAILLOG), $|=1)[0]) ;  # flush buffers

    $maillog = "$LOG/rtdbclean_mail";

#  Load data from parameter files

    &get_pars();

    $host = &print_header();  

#  Print PFPATH and pf information
  
    print STDERR  &df_avail()/1000, " mbytes available on disk \n\n" if ($opt_v || $opt_V);

    &parameter_check () if ($opt_v || $opt_V) ;

    &check_db();

    $cmd = "orb2db_msg $rt_db pause";
    &run( $cmd );

    if ($pid = fork) {  # parent
        $new_pid = wait ;
        if ($?) {
            $problem_child = 1;
        }
        $cmd = "orb2db_msg $rt_db continue";
        &run( $cmd );
        if ($problem_child) {&bad_exit("Error $? from rtdbclean child process  ");}
        &good_exit();

    } elsif (defined $pid) {  # child
        @dbin     = dbopen  ( $rt_db, "r+");
        @dbwfdisc = dblookup( @dbin,"","wfdisc","","");
        $nrecs    = dbquery ( @dbwfdisc,"dbRECORD_COUNT");
        $wfname   = dbquery ( @dbwfdisc,"dbTABLE_FILENAME");
    
        print STDERR  "$nrecs records in wfdisc \n" if ($opt_v || $opt_V) ; 

        if ($nrecs == 0) { 
            &bad_exit("No wfdisc records in $rt_db ");
        }

# Delete old days if necessary

        @jdates = &get_jdates ( @dbwfdisc ) ;
        print STDERR "\nnumber of jdates - ", ( $#jdates + 1 ) ,"  \n" if ($opt_v || $opt_V) ;
        print STDERR "jdates @jdates  \n" if ($opt_v || $opt_V) ;

        $tmbytes = 0;

        while (($min_disk_free > &df_avail()/1000 ) && ($#jdates >= 0)) {
            print STDERR "Disk test  $min_disk_free > ", &df_avail()/1000, "\n" if ($opt_v || $opt_V);
            $tmbytes += $nbytes = &clean_disk() ;
            if ($opt_n) {
               $min_disk_free -= $nbytes ;
               print STDERR "min_disk_free	$min_disk_free \n";
               print STDERR  &df_avail()/1000, " mbytes available on disk \n" if ($opt_v || $opt_V);
            }
            shift( @jdates ) ;
         }

         while ($max_days_db < $#jdates + 1) {
            print STDERR "Jdate test $max_days_db < ", $#jdates + 1 ,"  \n" if ($opt_v || $opt_V) ; 
            $tmbytes += &clean_disk() ;
            shift( @jdates ) ;
         }

         $two_days = &yearday(time() + (2 * 86400.)) ;
         if ($two_days >  1998001 ) {
            while (@jdates) {
               print STDERR "Future test $jdates[0] > $two_days \n" if ($opt_v || $opt_V); 
               if ($jdates[0] > $two_days ) {
                  $tmbytes += &clean_disk() ;
               }
               shift( @jdates ) ;
            }
         } else {
            print STDERR "two days in the future is not $two_days \n";
         }


        &clean_rt_tables() unless $opt_n;

        &clean_del_arr() unless $opt_n;

        &clean_nojoins() unless $opt_n;

        &db_fixes() unless $opt_n;

        &crunch_time() unless $opt_n;

        &db_fixchanids() unless $opt_n;

        print STDERR "$tmbytes total mbytes removed \n";
        print MAILLOG "$tmbytes total mbytes removed \n";

        $nrecs    = dbquery( @dbwfdisc,"dbRECORD_COUNT" ) ;
        print STDERR  "$nrecs records in wfdisc \n" if ($opt_v || $opt_V) ; 

        exit(0);
    }

exit;


sub df_avail {
    my ( $df) ;
    my ( $aline, $dfline, $ok ) ;

    $df = "df -k $rt_db" ;

    if ( (rindex $df, "/") >= 0 ) {
       $df = substr ($df, 0, (rindex $df, "/")) ;
    }
     
    open ( DF, "$df 2>&1 |" ) ;
    while ( $aline = <DF> ) {
# Linux:
#    Filesystem           1k-blocks      Used Available Use% Mounted on
# Solaris
#    Filesystem            kbytes    used   avail capacity  Mounted on
        if ( $aline =~ /Filesystem/ ) {
	    $ok = 1 ; 
	} else { 
	    chomp ($aline);
	    $dfline .= " $aline" ;
	}
    }
    close DF ;
         
    my ( $device, $max, $used, $avail, $capacity, $mounton ) ;
 
    if ( $ok ) {
        ( $device, $max, $used, $avail, $capacity, $mounton )
            = split ( ' ', $dfline ) ;
    } else {
        &bad_exit("Can't run df -k $rt_db ");
    }
 
    return ( $avail ) ;
}

sub dir_name {  # dir_name ( db ) 
    my (@db) = @_ ;
    my ($dir, $tdir, $dir_file);

    $dir      = dbgetv(@db, qw (dir)) ;  
    $tdir     = dbquery ( @db,"dbTABLE_DIRNAME") ;
    $dir_file = $tdir . "/" . $dir ;

    return ( $dir_file ) ;
}

 
sub get_jdates { # get_jdates ( db )
    my (@db) = @_ ;
    my ($nrecs, $row, $jdate, $time, @jdates) ;

    @db        = dbsort ( @db, "time") ;
    $nrecs     = dbquery ( @db,"dbRECORD_COUNT") ;

    foreach $row (0..$nrecs-1) {
       $db[3]     = $row ;
       $time      = dbgetv(@db, qw ( time )) ;
       if ( $time != -9999999999.99900 ) {
          $jdate     = &yearday ($time) ;
          if ($jdate != $jdates[$#jdates]) {
             push(@jdates,$jdate) ;
          }
       }
    }
    dbfree (@db);
    return ( @jdates ) ;
}


sub rm_data { # rm_data ( $rmjdate)
#  removes all waveforms starting on jdate
#  returns the number of bytes removed
#
    my ($rmjdate) = @_ ;
    my (@db)      = @dbwfdisc ;
    my ($nrecs, $row, $jdate, $dfile, $nbytes, $totbytes, $time, $endday) ;
    my (@dbday, @dbdfile,@db_row);
    my ($subset,$db_row,$cmd);

    print STDERR "rm_data \n"   if ($opt_v || $opt_V) ;

    $totbytes = 0 ;
    $nbytes   = 0 ;
    $nrecs    = dbquery ( @db,"dbRECORD_COUNT") ;

    print STDERR "	$nrecs wfdisc records\n"   if ($opt_v || $opt_V) ;

    $endday = yearday(epoch($rmjdate) + 86400.);
    $subset  = "time >= _ $rmjdate _ && time < _ $endday _";
    print STDERR "	$subset\n"   if ($opt_v || $opt_V) ;
    @dbday = dbsubset( @db,$subset);
    @dbdfile = dbsort(@dbday, "-u", "dir", "dfile");
    $nrecs   = dbquery ( @dbdfile,"dbRECORD_COUNT") ;
    print STDERR "	$nrecs unique dir and dfiles\n"   if ($opt_v || $opt_V) ;

# remove all data files for $rmjdate

    foreach $row (0..$nrecs-1) {
        $dbdfile[3]  = $row ;
        $dfile  = &dbextfile (@dbdfile) ;
        $nbytes = -s $dfile ;
        unless ( $opt_n || $opt_w ) {
            print STDERR "	unlink	$dfile \n"   if $opt_V ;
            if ( ! unlink($dfile) && ( -e $dfile)) {
                print STDERR "Could not delete $dfile \n" ;
            }
            &clean_dirs( &dir_name (@dbdfile)) ;
        } 
	$totbytes += $nbytes;
    }

# mark all wfdisc rows for $rmjdate

    $nrecs = dbquery ( @dbday,"dbRECORD_COUNT") ;
    $cmd = "dbsubset $rt_db.wfdisc \"$subset\" \| dbdelete -m - ";
    &run($cmd);

    print STDERR "	$nrecs recs in $rmjdate.wfdisc marked for deletion\n"   if ($opt_v || $opt_V) ;

    return ($totbytes) ;
}

sub clean_disk {
#
#  Global Variables
#	global_array	@jdates 
#
    my ($tbytes,$tmbytes);
    $tbytes   = 0;
    $tbytes   = &rm_data ( $jdates[0] ) ;
    $tmbytes += $tbytes/1000000 ;
    print STDERR "$jdates[0] removed \n";
    print MAILLOG "$jdates[0] removed -	", $tbytes/1000000, " mbytes\n";
    print STDERR "$tmbytes mbytes removed \n"   if ($opt_v || $opt_V) ;
    return ($tmbytes);
}

sub clean_dirs {  # clean_dirs ( dir_name ) 

    my ($dir_name) = @_ ;
    while (rmdir $dir_name) {
       print STDERR "removed directory - $dir_name \n"  if ($opt_v || $opt_V) ;
       if ( (rindex $dir_name, "/") >= 0 ) {
          $dir_name = substr ($dir_name, 0, (rindex $dir_name, "/")) ;
       }
    }
    return ( $dir_name ) ;
}

sub get_pars {
#
#  Global Variables
#	global_array	@clean_tables @$ref @mail_to 
#	global_scalar	$min_disk_free $Pf $max_days_db $max_days_clean_tables $min_days_clean_wfdisc 
#
    my ( $ref ) ; 

    $min_disk_free		= pfget ( $Pf, 'min_disk_free' ) ;
    $max_days_db		= pfget ( $Pf, 'max_days_db' ) ;
    $max_days_clean_tables	= pfget ( $Pf, 'max_days_clean_tables' ) ;
    $min_days_clean_wfdisc	= pfget ( $Pf, 'min_days_clean_wfdisc' ) ;

    $ref		= pfget ( $Pf, 'clean_tables' ) ;
    @clean_tables 	= @$ref ;

}

sub parameter_check {
#
#  Global Variables
#	global_scalar	$Pf $rt_db $orb $min_disk_free $max_days_db $max_days_clean_tables
#	global_array	@mail_to @clean_tables
#
    print STDERR "\nPFPATH  -  $ENV{PFPATH} \n\n";
    print STDERR  $Pf,            "	- parameter file \n"           ;
    print STDERR  $rt_db, "	- network database \n"       ;
    print STDERR  $orb, "	- orb \n"       ;
    print STDERR  "$min_disk_free mbytes, minimum free  \n"         ;
    print STDERR  "$max_days_db days, maximum number of wf \n"      ;
    print STDERR  "$max_days_clean_tables, maximum number of days of data in cleaned tables \n"      ;
    print STDERR  "$min_days_clean_wfdisc, minimum number of days before removing bad wfdisc rows \n"      ;
    print STDERR  "clean tables       @clean_tables \n"                 ;
}

sub good_exit {
    my ($t);
    $t = time() ;
    printf STDERR   "$prog_name  - completed  %s UTC\n\n", &strydtime($t) ;  
    printf MAILLOG  "$prog_name  - completed  %s UTC\n\n", &strydtime($t) ;  
    close MAILLOG ;
    unlink ($maillog) unless $opt_V;
    close LOCK ;
    unlink (".$prog_name") unless $opt_V;
    exit(0);
}


sub bad_exit {  # &bad_exit($line)
    my ($line) = @_ ;
    my ($cmd,$t);
    $t = time() ;

    print STDERR  "\n$line \n\n" ;
    printf STDERR   "%s  - error exit  %s UTC\n\n", $prog_name, &strydtime($t) ;  

    if ($maillog) {
        print MAILLOG "\n$line \n\n" ;

        print MAILLOG "Check errors in $LOG/$prog_name \n" ;
        printf MAILLOG   "%s  - error exit  %s UTC\n\n", $prog_name, &strydtime($t) ;  
        close MAILLOG ;
        $cmd = "rtmail -s \"PROBLEMS - $rt_db $host $prog_name \" $mail_to < $LOG/$prog_name" . "_mail" ;
    } else {
        open(MT,">tmp_mail");
        print MT "$line \n" ;
        close MT;
        $cmd = "rtmail -s \"PROBLEMS - $rt_db $host $prog_name\" $mail_to < tmp_mail" ;
    }
    if ($opt_m) {
        print STDERR  "$cmd \n" ;
        system ( $cmd ) ;
        if ($?) {
            print STDERR "$cmd error $? \n";
        }
    }
    unlink tmp_mail unless $opt_V;
 
    exit(1);
}

sub clean_rt_tables {

    my ($max_days_clean_tables) = $max_days_clean_tables ; 
    my (@dbin) = @dbin ; 
    my (@clean_tables) = @clean_tables;
    my (@db_table, @db_subset, @db_row);
    my ($subset, $table, $nrecs, $row, $nrows, $db_row);
    my ($midnight, $two_days, $number_days_ago, $schema);

    $midnight = ":00:00:00" ;

    $number_days_ago = &yearday(time() - ($max_days_clean_tables * 86400.)) ;
    $two_days       = &yearday(time() + (2 * 86400.)) ;
    
    $subset = "time < _" . $number_days_ago . $midnight . "_" ;

    if ($two_days >  1998001 ) {
        $subset = $subset . " || time > _" . $two_days . $midnight . "_" ;
    }

    print STDERR "clean_rt_tables	subset = $subset \n" if ($opt_v || $opt_V) ;

    push(@clean_tables);

    foreach $table (@clean_tables) {
        @db_table   = dblookup(@dbin,"",$table,"","") ;
        if ($db_table[1] < 0) {
            $schema   = dbquery (@dbin,"dbSCHEMA_NAME") ;
            print STDERR "clean_rt_tables: $table is not in schema $schema \n" if ($opt_v || $opt_V) ;
            next;
        }

        $row = 0;
        $nrows = dbquery ( @db_table,"dbRECORD_COUNT") - 200000;
        while ($row < $nrows) {
            $db_table[3]  = $row++ ;
            dbmark ( @db_table ) ; 
        }

        print STDERR "$table  - nrows  ",  dbquery ( @db_table,"dbRECORD_COUNT"),"  subset - $subset \n" if ($opt_v || $opt_V) ; 
        @db_subset  = dbsubset(@db_table, $subset) ;
        $nrecs = dbquery ( @db_subset,"dbRECORD_COUNT") ;
        foreach $row (0..$nrecs-1) {
            $db_subset[3] = $row ;
            $db_row       =  dbgetv ( @db_subset, $table ) ;
            @db_row       =  split ( ' ', $db_row ) ; 
            dbmark ( @db_row ) ; 
        }
        print STDERR "$nrecs records removed from  $table  \n" if ($opt_v || $opt_V);
        dbfree (@db_subset);
    }

}

sub clean_del_arr {
    my (@dbin) = @dbin ; 
    my (@db_arrival, @db_subset, @db_row);
    my ($subset, $nrecs, $row, $table, $db_row);

    $table  = "arrival";
    $subset = "iphase == \"del\"" ;

    print STDERR "clean_del_arr subset = $subset \n" if ($opt_v || $opt_V) ;
    @db_arrival   = dblookup(@dbin,"",$table,"","") ;
    @db_subset    = dbsubset(@db_arrival, $subset) ;

    $nrecs = dbquery ( @db_subset,"dbRECORD_COUNT") ;
    print STDERR "clean_del_arr nrecs $nrecs \n" if ($opt_v || $opt_V) ;
    foreach $row (0..$nrecs-1) {
        $db_subset[3] = $row ;
        $db_row       =  dbgetv ( @db_subset, $table ) ;
        @db_row       =  split ( ' ', $db_row ) ; 
        dbmark ( @db_row ) ; 
    }
    print STDERR "$nrecs \"del\" records removed from  $table  \n" if ($opt_v || $opt_V);

    dbfree  (@db_subset);
}

sub clean_nojoins {
    &nojoin("assoc",  "arrival");
    &nojoin("assoc",  "origin");
    &nojoin("origin", "assoc");
    &nojoin("origin", "event");
    &nojoin("event",  "origin");
    &nojoin("origerr","origin");
}

sub nojoin { # nojoin ( table1, table2 ) 
    my ($table1, $table2 ) = @_ ;
    my (@dbin) = @dbin ; 
    my (@db1,@db2,@db_nojoin,@db_row) ;
    my ($nrecs,$row,$db_row) ;

    print STDERR "nojoin	$table1	$table2 \n" if ($opt_v || $opt_V) ;

    @db1   = dblookup(@dbin,"",$table1,"","") ;
    @db2   = dblookup(@dbin,"",$table2,"","") ;

    unless (dbquery ( @db1,"dbRECORD_COUNT") ) {
         print STDERR "no records in $table1 for dbnojoin $table1 $table2 \n" if ($opt_v || $opt_V);
         return;
    }
    unless (dbquery ( @db2,"dbRECORD_COUNT")) {
         print STDERR "no records in $table2 for dbnojoin $table1 $table2 \n" if ($opt_v || $opt_V);
         return;
    }

    print STDERR "dbnojoin  $table1  $table2 \n" if ($opt_v || $opt_V) ;

    @db_nojoin   = dbnojoin(@db1, @db2);

    print STDERR "dbnojoin  completed $table1  $table2 \n" if ($opt_v || $opt_V) ;

    unless (dbquery ( @db_nojoin,"dbRECORD_COUNT")) {
       print STDERR "no records from dbnojoin $table1 $table2 \n" if ($opt_v || $opt_V);
       return ; 
    }
         
    print STDERR "dbquery db_nojoin completed \n" if ($opt_v || $opt_V) ;

    $nrecs = dbquery ( @db_nojoin,"dbRECORD_COUNT");
    print STDERR "$nrecs records from $table1 did not join with $table2 \n" if ($opt_v || $opt_V);

    foreach $row (0..$nrecs-1) {
        $db_nojoin[3] = $row ;
        $db_row       =  dbgetv ( @db_nojoin, $table1 ) ;
        @db_row       =  split ( ' ', $db_row ) ; 
        eval {dbmark ( @db_row ) ;} ;
        if ($@) {
            print STDERR "dbmark error $@ \n";
            print STDERR "db1	@db1	db2	@db2	db_nojoin	@db_nojoin \n";
            print STDERR "db_row	$db_row	@db_row \n";
        }
    }
    print STDERR "$nrecs records removed from  $table1  \n" if ($opt_v || $opt_V);
    dbfree  (@db_nojoin);
}


sub db_fixchanids {  
    my (@dbin) = @dbin ; 
    my (@dbsitechan, @dbarrival, @dbsensor, @match) ;
    my ($nrecs, $row, $time, $sta, $chan, $chanid, $lddate) ;

    @dbsitechan  = dblookup(@dbin,"","sitechan","","") ;
    @dbarrival   = dblookup(@dbin,"","arrival","","") ;
    @dbsensor    = dblookup(@dbin,"","sensor","","") ;

    if (dbquery ( @dbsitechan,"dbRECORD_COUNT")) {
        if (dbquery ( @dbarrival,"dbRECORD_COUNT")) {
            @dbarrival = dbnojoin(@dbarrival,@dbsitechan) ;
            $nrecs     = dbquery ( @dbarrival,"dbRECORD_COUNT");
            foreach $row (0..$nrecs-1) {
                $dbarrival[3] = $row;
                @match = dbmatches(@dbarrival, @dbsensor, "sensor", "sta", "chan", "time#time::endtime");
                if ($#match != -1) {
                    $dbsensor[3] = $match[0];
                    $chanid = dbgetv(@dbsensor,"chanid");
                    $lddate = dbgetv(@dbarrival,"lddate");
                    dbputv(@dbarrival,"chanid",$chanid,"lddate",$lddate);
                }
            }
        }
    } else {
        print STDERR "no records in sitechan to fix arrival chanids \n" if ($opt_v || $opt_V);
    }

    dbfree (@dbsitechan);
}

sub db_fixes {  
    my (@dbin) = @dbin ; 
    my (@dbwfdisc) = @dbwfdisc ; 
    my (@dbcalibration,@dbjoin,@dbarrival,@db_subset,@db_row) ;
    my ($row,$calib,$calper,$lddate) ;
    my ($subset,$db_row,$jdate,$midnight,$nrecs,$table) ;

    @dbcalibration   = dblookup(@dbin,"","calibration","","") ;
    if (dbquery ( @dbcalibration,"dbRECORD_COUNT")) {
        @dbjoin   = dbjoin(@dbwfdisc, @dbcalibration);

        $nrecs = dbquery ( @dbjoin,"dbRECORD_COUNT")    ;
        print STDERR "db_fixes:  $nrecs records in wfdisc-calibration join \n" if ($opt_v || $opt_V) ;
        foreach $row (0..$nrecs-1) {
            $dbjoin[3] = $row ;
            ($calib,$calper,$lddate)  = dbgetv(@dbjoin, qw (calibration.calib calibration.calper wfdisc.lddate)) ;
            dbputv (@dbjoin, 
                     "wfdisc.calib",       $calib,
                     "wfdisc.calper",      $calper,
                     "wfdisc.lddate",      $lddate ) ;
        }

        dbfree (@dbjoin);
    }  else {
        print STDERR "no records in calibration for dbjoin wfdisc calibration \n" if ($opt_v || $opt_V);
    }

#    $table  = "arrival";
#    @dbarrival   = dblookup(@dbin,"",$table,"","") ;
#    $subset = "deltim == 0.0" ;
#    @db_subset   = dbsubset(@dbarrival, $subset);
#    $nrecs = dbquery ( @db_subset,"dbRECORD_COUNT") ;
#    print STDERR "db_fixes:  $nrecs records in arrival with deltim = 0.0 \n" if ($opt_v || $opt_V) ;
#    foreach $row (0..$nrecs-1) {
#        $db_subset[3] = $row ;
#        $db_row       =  dbgetv ( @db_subset, $table ) ;
#        @db_row       =  split ( ' ', $db_row ) ;
#        $lddate       =  dbgetv(@db_row,qw(lddate));
#        dbputv (@db_row, "deltim", -1.0, "lddate", $lddate ) ;
#    }

    $nrecs = dbquery ( @dbwfdisc,"dbRECORD_COUNT")    ;
    foreach $row (0..$nrecs-1) {
        $dbwfdisc[3] = $row ;
        $wffile = dbextfile(@dbwfdisc) ;
        if (! -e $wffile) {
             print STDERR "waveform file $wffile does not exist! \n" ;
             print STDERR "  removing row from wfdisc \n\n"  if ($opt_v || $opt_V) ;
             dbmark(@dbwfdisc);
        }
    }
    
    $jdate = &yearday(time() - ($min_days_clean_wfdisc * 86400.));
    $midnight = ":00:00:00" ;
    $subset = "nsamp==0 && time< " . "_" . $jdate . $midnight . "_" ;
    $table = "wfdisc";
    @db_subset   = dbsubset(@dbwfdisc, $subset);
    $nrecs = dbquery ( @db_subset,"dbRECORD_COUNT") ;
    print STDERR "db_fixes:  $nrecs records in wfdisc with $subset\n" if ($opt_v || $opt_V) ;
    foreach $row (0..$nrecs-1) {
        $db_subset[3] = $row ;
        $db_row       =  dbgetv ( @db_subset, $table ) ;
        @db_row       =  split ( ' ', $db_row ) ; 
        dbmark ( @db_row ) ; 
    }

    $subset = "abs(endtime-time-(nsamp-1)/samprate)>.0005 && time< " . "_" . $jdate . $midnight . "_"  ;
    $table = "wfdisc";
    @db_subset   = dbsubset(@dbwfdisc, $subset);
    $nrecs = dbquery ( @db_subset,"dbRECORD_COUNT") ;
    print STDERR "db_fixes:  $nrecs records in wfdisc with $subset\n" if ($opt_v || $opt_V) ;
    foreach $row (0..$nrecs-1) {
        $db_subset[3] = $row ;
        $db_row       =  dbgetv ( @db_subset, $table ) ;
        @db_row       =  split ( ' ', $db_row ) ; 
        dbmark ( @db_row ) ; 
    }

    dbfree (@db_subset);
    dbfree (@dbcalibration);
}


sub run { 
    my ( $cmd ) = @_ ; 
    print STDERR "$cmd\n" if ($opt_v || $opt_V) ; 
    system ( $cmd ) if ! $opt_n ;
    if ($?) {
        &bad_exit("$cmd error $? ");
    }
}


sub print_header { 
    my ($rt_db) = $rt_db;
    my ($host,$pwd,$network_database,$t,$nw) ;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);
    my (@nw);

    chop ($host = `uname -n` ) ;
    chop ($pwd = `pwd` ) ;
    $network_database = $rt_db	 ;
    @nw = dbopen ( $network_database, "r" ) ; 
    @nw = dblookup ( @nw, "", "network", "", "" ) ;
    $nw = dbquery ( @nw, "dbRECORD_COUNT" ) ; 
    if ( $nw > 0 ) { 
	$nw[3] = 0 ;
	($nw) = dbgetv ( @nw, "netname" ) ; 
    } else { 
	$nw = "No network table in $network_database" ;
    }

    $t = time() ;
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($t) ; 

    printf MAILLOG "\n$nw\n" ;
    printf MAILLOG "$host:$pwd  database=$network_database\n" ;
    printf MAILLOG "\ncommand line:	$0 " ;
    printf MAILLOG "-v "  if $opt_v ;
    printf MAILLOG "-V "  if $opt_V ;
    printf MAILLOG "-n "  if $opt_n ;
    printf MAILLOG "-w "  if $opt_w ;
    printf MAILLOG "-m $opt_m "  if $opt_m ;
    printf MAILLOG "-p $opt_p "  if $opt_p ;
    printf MAILLOG "@ARGV\n" ;
    printf MAILLOG "version:	\$Revision: 1.28 $\ \$Date: 2006/04/09 00:54:48 $\  \n";
    printf MAILLOG "\nCurrent time:\n" ;
    printf MAILLOG "%s UTC\n", &strydtime($t) ;  
    printf MAILLOG "%2d/%02d/%04d (%03d) %2d:%02d:%02d.000 %s %s\n\n", 
	$mon+1, $mday, $year+1900, $yday+1, $hour, $min, $sec, $ENV{'TZ'}, $isdst ? "Daylight Savings Time" : "Standard Time" ;

    printf STDERR  "\n$nw\n" ;
    printf STDERR  "$host:$pwd  database=$network_database\n" ;
    printf STDERR  "\ncommand line:	$0 " ;
    printf STDERR  "-v "  if ($opt_v || $opt_V) ;
    printf STDERR  "-V "  if $opt_V ;
    printf STDERR  "-n "  if $opt_n ;
    printf STDERR  "-w "  if $opt_w ;
    printf STDERR  "-m $opt_m "  if $opt_m ;
    printf STDERR  "-p $opt_p "  if $opt_p ;
    printf STDERR  "@ARGV\n" ;
    printf STDERR  "version:	\$Revision: 1.28 $\ \$Date: 2006/04/09 00:54:48 $\  \n";
    printf STDERR  "\nCurrent time:\n" ;
    printf STDERR  "%s UTC\n", &strydtime($t) ;  
    printf STDERR  "%2d/%02d/%04d (%03d) %2d:%02d:%02d.000 %s %s\n\n", 
	$mon+1, $mday, $year+1900, $yday+1, $hour, $min, $sec, $ENV{'TZ'}, $isdst ? "Daylight Savings Time" : "Standard Time" ;
    
    dbclose @nw;
    return ($host);
}


sub crunch_time {
    my (@dbin) = @dbin ; 
    my (@crunch_tables);
    my ($table, $schema);
    my (@db_table) ;

    push(@crunch_tables, "wfdisc", "arrival", "assoc", "origin", "event", "origerr", "stamag", "netmag", "retransmit", "gap", "detection", "trigger");

    print STDERR "crunch_time \n" if ($opt_v || $opt_V) ;
    print STDERR " @crunch_tables \n " if ($opt_v || $opt_V) ;
    foreach $table (@crunch_tables) {
        @db_table   = dblookup(@dbin,"",$table,"","") ;
        if ($db_table[1] < 0) {
            $schema   = dbquery (@dbin,"dbSCHEMA_NAME") ;
            print STDERR "crunch_time: $table is not in schema $schema \n" if ($opt_v || $opt_V) ;
            next;
        }

        dbcrunch(@db_table);
        print STDERR "crunched $table  \n" if ($opt_v || $opt_V);
    }

}


sub check_db {  # check_db () 
    my (@dbin)  = @dbin;
    my ($rt_db) = $rt_db;
    my (@tables);
    my ($table, $test, $check, $recsize, $tabsize, $nrecs);


    @dbin     = dbopen  ( $rt_db, "r")                ;
    @tables   = dbquery ( @dbin,"dbSCHEMA_TABLES")  ;
    $test = 0;
    foreach $table (@tables) {
        @dbin     = dblookup( @dbin,"",$table,"","")     ;
        $nrecs    = dbquery ( @dbin,"dbRECORD_COUNT")  ;
        $recsize  = dbquery ( @dbin,"dbRECORD_SIZE")  ;
        $tabsize  = dbquery ( @dbin,"dbTABLE_SIZE")  ;
        $check    = $tabsize/$recsize ;
        unless ($nrecs == $check) {
             $test++;
             print STDERR "	Error in $rt_db table $table - expected records	$nrecs	found	$check\n";
             print MAILLOG "	Error in $rt_db table $table - expected records	$nrecs	found	$check\n";
        }
    }
    dbclose(@dbin);

    if ($test) {
         &bad_exit("\n	$rt_db has problems, run dbverify and dbcheck!");
    }

}


sub check_lock { # &check_lock($prog_name)
    my ($prog_name) = @_ ;
    my ($lockfile);

    print STDERR "check_lock ( $prog_name )\n"  if ($opt_v || $opt_V );
    $lockfile = ".$prog_name" ;
    open ( LOCK, ">$lockfile" ) ;
    if ( flock(LOCK, 6 ) != 1 ) {
        &bad_exit ( "Can't lock file '$lockfile'.\n\nIs $prog_name or another process which locks $prog_name already running?\n" ) ;
    }
    print LOCK "$$\n" ;
    return();
}

