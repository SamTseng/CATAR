package SamOpt;

# Refer to http://perldoc.perl.org/Exporter.html for the details of the next 3 lines:
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(SamOpt);
$VERSION = '1.0';


=head1 NAME

Process command options for my own use.

=head1 SYNOPSIS

    use SAMtool::SamOpt;
    SamOpt();

In normal Perl script running, Perl takes care of the option handling.
    D:\demo\SAM>testpm.pl -OStem ladies
      ARGV=ladies
      ladies:lady
      End of Program: @ARGV=''

But after packaging by PAR::Parcker, we have to do our own option handling.
    D:\demo\SAM>pp -o testpm.exe testpm.pl
    D:\demo\SAM>testpm -OStem -Otest="1 2 3" ladies
      ARGV=-OStem -Otest=1 2 3 ladies
        (key, value)=(OStem, 1), ARGV=-OStem,-Otest=1 2 3,ladies
        ${OStem}=1, @EXPORT=$OStem
        (key, value)=(Otest, 1 2 3), ARGV=-Otest=1 2 3,ladies
        ${Otest}=1 2 3, @EXPORT=$OStem $Otest
      ladies:lady
      End of Program: @ARGV=''

So use this module like 
    use SamOpt;  &SamOpt();
immediately after the shebang line (i.e., 2nd line of your Perl script).

=cut


# For each switch found, sets $ox (where x is the switch name) to the value of the
# argument, or 1 if no argument.  
sub SamOpt {
    my ($key, $value);
    local $_;
    local @EXPORT;
    while (@ARGV) {
    	$key = $value = '';
    	if ($ARGV[0] =~ /^\-([^=]+)$/) {
	    $key = $1; $value = 1;
    	} elsif ($ARGV[0] =~ /^\-([^=]+)=(.+)/) {
	    $key = $1; $value = $2;
	} else { last; }
#print "(key, value)=($key, $value), ARGV=", join(',', @ARGV), "\n";
	${"$key"} = $value;
	push( @EXPORT, "\$$key" );
#print "\${$key}=", ${"$key"}, ", \@EXPORT=@EXPORT\n";
	shift(@ARGV);
    }
    local $Exporter::ExportLevel = 1;
    import SamOpt;
#    import SAMtool::SamOpt;
}

1;
