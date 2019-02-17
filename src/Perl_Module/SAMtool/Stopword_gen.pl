#!/usr/bin/perl -s
# C:\Perl\site\lib\SAMtool>perl -s Stopword_gen.pl ..\SAM\word >SetStopHash.txt
    use Stopword;
    $Stop = Stopword->new( { 'WordDir'=> "$ARGV[0]" } );
    exit;

package Stopword;
#    use strict; use vars;
# Note: These are package variables, not object variables, use them carefully.
    %ESW = ();	# English stop words
    %CSW =();	# Chinese stop words 
    %Emark = ();	# English punctuation marks
    %Cmark =();	# Chinese punctuation marks ¼ÐÂI²Å¸¹
    %StopHead = ();	# Chinese stop head
    %StopTail = ();	# Chinese stop tail 

=head1 Methods

=head2 new() : the constructor

  $Stop = Stopword->new( {'Attribute_Name'=>'Attribute_Value', ... } );

  The constructor of this class. Attributes that must be given are:
		'WordDir' => 'word',
  Next attributes should be given if the above is not given.
                'StopHead' => 'stophead.txt',
                'StopTail' => 'stoptail.txt',
                'StopWord_Chi' => 'stopword-chi.txt',
                'StopWord_Eng' => 'stopword-eng.txt',
                'Punch_Marks'  => 'stopmark.txt'

=cut
sub new {
    my($class, $rpara) = @_; 
    $class = ref($class) || $class; # ref() return a package name
    my $self = bless( {}, $class ); # same as  $self={}; bless $self, $class;
#print "in &new(): ref(\$rpara)='", ref($rpara), "'\n";
    $self->Init($rpara) if ref($rpara);
    return $self;
}

=head2 Init() : the initialization method

  $Stop->Init(); 

  Initialize some variables in this package by reading some files 
  given in new().

  If the variables are set in &new(), you don't need to call this method.

  If in &new(), you set no variables, you should call this method
  to set the variables.

  Or even if in &new() you have already set some variables, you can still 
  redefine these variables by calling this method with arguments, like this:
    $Stop->Init( { 'WordDir' => 'My_Stop' } );
  or
    $Stop->Init( {
                'StopHead' => 'My_Stop/stophead.txt',
                'StopTail' => 'My_Stop/stoptail.txt',
                'StopWord_Chi' => 'My_Stop/stopword-chi.txt',
                'StopWord_Eng' => 'My_Stop/stopword-eng.txt',
                'Punch_Marks'  => 'My_Stop/stopmark.txt'
    } );

=cut

sub Init {
    my($pkg, $rpara) = @_; my($k, $v, $dir);
#print "in &Init(): ref(\$rpara)='", ref($rpara), "'\n";
    if (ref($rpara)) {
	while (($k, $v) = each %$rpara) { $pkg->{$k} = $v; }
    }
#print "INC=@INC, WordDir=$pkg->{'WordDir'}, StopHead='$pkg->{'StopHead'}'\n";
    if (not -d $pkg->{'WordDir'} and not defined $pkg->{'StopHead'}) {
	foreach $dir (@INC) { 
	    if (-d $dir . '/'. $pkg->{'WordDir'}) {
		$pkg->{'WordDir'} = $dir . '/'. $pkg->{'WordDir'};
		last;
	    } 
	}
    }
    if (not defined $pkg->{'StopHead'}) {
	$pkg->{'StopHead'} = $pkg->{'WordDir'} . '/stophead.txt',
	$pkg->{'StopTail'} = $pkg->{'WordDir'} . '/stoptail.txt',
	$pkg->{'StopWord_Chi'} = $pkg->{'WordDir'} . '/stopword-chi.txt',
	$pkg->{'StopWord_Eng'} = $pkg->{'WordDir'} . '/stopword-eng.txt',
	$pkg->{'Punch_Marks'}  = $pkg->{'WordDir'} . '/stopmark.txt'
    }
#print "INC=@INC, WordDir=$pkg->{'WordDir'}, StopHead='$pkg->{'StopHead'}'\n";


    my $str ='
sub SetStopHash {
    local $/; $/ = "\n\n";  my($a, @A);
    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $StopHead{$a} = 1; }
    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $StopTail{$a} = 1; }
    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $Emark{$a} = 1; }
    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $Cmark{$a} = 1; }
    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $ESW{$a} = 1; }
    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $CSW{$a} = 1; }
}
1;
__DATA__
';
    print $str;
    &ReadStopChar($pkg->{'StopHead'}, \%StopHead);
    &PrintHash(\%StopHead, '%StopHead');
    &ReadStopChar($pkg->{'StopTail'}, \%StopTail);
    &PrintHash(\%StopTail, '%StopTail');
    &Read_Punch_Marks($pkg->{'Punch_Marks'}, \%Emark, \%Cmark);
    &PrintHash(\%Emark, '%Emark');
    &PrintHash(\%Cmark, '%Cmark');
    &Read_Eng_StopList($pkg->{'StopWord_Eng'}, \%ESW);
    &PrintHash(\%ESW, '%ESW');
    &ReadStopWord($pkg->{'StopWord_Chi'}, \%CSW);
    &PrintHash(\%CSW, '%CSW');
}

