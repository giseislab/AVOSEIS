# Write an index.html file in the current directory that lists all the 
# contents of directrory.


#USAGE
$Usage = "Usage: htmldir\n\nSee man page for description.";


if ( $#ARGV != -1 ) {
        die ( "$Usage" );
} 

$outfile = "index.html";
$indir = '.';


# WRITE HTML HEADER
open(OUT,">$outfile");
print OUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"> \n";
print OUT "<html>\n\t<head>\n\t\t<title>Unknown</title>\n\t</head>\n\t<body>\n";


opendir(DIR,$indir); 
my $count = 0;
while (my $file = readdir(DIR)) {
  $count++;
    print "$file ...\n";
    if (-d "$indir/$file") {
      print OUT "\t\t<a href=\"$file\">$file</a> (directory)<br>\n";
    } else {
      print OUT "\t\t<a href=\"$file\">$file</a><br>\n";
  }
}
closedir(DIR);
# print "No. of files processed: $count\n";


# WRITE FOOTER
print OUT "\t</body>\n</html>\n";
close(OUT);
