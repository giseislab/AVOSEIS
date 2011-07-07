
my $usage = <<"EOF";

USAGE

stringreplace oldpattern newpattern  infile  outfile

e.g.

stringreplace "_.." "   "  file.in  file.out

Patterns must be as you would normally use in a Perl regular expression

EOF

die($usage) unless ($#ARGV>=2);
$infile = $ARGV[2];
if ($#ARGV==2) {
	$outfile = $infile;
} else {
	$outfile = $ARGV[3];
};
$tmpfile = "$infile.tmp";
open(FIN,$infile) or die("Cannot open: $!\n");
open(FOUT,">$tmpfile") or die("Cannot write: $!\n");


my $oldpattern = $ARGV[0];
my $newpattern = $ARGV[1];
while (<FIN>) {
	s/$oldpattern/$newpattern/g;
	print FOUT;
}

system("mv $tmpfile $outfile");

