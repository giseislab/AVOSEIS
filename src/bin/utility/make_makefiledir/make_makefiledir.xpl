$PROGNAME = $ARGV[0];
$result2 = `grep \/usr\/bin\/perl/` unless ($result);
if ($result || $result2) {
	open(FIN, $PROGNAME);
	open(FOUT, ">$PROGNAME.xpl");
	while ($line=<FIN>) {
		next if ($line =~ /\/usr\/bin\/perl/);
		next if ($line =~ /ANTELOPE\/bin\/perl/);
		next if ($line =~ /ENV{ANTELOPE}\/data\/perl/);
	
		print FOUT "$line";
	}
	close(FOUT);
	close(FIN);
	system("mv $PROGNAME $PROGNAME.old");
	system("mkdir $PROGNAME");
	system("mv $PROGNAME.xpl $PROGNAME");

	open(FMAK, ">$PROGNAME/Makefile");
	print FMAK "BIN=$PROGNAME\n";
	if (-e "../../man/man1/$PROGNAME.1") {
		print FMAK "MAN1=$PROGNAME.1\n";
		system("mv ../../man/man1/$PROGNAME.1 $PROGNAME");
	}
	if (-e "../../data/pf/$PROGNAME.pf") {
		print FMAK "PF=$PROGNAME.pf\n";
		system("mv ../../data/pf/$PROGNAME.pf $PROGNAME");
	}
	print FMAK "DIRS=\n";
	print FMAK "include \$(AVOSEISMAKE)\n";
	close(FMAK);
} else {
	print "Not a perl program\n";
	system("mkdir other/");
	system("mv $PROGNAME other/");
}