sub PrintHash {
    my($rH, $name) = @_; my($i, $a, @A);
    @A = sort keys %$rH;
    foreach $a (@A) {
    	$i++; print "$a\t";
    	print "\n" if $i%8==0;
    }
    if ($i%8==0) { print "\n"; } else { print "\n\n"; }
}

#private
sub ReadStopChar {
    my($file, $rChar) = @_;     my($a, @A);    
    local $/ = "\n";
    open(F, "$file") || die "Cannot open file:'$file' in &ReadStopChar()";
    while (<F>) { 
    	next if /^#/; # Escape Comment lines
    	@A = split ' ', $_;
    	foreach $a (@A) {
    	    $a =~ s/(^\s+|\s+$)//g;
    	    next if $a eq '';
    	    $rChar->{$a} = 1;
    	}
    }
    close(F);
}

# private
sub ReadStopWord {
    my($file, $rCSW) = @_;    
    local $/ = "\n";
    open(F, "$file") || die "Cannot open file:'$file' in &ReadStopWord()";
    while (<F>) { 
    	next if /(^#|^\s+$)/; # Escape Comment lines
    	chomp; 
    	$rCSW->{$_} = 1; # word should be separated by a space
    }
    close(F);
}

# private
sub Read_Eng_StopList {
    my($eng_list, $rESW) = @_;    my($w, @SList);
    local $/ = "\n";
    open(F, "$eng_list") 
	|| die("cannot open file:'$eng_list' in &Read_Eng_StopList()");
    while (<F>) { 
    	next if /^#/;   
    	chomp;  
    	@SList = split ' ', $_;
    	foreach $w (@SList) {
	    $rESW->{lc $w} = 1; 
    	}
    }
    close(F);
}


# Set global var: %Emark and %Cmark
sub Read_Punch_Marks {
    my($PunchMarks, $rEmark, $rCmark) = @_;   my($c, $Emarks, $Cmarks) = ();
    local $/;  undef($/);
    open(F, "$PunchMarks") 
	|| die("cannot open file:'$PunchMarks' in &Read_Punch_Marks()");
    $c = <F>;  close(F);
    if ($c =~ /^<English>((.|\n|\r)+)<\/English>/m) { $Emarks = $1; }
    if ($c =~ /^<Chinese>((.|\n|\r)+)<\/Chinese>/m) { $Cmarks = $1; }
    foreach $c (split ' ', $Emarks) { $rEmark->{$c} = 1; }
    foreach $c (split ' ', $Cmarks) { $rCmark->{$c} = 1; }
}


1;
 