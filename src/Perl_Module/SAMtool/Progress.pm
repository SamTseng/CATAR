#!/usr/bin/perl -s
package Progress;
# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

    Progress - report the progress of a time consuming program.

=head1 SYNOPSIS

    use Progress;
    if ($ARGV[0] eq 'percent') {
	$obj = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    } else {
	$obj = Progress->new( {'OUT'=>*STDOUT{IO},'Format'=>'line'} );
    }
    $TotalLine = 100;  # or $TotalLine = &getTotal();
    for($line=1; $line <= 100; $line++) {
	$percent = $obj->ShowProgress($line/$TotalLine, $percent);
    }
    $percent = $obj->ShowProgress($line/$TotalLine, $percent);

=head1 DESCRIPTION

  Given a ratio of completing some work, show the percentage before completion.
    
Author:
    Yuen-Hsien Tseng.  All rights reserved.
    
Date:
    2003/06/13

=head1 methods

=head2 new() : the constructor 

  $obj = $class->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );

  The attributes in the object can be set by an INI file (through attribute 
    'INI') or directly given in the constructor's argumnets in a 
    key=>value format. To know the attribute names, consult class.ini.

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in 
  		$class->new( { {'OUT'=>*STDERR{IO},'Format'=>'percent'}  );
 
  'OUT'=>*STDERR{IO} : output progress message to standard error.
  'OUT'=>*STDout{IO} : output progress message to standard output.
  'Format'=>'percent' : output progress message in percentage.
  'Format'=>'line' : output progress message in '.' and '+'.

=cut
sub new {
    my($class, $rpara) = @_;
    $class = ref($class) || $class; # ref() return a package name
    my $this = bless( {}, $class ); # same as  $this={}; bless $this, $class;
    my($k, $v);
    while (($k, $v) = each %$rpara) {
	$this->{$k} = $v;
    }
    return $this;
}


=head2 ShowProgress() : display progress message

  $p->ShowProgress($CurrentPercent, $PreviousPercent)

  Show $CurrentPercent if $CurrentPercent > $PreviousPercent.
  The attribute 'Format' will affect the progress message.
  if Format=>'percent', then percentage will be shown;
  if format=>'line',    then '.' and '+' will be shown;

=cut
sub ShowProgress {
    ($this, $p, $percent) = @_;
    if ($this->{'Format'} eq 'percent') {
    	$this->ShowProgressPercent($p, $percent);
    } else {
    	$this->ShowProgressLine($p, $percent);
    }
}

=head2 ShowProgressPercent() : display progress message in percent format

  $p->ShowProgressPercent($CurrentPercent, $PreviousPercent)

  Show $CurrentPercent in percentage if $CurrentPercent > $PreviousPercent.

=cut
sub ShowProgressPercent {
    my($this, $p, $percent) = @_;
    $p = int($p * 100);
#    print $fh $p, "%\n" if ($p > $percent);
    my $fh = $this->{'OUT'};
    print $fh $p, "%" if ($p > $percent);
#    print $fh "\n" if $p == 100;
    print $fh "\n" if $p == 100 and $percent < 100; # 2003/01/16
    return $p;
}

=head2 ShowProgressLine() : display progress message in '.' or '+'.

  $p->ShowProgressLine($CurrentPercent, $PreviousPercent)

  Show $CurrentPercent in '.' or '+' if $CurrentPercent > $PreviousPercent.

=cut
sub ShowProgressLine {
    my($this, $p, $percent) = @_; my($c);
    $p = int($p * 100);
    my $fh = $this->{'OUT'};
#    print $fh $p, "%" if ($p > $percent);
    if ($p > $percent) {
    	if ($p % 10 == 0) {
    	    $c = int($p / 10);
    	} elsif ($p % 5 == 0) { $c = "+"; } else { $c = "."; }
    	print $fh $c;
    }
#    print $fh "\n" if $p == 100;
    print $fh "\n" if $p == 100 and $percent < 100; # 2003/01/16
    return $p;
}


1;
