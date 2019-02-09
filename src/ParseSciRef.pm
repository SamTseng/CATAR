#!/usr/bin/perl -s
package ParseSciRef;

    use strict;    use vars;

=head1 NAME

ParseSciRef -- A class to parse scientific paper citation from 
   the "Other References" in a U.S. patent document.

=head1 SYNOPSIS

    use ParseSciRef;
    $SciRef = ParseSciRef->new( );
    $rSciRef = $SciRef->ParseSciRef( $cite_string );
    print "Type\tYear\tVol\tStartPage\tAuthor\tJouTitle\tPubTitle\n";
    print join("\t, @$rSciRef), "\n";
    exit;

Author:

    Yuen-Hsien Tseng.  All rights reserved.

Date:

    2006/06/16

=cut


=head2 Methods

=cut

=head2 new( { 'Patent_INI'=>'Patent.ini' }  )

  Constructor of the class. return a reference to a no-name hash.

=cut
sub new {
    my($class) = @_;
    $class = ref($class) || $class; # ref() return a package name
    my $me = bless( {}, $class ); # same as  $me={}; bless $me, $class;
    return $me;
}

=head2 $rSciRef = $SciRef->ParseSciRef( $citation_string );

 Given a Scientific citation extracted from the "Other References" in 
   a U.S. patent document, classify the citation format and then parse the
   citation into fields: Type, Year, Vol, StartPage, Author, PubTitle, JouTitle.
 Type is only for internal use. if you do not know the type, just ignore it.
 Return a reference to an array containing the following fields:
   (Type, Year, Vol, StartPage, Author, PubTitle, JouTitle)

=cut
sub ParseSciRef {
    my($me, $c) = @_;  my($BQ, $BN);
    if ($c =~ /".+"/) { # match a quotation mark
	$BQ = $`; # copy the string from the begining upto the match point
	if ($BQ =~ /^\s*\w\./) { # start with abbrev. middle name
	    if ($BQ=~/\d/) { # J. Journal Title, vol, [Authors] "Publication Title" [Authors]
		&ParseSciCite_0($c);
	    } else { # i.e., Y.H. Tseng, "Publicatio Title", 
		&ParseSciCite_1($c);
	    }
	} else { # Quation mark, but not begin with abbrev. middle name
	    if ($BQ =~ /\bet\.? al\b/ or $BQ =~ /\b[A-Z]\./) { 
	    # any et al? or abbrev. middle name
		if ($BQ=~/\d/) { # Journal Title, vol, Authors "Publication Title"
		    &ParseSciCite_2($c);
		} else { # i.e., Tseng Y., Yu et al, [(Year)] "Publication Title", 
		    &ParseSciCite_3($c);
		}
	    } else { # no et al and no abbrev. middle name
		if ($BQ =~ /\d/) { # Journal Title, Vol_Info, "Publicatoin Title" [Author], More_Info
		    &ParseSciCite_4($c);
		} else { # [Author] "Publication Title" info.
		    &ParseSciCite_5($c);
		}
	    }
	}
    } else { # when there is no quotation mark
	if ($c =~ /^\s*\w\./) { # Authors, [Publication Title], Journal Title, info
	    &ParseSciCite_6($c);
	} else { # not begin with abbrev. middle name
	    if ($c =~ /\(\d\d\d\d\)\.?/) { 
		&ParseSciCite_APA($c); # Author (year). Title, Journal, vol info
	    } elsif ($c =~ /\bet\.? al\b/ or $c =~ /\b[A-Z]\./) { # contain et al
		$BN = $`;
		if ($BN=~/\d/) { # Journal Title, vol info, Authors, Publication Title
		    &ParseSciCite_7($c);
		} else { 
		    if ($BN =~ /\b(of|from|for|using|in|and)\b/i) {
			&ParseSciCite_8($c);
		    } else {
			&ParseSciCite_9($c);
		   }
		}
	    } else { # no et al and no abbrev. middle name
		&ParseSciCite_10($c);
	    }
	}    	
    }
} # End of &ParseSciRef();


