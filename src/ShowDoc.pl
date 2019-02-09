#!/usr/bin/perl -s
# Written on 2006/07/15 by Yuen-Hsien Tseng
    print "Content-type: text/html\n\n";
    &parse_form_data(*F);
    my ($f, $st) = ($F{'f'}, $F{'st'});

# For different database, change next lines
  if (0) {
    my $dsn = 'UPC977';
    my $sql = "SELECT FullText FROM TFullText where PatentNo='$f'";
    print &GetDocument_in_DBMS($f, $sql, $dsn);
  } else {
    &PrintDoc($f);
  }
    exit;

# Given $f
sub PrintDoc {
    my($f) = @_;
    open F, $f or die "Cannot read file:'$f'";
    local $/; undef $/; $text = <F>; close(F); 
    $text =~ s/\n/<p>\n/g;
    print $text;
    return;
    my($key, $title, $content);
    $text = &InsertP($text);
# Output the result
    print <<OUT;
<HTML><head><title>$f</title></head><body>
$f : $title<HR>$content
</body></html>
OUT
}

sub GetDocument_in_DBMS {
    my($pk, $sql, $dsn) = @_; my($DBH, $STH);
    use DBI;
    $DBH = DBI->connect( "DBI:ODBC:$dsn",,, { # use -Odsn=File_NSC
      RaiseError => 1, AutoCommit => 0
     }) or die "Can't make database connection: $DBI::errstr\n";
    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
    $DBH->{LongTruncOk} = 1;
    $STH = $DBH->prepare($sql)
           or die "Can't prepare SQL statement: SQL=$sql, $DBI::errstr\n";
    $STH->execute()
           or die "Can't run SQL statement: SQL=$sql, $DBI::errstr\n";
    return $STH->fetchrow_array;
}

# Insert <P> at proper position. 
# If current line is shorter than the previous line by 3/4, then regard
# next  line as the beginning of a paragraph.
sub InsertP { # Given $file, return $file with <P> inserted at correct position
    my($file) = @_;
    my($len, $i, $lent, $j, @Lines);
    @Lines = split /\r?\n/, $file; # splitted by line break
    $len = 0;
    for ($i=0; $i<@Lines; $i++) {
	$Lines[$i] =~ s/ +$//;
	$lent = length($Lines[$i]);
	if ($lent < 3 * $len / 4) { 
	    $j = $i+1; $Lines[$j] = "<P>" . $Lines[$j] if $j<@Lines; 
	}
	$len = $lent;
#$Lines[$i] .= " : $lent\n";
    }
    return join "\n", @Lines;
} # End of &InsertP()


# The following codes for decoding URL-encoded data are adopted 
#   from "CGI Programming on the World Wide Web" authored by 
#   Shishir Gundavaram on pp.64-67, 1996.
#
sub parse_form_data {
  local (*FORM_DATA) = @_;
  my ( $request_method, $query_string, @key_value_pairs,
	  $key_value, $key, $value);

  $request_method = $ENV{'REQUEST_METHOD'};
  if ($request_method eq "GET") {
     $query_string = $ENV{'QUERY_STRING'};
  } elsif ($request_method eq "POST") {
     read (STDIN, $query_string, $ENV{'CONTENT_LENGTH'});
  } else {
     &return_error (500, "Server Error", 
			"Server uses unsupported method");
  }
  
  @key_value_pairs = split(/&/, $query_string);
  foreach $key_value (@key_value_pairs) {
     ($key, $value) = split (/=/, $key_value);
     $value =~ tr/+/ /;
     $value =~ s/%([\dA-Fa-f][\dA-Fa-f])/pack ("C", hex($1))/eg; 
     if (defined($FORM_DATA{$key})) {
        $FORM_DATA{$key} = join ("\0",$FORM_DATA{$key}, $value);
     } else {
        $FORM_DATA{$key} = $value;
     }
  }
}

sub return_error
{
  my ($status, $keyword, $message) = @_;
  my $webmaster = 'samtseng@ntnu.edu.tw';
  print "Content-type: text/html", "\n";
  print "Status: ", $status, " ", $keyword, "\n\n";
  print <<End_of_Error;

<title>CGI Program - Unexpected Error</title>
<h1>$keyword</h1>
<hr>$message</hr>
Please Contact $webmaster for more information.

End_of_Error
 
  exit(1);
}

1;