# Type 0=> (Jounal_Title_1, Vol_Info, [Authors], "Publication_Titile", [Authors], [More_Info])
# ex: J. Phys. Chem., vol. 59, pp. 1153-1155, Nov. 1955, L. J. E. Hofer, et al., "Structure Of The Carbon Deposited From Carbon Monoxide On Iron, Cobalt And Nickel".
sub ParseSciCite_0 {
    my($c) = @_;  my($i, @Seg);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    if ($c =~ /"([^"]+),?"/) 
    { $PubTitle = $1; $c = $` .', '. $'; $PubTitle=~s/,$//; }
    @Seg = split /, ?/, $c;
    $JouTitle = $Seg[0]; # Special simple JouTitle rule
# Special JouTitle rule
    if ($JouTitle =~ / (vol\. \d+)/) { $JouTitle = $`; unshift @Seg, $1; }
    for($i=1; $i<@Seg; $i++) { # scan from the 2nd part
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol=$1 if $Vol eq "" and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 6. Simple Author rule 1
	if ($Author eq "" and $Seg[$i]=~/\b[A-Z]\. ?([A-Z]\w+)/) { $Author=$1; next; }
# 7. Simple Author rule 2
	if ($Author eq "" and $Seg[$i]=~/\b(\w\w+),? et al/) { $Author=$1; next; }
    }
    my @r = (0, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
# 準確率：除了 Vol 有一個沒擷取到之外，其餘都正確。
# 6280697	J. Am. Chem. Soc., 1992, 114, "Electrochemical Intercalation of Lithium into Solid C.sub.60 ", Yves Chabre et al., pp. 764-766.
# 1992		764	Chabre	J. Am. Chem. Soc.	Electrochemical Intercalation of Lithium into Solid C.sub.60 
}

#   1 =>105 (Authors_1, "Publication_Title", Journal_Title, Vol_Info)
#	    S. Iijima, "Helical Microtubules of Graphitic Carbon," Nature, vol. 354, pp. 56-58 (1991).
sub ParseSciCite_1 {
    my($c) = @_;  my($i, @Seg, $au);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    if ($c =~ /"([^"]+),?"/) 
    { $PubTitle = $1; $au=$`; $c = $'; $PubTitle=~s/,$//; }
# Simple Author rule 1
    if ($au=~/\b[A-Z]\. ?([A-Z]\w+)/) { $Author=$1; }
# Simple Author rule 2
    if ($Author eq "" and $au=~/\b(\w\w+),? et al/) { $Author=$1; }
    @Seg = split /, ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# If JouTitle is not separated with Vol_Info with a comma 
	if ($JouTitle eq '' and $Seg[$i] =~ / vol\. \d+/) { 
	    $JouTitle = $`; $JouTitle=~s/^\s*|\s*$//g; } # delete spaces
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol=$1 if $Vol eq "" and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	{ $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
    }
    my @r = (1, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}

#   2 =>38  (Journal_Title, Vol_Info, Authors, "Publication_Title", [More_Info])
#	    Appl. Phys. Lett. 69(27) 30 Dec. 1996 Yamamoto et al "New method carbon nanotube growth by ion beam indication", pp. 4174-4175.
# 	or  (Authors, Jounal_Title, Vol_Info, "Publication_Title", [More_Info])
sub ParseSciCite_2 {
    my($c) = @_;  my($i, @Seg, $JoAu, $r);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    if ($c =~ /"([^"]+),?"/) 
    { $PubTitle = $1; $c = $` .', '. $'; $PubTitle=~s/,$//; }
    $JoAu = 1; # Journal Title is before Author
    if ($c =~ /\d/) { if ($` =~ /et al|\b[A-Z]\./) { $JoAu = 0; } }
    @Seg = split /, ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol=$1 if $Vol eq "" and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
	if ($JoAu) { # JouTitle is before Author, so match JouTitle first
# 8. Simple JouTitle rule
	    if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	    { $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
# 6. Simple Author rule 1
	    if ($Author eq "" and $Seg[$i]=~/\b[A-Z]\. ([A-Z]\w+)/) { $Author=$1; next; }
# 7. Simple Author rule 2
	    if ($Author eq "" and $Seg[$i]=~/\b(\w\w+),? et al/) { $Author=$1; next; }
	} else { # Author is before JouTitle, so match Author first
# 7'. Special Author rule 2
	    if ($Author eq "" and (($i<@Seg-1 and $Seg[$i+1]=~/et al/)
	    			   or $Seg[$i]=~/et al/)) { 
	    	($Author, $r) = split ' ', $Seg[$i]; next; 
	    }
# Special Vol rule and StartPage rule for "Int J Biol Macromol 23:7-10"
	    if ($Vol eq '' # and $StartPage eq '' and $JouTitle eq ''
	        and $Seg[$i] =~ / (\d+):(\d+)-\d+/) {
	        $Vol = $1; $StartPage = $2;
	        $JouTitle = $`; # Special JouTitle rule
	        $JouTitle =~ s/^\s*|\s*$//g;
	    }
	}
    }
    my @r = (2, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}


#   3 =>356 ([Journal_Title], Authors, "Publication_Title", Journal_Title, Vol_Info)
#	    Ajayan et al, "Opening carbon nanotubes with oxygen and implications for filling", Nature, vol. 362, Apr. 8, 1993, pp. 522-525.
#	    Ren, Z.F., "Synthesis of Large Arrays of Well-Aligned Carbon Nanotubes on Glass," Science, vol. 282, 1105-1107 (Nov. 6, 1998). 
sub ParseSciCite_3 {
    my($c) = @_;  my($i, @Seg, $au, $jo);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    if ($c =~ /"([^"]+),?"/) 
    { $PubTitle = $1; $au=$`; $c = $'; $PubTitle=~s/,$//; }
# Simple Author rule 1
    if ($Author eq '' and $au=~/\b[A-Z]\. ?([A-Z]\w+)/) { $Author=$1; }
# Simple Author rule 2
    if ($Author eq "" and $au=~/\b(\w\w+),? et al/) { $Author=$1; }
# Simple Author rule 3
    if ($Author eq '' and $au=~/\b([A-Z]\w+), [A-Z]\./) { $Author=$1; }
# Special Author rule for : "Smalley, Richard E.,"
    if ($Author eq '' and $au=~/\b([A-Z]\w+), \w+( |\-)[A-Z]\.(,| et al)/) { $Author=$1; }
    @Seg = split /, ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# Special JouTitle rule and Vol rule for "Nature vol. 356"
	if ($JouTitle eq '' and $Vol eq "" and 
	    $Seg[$i] =~ /(.+) vol\.?\s*(\d+)/i) { $JouTitle=$1; $Vol = $2; next; }
# Special JouTitle rule and Vol rule for "Appl. Phys. Lett. 62 (16)" or "Jpn. Appl. Phys. 32 (Jan. 1993)"
	if ($JouTitle eq '' and $Vol eq "" and 
	    $Seg[$i] =~ /(.+) (\d+) \(/i) { $JouTitle=$1; $Vol = $2; }
# Special Vol rule and StartPage rule for "Letters to Nature, 384:147-150"
	if ($Vol eq '' and $StartPage eq '' and $Seg[$i] =~ /(\d+):(\d+)-\d+/) 
	    { $Vol = $1; $StartPage = $2; next; }
# Special StartPage rule for: "Solid State Communications 86, 607-612 (1993)"
	if ($StartPage eq '' and $i>0 and $Seg[$i-1] =~ /\d$/
	    and $Seg[$i] =~ /(\d+)-\d+/)
	    { $StartPage = $1; }
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol=$1 if $Vol eq "" and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No), e.g. match those "12 (6)"
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	{ $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
    }
    my @r = (3, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}

#   4 =>33  (Journal_Title, Vol_Info, [Authors], "Publication_Title", [Authors], [More_Info])
#	    Nature, vol. 367, 10 Feb. 1994, p. 519, "Purification of Nanotubes".
# But not as Type 2, the authors have no 'et al' or abbrev. middle name
# Also, the Journal_Title seems to appear before the Author
sub ParseSciCite_4 {
    my($c) = @_;  my($i, @Seg, $JouTitleEnd);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    if ($c =~ /"([^"]+),?"/) 
    { $PubTitle = $1; $c = $` .', '. $'; $PubTitle=~s/,$//; }
    @Seg = split /, ?/, $c;
    $JouTitleEnd = 0;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# Special JouTitle rule 
	if ($Seg[$i] =~ /\d/) { $JouTitleEnd = 1; }
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol=$1 if $Vol eq "" and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# Assume JouTitle is before Author, so match JouTitle first
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $JouTitleEnd==0 and $Seg[$i]!~/\d/) 
	    { $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g; next; }
# Simple Author rule 1 and rule 2 are no longer valid here
# Simple Author rule 4:
	if ($Author eq "" and $Seg[$i]!~/\d/) {
# Simple Author rule 1
	    if ($Author eq '' and $Seg[$i]=~/\b[A-Z]\. ?([A-Z]\w+)/) { $Author=$1; }
# Simple Author rule 2
	    if ($Author eq "" and $Seg[$i]=~/\b(\w\w+),? et al/) { $Author=$1; }
# Simple Author rule 3
	    if ($Author eq '' and $Seg[$i]=~/\b([A-Z]\w+), [A-Z]\./) { $Author=$1; }
	    if ($Author eq '') 
		{ $Author=$Seg[$i]; $Author=~s/^\s*\.?|\s*$//g; next; }
	 }
    }
    my @r = (4, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}

#   5 =>55  (Authors_0, "Publication_Title", Journal_Title, Vol_Info)
#	    Iijima, "Helical microtubules of graphitic carbon", Nature, vol. 354, Nov. 7, 1991.
# Author seems to appear before JouTitle
sub ParseSciCite_5 {
    my($c) = @_;  my($i, @Seg, $au);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    if ($c =~ /"([^"]+),?"/) 
    { $PubTitle = $1; $au=$`; $c = $'; $PubTitle=~s/,$//; }
# Simple Author rule 5
    if ($au=~/\b([A-Z]\w+)[,;]/) { 
    	$Author=$1; # next line is for incorrect extraction
    	if ($Author =~ /unknown|Techno|corporat|Institute|News/i) 
    	{ $Author = ""; }
    }
    @Seg = split /, ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol = $1 if $Vol eq '' and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# Special Vol rule and StartPage rule for "Int J Biol Macromol 23:7-10"
	if ($Vol eq '' # and $StartPage eq '' and $JouTitle eq ''
	        and $Seg[$i] =~ / (\d+):(\d+)-\d+/) {
	    $Vol = $1; $StartPage = $2;
	    $JouTitle = $`; # Special JouTitle rule
	    $JouTitle =~ s/^\s*|\s*$//g;
	}
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	    { $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g; next; }
    }
    my @r = (5, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}


#   6 =>34  (Authors_1, [Publication_Title], Journal_Title, Vol_Info)
# 	Y. Saito et al., Bamboo-Shaped Carbon Tube Filled Partially with Nickel, Journal of Crystal Growth, 134, 154-156, 1993 (Nov. 1993).
#	E.L.M. Hamilton, et al, Science, 260:659, 1993.
sub ParseSciCite_6 {
    my($c) = @_;  my($i, @Seg, $au);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
# Specia rule 2 for Vol, StartPage, Year, and JouTitle
    if ($c =~ /([^,]+),? (\d+): ?(\d+).+((19|20)\d\d)/) {
    	$Vol = $2; $StartPage = $3; $Year = $4;
    	$JouTitle = $1; $JouTitle =~ s/^\s*|\s*$//g;
    }
    if ($c =~ /(et al\.?,)\s*/) { # get the author part
    	$au = $` . $1; # recombine into the author part for later extractoin
    	($PubTitle, $c) = split /, ?/, $', 2; # try to get PubTitle
    } else { # there is no 'et al', try abbrev. middle name
        @Seg = split /, ?/, $c;
        for($i=0; $i<@Seg; $i++) {# find the last author of the author part
            if ($Seg[$i]=~/\b[A-Z]\./) {} else { last; }
        }
        $au = join ", ", @Seg[0..($i-1)]; # put back the author part
        $PubTitle = $Seg[$i]; # "J. Appl. Phys., 47" can cause error
        $c = join ", ", @Seg[($i+1)..$#Seg];
        if ($PubTitle =~ /^\d+$/) # compensate the error here
	    { $c = join ", ", @Seg[($i-1)..$#Seg]; $PubTitle = ""; }
	if ($Seg[$i+1] =~ /^\d+$/) # compensate the error of having PubTitle
	    { $c = join ", ", @Seg[($i)..$#Seg]; $PubTitle = ""; }
    }
    # not a PubTitle, put back the string
    if ($PubTitle !~ /.\s./ or $PubTitle =~ /\d+$/) 
    	{ $c = $PubTitle . ', '. $c; $PubTitle = ""; }
# Simple Author rule 1
    if ($au=~/\b[A-Z]\. ?([A-Z]\w+)/) { $Author=$1; }
# Below fit for the case where the Author part and the PubTitle have been extracted, 
# leaving only the JouTitle and Vol info
# Specia rule 1 for Vol, StartPage, Year, and JouTitle
    if ($c =~ /([^,]+),? (\d+), L?(\d+)(\-\d+)?.+((19|20)\d\d)/) {
# for the case: Saito et al., Jpn. J. Appl. Phys., vol. 36, L1340 (1997).
# for the case: DeHeer et al., Science, vol. 270, 1179 (1995).
    	$Vol = $2; $StartPage = $3; $Year = $5;
    	$JouTitle = $1; $JouTitle =~ s/^\s*|\s*$//g;
    	if ($JouTitle =~ /vol\./) { $JouTitle = ''; }
    }
    @Seg = split /, ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# If JouTitle is not separated with Vol_Info with a comma 
	if ($JouTitle eq '' and $Seg[$i] =~ / vol\. \d+/) { 
	    $JouTitle = $`; $JouTitle=~s/^\s*|\s*$//g; } # delete spaces
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol = $1 if $Vol eq '' and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	{ $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
    }
    my @r = (6, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}


sub ParseSciCite_7 { # not need to extract anything
    my($c) = @_;  
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    my @r = (7, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}


#   8 =>8篇 (Publication_Title, Authors, Journal_Title, Vol_Info)
#	    Applications of Graphite Intercalation Compounds; M. Inagaki Journal of Material Research; vol 4, No. 6, Nov./Dec. 1989; pp. 1560-1568.
sub ParseSciCite_8 {
    my($c) = @_;  my($i, @Seg, $au);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
    ($PubTitle, $c) = split /[,;] /, $c, 2;
    if ($c =~ /(et al\.?,?)\s*/) { # get the author part, note the '?' in regexp
    	$au = $` . $1; # recombine into the author part for later extractoin
    	($PubTitle, $c) = split /[,;] ?/, $', 2; # try to get PubTitle
    } else {
    	($au, $c) = split /[,;] ?/, $c, 2; # try to get PubTitle
    }
# Simple Author rule 1
    if ($Author eq '' and $au=~/\b[A-Z]\. ?([A-Z]\w+)/) { $Author=$1; }
# Simple Author rule 2
    if ($Author eq "" and $au=~/\b(\w\w+),? et al/) { $Author=$1; }
    @Seg = split /[,;] ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# If JouTitle is not separated with Vol_Info with a comma 
	if ($JouTitle eq '' and $Seg[$i] =~ / vol\. \d+/) { 
	    $JouTitle = $`; $JouTitle=~s/^\s*|\s*$//g; } # delete spaces
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol = $1 if $Vol eq '' and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	{ $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
    }
    my @r = (8, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}


#   9 =>50  (Authors, [Publication_Title], Journal_Titile, Vol_Info)
#	    Jiao et al., Ytrrium Carbide in Nanotubes, Nature, 362, 503, 1993 (08 Apr. 1993).
sub ParseSciCite_9 {
    my($c) = @_;  my($i, @Seg, $au);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
# Specia rule 2 for Vol, StartPage, Year, and JouTitle
    if ($c =~ /([^,]+),? (\d+): ?(\d+).+((19|20)\d\d)/) {
    	$Vol = $2; $StartPage = $3; $Year = $4;
    	$JouTitle = $1; $JouTitle =~ s/^\s*|\s*$//g;
    }
# Simple Author rule 3'
    if ($Author eq '' and $c=~/\b([A-Z]\w+), [A-Z]\.(\s?[A-Z]\.\s?)?/) 
    { $Author=$1; $c = $';}
    if ($c =~ /(et al\.?,?)\s*/) { # get the author part
    	$au = $` . $1; # recombine into the author part for later extractoin
    	($PubTitle, $c) = split /[,;] ?/, $', 2; # try to get PubTitle
    } else { # there is no 'et al', try abbrev. middle name
        @Seg = split /[,;] ?/, $c;
        for($i=0; $i<@Seg; $i++) {# find the last author of the author part
            if ($Seg[$i]=~/\b[A-Z]\./) {} else { last; }
        }
        $au = join ", ", @Seg[0..($i-1)]; # put back the author part
        $PubTitle = $Seg[$i]; # "J. Appl. Phys., 47" can cause error
        $c = join ", ", @Seg[($i+1)..$#Seg];
        if ($PubTitle =~ /^\d+$/) # compensate the error here
	    { $c = join ", ", @Seg[($i-1)..$#Seg]; $PubTitle = ""; }
	if ($Seg[$i+1] =~ /^\d+$/) # compensate the error of having PubTitle
	    { $c = join ", ", @Seg[($i)..$#Seg]; $PubTitle = ""; }
    }
    # not a PubTitle, put back the string
    if ($PubTitle !~ /.\s./ or $PubTitle =~ /\d+$/) 
    	{ $c = $PubTitle . ', '. $c; $PubTitle = ""; }
# Simple Author rule 2
    if ($Author eq "" and $au=~/\b(\w\w+),? et al/) { $Author=$1; }
# Simple Author rule 3
    if ($Author eq '' and $au=~/\b([A-Z]\w+), [A-Z]\./) { $Author=$1; }
# Special Author rule for : "Smalley, Richard E.,"
    if ($Author eq '' and $au=~/\b([A-Z]\w+), \w+( |\-)[A-Z]\.(,| et al)/) { $Author=$1; }
# Below fit for the case where the Author part and the PubTitle have been extracted, 
# leaving only the JouTitle and Vol info
# Specia rule 1 for Vol, StartPage, Year, and JouTitle
    if ($c =~ /([^,]+),? (\d+), L?(\d+)(\-\d+)?.+((19|20)\d\d)/) {
# for the case: Saito et al., Jpn. J. Appl. Phys., vol. 36, L1340 (1997).
# for the case: DeHeer et al., Science, vol. 270, 1179 (1995).
    	$Vol = $2; $StartPage = $3; $Year = $5;
    	$JouTitle = $1; $JouTitle =~ s/^\s*|\s*$//g;
    	if ($JouTitle =~ /vol\./) { $JouTitle = ''; }
    }
    @Seg = split /[,;] ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# If JouTitle is not separated with Vol_Info with a comma 
	if ($JouTitle eq '' and $Seg[$i] =~ / vol\. \d+/) { 
	    $JouTitle = $`; $JouTitle=~s/^\s*|\s*$//g; } # delete spaces
# 1. Simple Vol rule
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol = $1 if $Vol eq '' and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	{ $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
    }
    my @r = (9, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}


#   10 =>33 ([Authors_0], [Publication_Title], Journal_Title, Vol_Info)
#	    Technology News Item, Solid State Technology, Nov. 1995, p. 42.
sub ParseSciCite_10 {
    my($c) = @_;  my($i, @Seg);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
# Specia rule 2 for Vol, StartPage, Year, and JouTitle
    if ($c =~ /([^,]+),? (\d+): ?(\d+).+((19|20)\d\d)/) {
    	$Vol = $2; $StartPage = $3; $Year = $4;
    	$JouTitle = $1; $JouTitle =~ s/^\s*|\s*$//g;
    }
# Special Author rule for : "Iijima, Nature vol. 354 pp. 56-58 Nov. 1991."
    if ($Author eq '' and $c=~/^([A-Z]\w+), /) { $Author=$1; $c = $'; }
# Specia rule 1 for Vol, StartPage, Year, and JouTitle, same as that in Type 9
    if ($c =~ /([^,]+),? (\d+), L?(\d+)(\-\d+)?.+((19|20)\d\d)/) {
    	$Vol = $2; $StartPage = $3; $Year = $5;
    	$JouTitle = $1; $JouTitle =~ s/^\s*|\s*$//g;
    	if ($JouTitle =~ /vol\./) { $JouTitle = ''; }
    }
    @Seg = split /[,;] ?/, $c;
    for($i=0; $i<@Seg; $i++) {
# Note: the sequence of the following statements is important.
#       Do not change their sequence!
# If JouTitle is not separated with Vol_Info with a comma 
	if ($JouTitle eq '' and $Seg[$i] =~ / vol\. \d+/) { 
	    $JouTitle = $`; $JouTitle=~s/^\s*|\s*$//g; } # delete spaces
# 1. Simple Vol rule
#	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; next; }
	if ($Vol eq "" and $Seg[$i] =~ /vol\.?\s*(\d+)/i) { $Vol = $1; }
# 2. Year rule and Vol rule
	if ($Year eq "" and $Seg[$i]=~/(\d+) \((\d\d\d\d)\)/) 
	{ $Vol = $1 if $Vol eq '' and $` !~ /\-$/; $Year = $2; }
# 3. Simple Year rule 
	if ($Year eq "" and $Seg[$i]=~/((19|20)\d\d)/) { $Year = $1; }
# 4. Vol rule 2: for the format : Vol (No)
	if ($Vol eq "" and $Seg[$i] =~ /(\d+) \(\d+\)/) { $Vol = $1 if $` !~ /\-$/; }
# 5. Simple StartPage rule
	if ($StartPage eq "" and $Seg[$i] =~ /\bpp?\.\s*(\d+)(\-\d+)?/) 
	{ $StartPage = $1; next; }
# 8. Simple JouTitle rule
	if ($JouTitle eq "" and $Seg[$i]!~/\d/) 
	{ $JouTitle=$Seg[$i]; $JouTitle=~s/^\s*|\s*$//g;  next; }
    }
    my @r = (10, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}

#Stone, C. A. (1989). Testing Software Review: MicroCAT Version 3.0. 
# Educational Measurement: Issues and Practice, 8 (3), 33-38.
sub ParseSciCite_APA {
    my($c) = @_;  my($i, @Seg);
    my($JouTitle, $PubTitle, $Author, $Year, $StartPage, $Vol); 
# Specia rule 2 for Vol, StartPage, Year, and JouTitle
    if ($c =~ /(\w.+)\((\d\d\d\d)\)\.?(.+)\.\s+(.+),\s*(\d+)\s*\(\d+\),\s+(\d+)\s*\-\s*\d+/) {
    	$Author = $1;
    	$Year = $2;
    	$PubTitle = $3;
    	$JouTitle = $4;
    	$Vol = $5; 
    	$StartPage = $6;
    }
# Special Author rule for : "Iijima, Nature vol. 354 pp. 56-58 Nov. 1991."
    if ($Author=~/^([A-Z]\w+), /) { $Author=$1; }
    $PubTitle =~ s/^\s*|\s*$//g;
    $JouTitle =~ s/^\s*|\s*$//g;
    my @r = (11, $Year, $Vol, $StartPage, $Author, $PubTitle, $JouTitle);
    return \@r;
}

# D:\demo\lwp>perl -s ClassifyCite.pl nanoSciRefs.txt >nanoSciRefs_3.txt
# 執行後得到各情況的次數統計，將各情況的引用型態整理如下：
#   0 =>9篇 (Jounal_Title_1, Vol_Info, [Authors], "Publication_Titile", [Authors], [More_Info])
#	    J. Phys. Chem., vol. 59, pp. 1153-1155, Nov. 1955, L. J. E. Hofer, et al., "Structure Of The Carbon Deposited From Carbon Monoxide On Iron, Cobalt And Nickel".
#   1 =>105 (Authors_1, "Publication_Title", Journal_Title, Vol_Info)
#	    S. Iijima, "Helical Microtubules of Graphitic Carbon," Nature, vol. 354, pp. 56-58 (1991).
#   2 =>38  (Journal_Title, Vol_Info, Authors, "Publication_Title", [More_Info])
#	    Appl. Phys. Lett. 69(27) 30 Dec. 1996 Yamamoto et al "New method carbon nanotube growth by ion beam indication", pp. 4174-4175.
#   3 =>356 (Authors, "Publication_Title", Journal_Title, Vol_Info)
#	    Ajayan et al, "Opening carbon nanotubes with oxygen and implications for filling", Nature, vol. 362, Apr. 8, 1993, pp. 522-525.
#   4 =>33  (Journal_Title, Vol_Info, [Authors], "Publication_Title", [Authors], [More_Info])
#	    Nature, vol. 367, 10 Feb. 1994, p. 519, "Purification of Nanotubes".
#   5 =>55  ([Authors_0], "Publication_Title", Journal_Title, Vol_Info)
#	    Iijima, "Helical microtubules of graphitic carbon", Nature, vol. 354, Nov. 7, 1991.
#   6 =>34  (Authors_1, [Publication_Title], Journal_Title, Vol_Info)
# 	    Y. Saito et al., Bamboo-Shaped Carbon Tube Filled Partially with Nickel, Journal of Crystal Growth, 134, 154-156, 1993 (Nov. 1993).
#   7 =>3篇 WO 00/51936 Zhou et al, 2000.*
#   8 =>8篇 (Publication_Title, Authors, Journal_Title, Vol_Info)
#	    Applications of Graphite Intercalation Compounds; M. Inagaki Journal of Material Research; vol 4, No. 6, Nov./Dec. 1989; pp. 1560-1568.
#   9 =>50  (Authors, [Publication_Title], Journal_Titile, Vol_Info)
#	    Jiao et al., Ytrrium Carbide in Nanotubes, Nature, 362, 503, 1993 (08 Apr. 1993).
#   10 =>33 ([Authors_0], [Publication_Title], Journal_Title, Vol_Info)
#	    Technology News Item, Solid State Technology, Nov. 1995, p. 42.
#  再次整理，得：
#   1 =>105 (Authors_1, "Publication_Title", Journal_Title, Vol_Info)
#	    S. Iijima, "Helical Microtubules of Graphitic Carbon," Nature, vol. 354, pp. 56-58 (1991).
#   3 =>356 (Authors, [(Year)] "Publication_Title", Journal_Title, Vol_Info)
#	    Ajayan et al, "Opening carbon nanotubes with oxygen and implications for filling", Nature, vol. 362, Apr. 8, 1993, pp. 522-525.
#	    Ren, Z.F., "Synthesis of Large Arrays of Well-Aligned Carbon Nanotubes on Glass," Science, vol. 282, 1105-1107 (Nov. 6, 1998).
#   5 =>55  ([Authors_0], "Publication_Title", Journal_Title, Vol_Info)
#	    Iijima, "Helical microtubules of graphitic carbon", Nature, vol. 354, Nov. 7, 1991.
#   6 =>34  (Authors_1, [Publication_Title], Journal_Title, Vol_Info)
# 	    Y. Saito et al., Bamboo-Shaped Carbon Tube Filled Partially with Nickel, Journal of Crystal Growth, 134, 154-156, 1993 (Nov. 1993).
#   9 =>50  (Authors, [Publication_Title], Journal_Titile, Vol_Info)
#	    Jiao et al., Ytrrium Carbide in Nanotubes, Nature, 362, 503, 1993 (08 Apr. 1993).
#	    Iijima, S., Nature, vol. 354, p. 56 (1991).
#   10 =>33 ([Authors_0], [Publication_Title], Journal_Title, Vol_Info)
#	    Technology News Item, Solid State Technology, Nov. 1995, p. 42.
#  其中 Authors=~/et al|\b\w\./, Authors_1=~/^\w\./, Authors_0:none of the above
#   0 =>9篇 (Jounal_Title_1, Vol_Info, [Authors], "Publication_Titile", [Authors], [More_Info])
#	    J. Phys. Chem., vol. 59, pp. 1153-1155, Nov. 1955, L. J. E. Hofer, et al., "Structure Of The Carbon Deposited From Carbon Monoxide On Iron, Cobalt And Nickel".
#   2 =>38  (Journal_Title, Vol_Info, Authors, "Publication_Title", [More_Info])
#	    Appl. Phys. Lett. 69(27) 30 Dec. 1996 Yamamoto et al "New method carbon nanotube growth by ion beam indication", pp. 4174-4175.
#   4 =>33  (Journal_Title, Vol_Info, [Authors], "Publication_Title", [Authors], [More_Info])
#	    Nature, vol. 367, 10 Feb. 1994, p. 519, "Purification of Nanotubes".
#   8 =>8篇 (Publication_Title, Authors, Journal_Title, Vol_Info)
#	    Applications of Graphite Intercalation Compounds; M. Inagaki Journal of Material Research; vol 4, No. 6, Nov./Dec. 1989; pp. 1560-1568.


1;
