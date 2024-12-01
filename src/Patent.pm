#!/usr/bin/perl -s
# can be Big5 or UTF-8, currently saved as UTF-8
package Patent;

    use strict;    use vars;
#    use LWP::Simple;
    use LWP::UserAgent;
    use SegWordPat;
#    my $seg=SegWordPat->new({'WordDir'=>'SAM/word', 'MaxRT'=>0, 'UseDic'=>0});
    use ParseSciRef;

=head1 NAME

Patent -- A class for getting and parsing patents from a patent website.

=head1 SYNOPSIS

    use Patent;
    $uspto = Patent->new( { 'Patent_INI'=>'Patent.ini' }, 'USPTO', 'NSC' );

    $uspto->PrintAttributes(); # for debugging
  # To test if the generic Set and Get method works:
    print "MaxDocNum=", $uspto->Value('MaxDocNum'),
    ", DefaultGroup=",  $uspto->Value('DefaultGroup'), "\n";
    &GetByPatNumber($uspto, @ARGV);

  # Given a patent number and an output directory,
  #   download the patent into the output directory
sub GetByPatNumber {
    my($me, $outdir, @PatNum) = @_; my($pat_url, $rPatent, $patnum);
    &MakeDir($outdir);
  #    $pat_url = "http://patft.uspto.gov/netacgi/nph-Parser?Sect1=PTO1&" .
  #        "Sect2=HITOFF&d=PALL&p=1&u=/netahtml/srchnum.htm&r=1&f=G&l=50&s1=" .
  #        "$patnum.WKU.&OS=PN/$patnum&RS=PN/$patnum";
    foreach $patnum (@PatNum) {
	$patnum =~ s/,//g; # delete ',' between digits
	$pat_url = $me->{PatentNo_URL};
	$pat_url =~ s/\$patnum/$patnum/g;
#	$rPatent = $me->Get_Patent_By_Number($patnum, $pat_url);
        $orgPatent = $me->ua_get($pat_url);
        $rPatent = $me->Parse_Patent( $orgPatent );

  #foreach $k (keys %$rPatent) { print "$k, "; } print "\n";
	$me->WriteOut($rPatent, "$outdir/pat/$rPatent->{PatNum}\.htm");
	$rPatentAbs = $me->GetPatentAbstract( $rPatent );
	$me->WritePatentAbs($rPatent, $rPatentAbs,
               "$outdir/abs/$rPatent->{PatNum}" . '-abs.htm');
        $me->PrintOutClaims( $rPatent ); # example of using &ParseClaims()
        $me->PrintOutDescription($rPatent);#example of using &GetPatentTOC()
    }
}

# Given the Claims string of the original HTML from USPTO,
# print out each of the claim items with leading claims highlighted.
# Using only 2 methods: ParseClaims() and GetValue()
sub PrintOutClaims {
    my($me, $rPatent) = @_;    my($i, $n, $c, $cn, $h1, $h2);
    $me->ParseClaims( $rPatent->{'Claims'} );
    $n = $me->GetValue('Claims_NumItems');
    $cn = $me->GetValue('Claims_NumLeads');
    print "\n<HR>There are $n claims and $cn of them are leading claims<p>\n";
    for($c=$i=0; $i<$n; $i++) {
    	if (($i+1) == $me->GetValue('Claims_Leads', $c)) {
	# test if $i-th item is a leading claim
    	    $h1 = "<font color=green>"; $c ++;
    	} else { $h1 = ''; }
    	$h2 = $h1 ? '</font>':'';
    	print $h1 . $me->GetValue('Claims_Items', $i) . $h2 . "<p>\n";
    }
}

# Given the Description string of the original HTML from USPTO,
# print out the parsed Description with the Section Title highlighted
# Using only 2 methods: GetPatentTOC() and GetValue()
sub PrintOutDescription {
    my($me, $rPatent) = @_;     my($i, $n, $c, $cn, $h1, $h2);
    $me->GetPatentTOC( $rPatent->{'Description'} );
    $n = $me->GetValue('PatentTOC_NumSections');
    print "\n<HR>There are $n Sections<p>\n";
    for($i=0; $i<$n; $i++) {
    	print "<h2>".$me->GetValue('PatentTOC_Title', $i)."</h2>" .
    	$me->GetValue('PatentTOC', $i)."\n";
    }
}

=head1 DESCRIPTION

    To generate the comments surrounded by =head and =cut, run
        pod2html Patent.pm > Patent.html
    under MS-DOS.

    Note: After =head and before =cut, there should be a complete blank line
    (only newline is allowed, not any white spaces) for correct formatting.

   This program is to fetch UPSTO patent documents. Given a patent number
    or a query string, it fetches patents from USPTO's website and then
    parse the patent into some fields that are more easy to handle.

Syntax:

  1. Given a query and a directory, fetch all (at most 200) patents and save
     them in the specified directory.
   Syntax: perl -s $0 -Oall query_string directory
   Ex : perl -s $0 -Oall  tm_dir "text mining"
  2. Given a query string (phrase), a page number, and a record number,
     print out the patent indicated by the record number. This is a
     imtermediate step out the above process.
   Syntax: perl -s $0 -Oget1 query_string page_number record_number
   Ex : perl -s $0 -Oget1 "text mining" 2 2
  3. Given a patent number, fetch the patent and save in

Author:

    Yuen-Hsien Tseng.  All rights reserved.

Date:

    2003/04/28

=cut


=head2 Methods

=cut

=head2 $pat=Patent->new( { 'Patent_INI'=>'Patent.ini' }, $group1, $group2 )

  The attributes in the object can be set by an INI file (through attribute
    'Patent_INI') or directly given in the constructor's argumnets in a
    key=>value format. To know the attribute names, consult Patent.ini.

  Attributes in an object in Perl is often saved in a referece to a hash.
  A reference to a no-name hash is donated as '{ }', as shown in
       $pat->new( { 'Patent_INI'=>'Patent.ini' }, $group1, $group2   );
  $group1 is usually 'USPTO'.
  $group2 is the one you want to use, e.g.: 'NSC'.

 This method return a reference to a no-name hash.

=cut
sub new {
    my($class, $rpara, $group1, $group2) = @_;
    $class = ref($class) || $class; # ref() return a package name
    my $me = bless( {}, $class ); # same as  $me={}; bless $me, $class;

    if (-e $rpara->{Patent_INI}) { # read attributes from file
            $me->ReadINI($rpara->{Patent_INI});
    } else {
# All the above settings can be replaced with the following statement:
        while (my($k, $v) = each %$rpara) {
            $me->{$k} = $v;
        }
    }
#print STDERR "A Patent object has been created!!\n";
    $me->{'seg_obj'}  
      = SegWordPat->new({'WordDir'=>'SAM/word', 'MaxRT'=>0, 'UseDic'=>0});
    $me->{'SciRef_obj'} = ParseSciRef->new( );

    $me->SetAttributes_by_DefaultGroup($group1);
    $me->SetAttributes_by_DefaultGroup($group2);
    $me->InitializeSavePatent();
    $me->Set_Patent_Existed();

    return $me;
}


=head2 ReadINI( 'Patent.ini' )

  Read the INI file ('Patent.ini') and set the patent object''s attributes.
  If you do not specify the Patent.ini in new() method, you can specify 
  it in this method.

  Return nothing, but has the side effect of setting some values to the
  attributes of the object.

=cut
sub ReadINI {
    my($me, $iniFile) = @_;
    my($GroupName, $DefaultGroup, %Groups);
    open (F, $iniFile) or die "Cannot open '$iniFile': $!";
    while (<F>) {
	next if /^#|^\s*$/; # if a comment line or an empty line
	chomp;
	if (/\[([^\[]+)\]/) { $GroupName = $1; next; }
	if (/^(\w+)=(.+)\s*$/) {
	    if ($1 eq 'DefaultGroup') {
		$DefaultGroup = $2;
	    } elsif ($GroupName eq '') { # GroupName not set yet, ...
		$me->{$1} .= $2;	 #    must be global attributes
	    } else { # local attributes (local to a group)
# Next line is the same as $Groups{$GroupName}->{$1} .= $2;
		$Groups{$GroupName}{$1} .= $2; # "->" can be omitted in 2-D hash
	    }
	}
    }
    close(F);
    $me->{DefaultGroup} = $DefaultGroup;
    $me->{Groups} = \%Groups; # a ref to a hash of hash
    if (keys %Groups == 0 or $me->{DefaultGroup} eq '') {
    	die "Ini_file=$iniFile\n$!";
    }
}


=head2 $pat->SetAttributes_by_DefaultGroup( [group_name] )

  By changing the 'DefaultGroup' attribute (say from 'USPTO' to 'JPO'),
  you may change the corresponding attributes (settings) by this method.

  Return nothing, but has the side effect of setting some values to the
  attributes of the object.

=cut
sub SetAttributes_by_DefaultGroup {
    my($me, $group) = @_; my($k, $v);
    if ($group eq '') { $group = $me->{DefaultGroup}; }
    while (($k, $v) = each %{$me->{Groups}->{ $group }}) {
            $me->{$k} = $v; # use the working group''s attribute to global
    }
# See the comments in Patent.ini for next segment
    if (not ref($me->{Patent_Fields})) {
	my @Patent_Fields = split /,/, $me->{Patent_Fields};
	$me->{Patent_Fields} = \@Patent_Fields;
    }
    if (not ref($me->{Patent_Abs_Fields})) {
	my @Patent_Abs_Fields = split /,/, $me->{Patent_Abs_Fields};
	$me->{Patent_Abs_Fields} = \@Patent_Abs_Fields;
    }
    if (not ref($me->{Patent_Des_Fields})) {
	my @Patent_Des_Fields = split /,/, $me->{Patent_Des_Fields};
	$me->{Patent_Des_Fields} = \@Patent_Des_Fields;
    }
    if (not ref($me->{Patent_Class_Fields})) {
	my @Patent_Class_Fields = split /,/, $me->{Patent_Class_Fields};
	$me->{Patent_Class_Fields} = \@Patent_Class_Fields;
    }
    if (not ref($me->{Patent_Class_Country})) {
	my @Patent_Class_Country = split /,/, $me->{Patent_Class_Country};
	$me->{Patent_Class_Country} = \@Patent_Class_Country;
    }
    if (not ref($me->{US_StateName})) {
	my @US_StateName = split /,/, $me->{US_StateName};
	my %US_StateName;
	foreach $k (@US_StateName) { $US_StateName{$k} = 1; }
	$me->{US_StateName} = \%US_StateName;
    }
}


=head2 PrintAttributes();

  This is for debugging. Print all the attributes of the object $pat.

  Return nothing, but has the side effect of showing all attributes and 
  their values in the STDOUT.

=cut
sub PrintAttributes {
    my($me) = @_;  my($k, $v);
    print "\n#=========== All attributes ...\n";
    while (($k, $v) = each %$me) {
            print "$k = $v\n\n";
    }
    print "\n#=========== Default group's attributes ...\n";
#    while (($k, $v) = each %{$me->{Groups}->{$me->{DefaultGroup}}}) {
# The above line is the same as next line, "->" can be omitted in 2-D case
    while (($k, $v) = each %{$me->{Groups}{$me->{DefaultGroup}}}) {
            print "$k = $v\n\n";
    }
}


=head2 Value() : A generic Set and Get method for all scalar attributes.

  Examples:
      $me->Value('MaxDocNum', 200); # Set MaxDocNum to 200
      $n = $me->Value('MaxDocNum'); # get MaxDocNum

  Any scalar attributes should work. That is, 'MaxDocNum' in the above
    can be replaced by, say, 'DefaultGroup', 'MaxAbsSen', etc.
  Other non-scalar attributes should use special Set and Get methods.

=cut
sub Value {
    my($me, $attribute, $value) = @_;
    if ($value ne '') {
        my $old = $me->{$attribute};
        $me->{$attribute} = $value;
        return $old;
    } else {
        return $me->{$attribute};
    }
}

=head2 SetValue() : A generic Set method for all scalar attributes.

  Examples:
      $me->SetValue('MaxDocNum', 200); # Set MaxDocNum to 200
      $n = $me->GetValue('MaxDocNum'); # get MaxDocNum
      $me->SetValue('MaxAbsSen', 3); # Set MaxAbsSen to 3
      $n = $me->GetValue('MaxAbsSen'); # get the value of MaxAbsSen

  Any scalar attributes should work. That is, 'MaxDocNum' in the above
    can be replaced by, say, 'DefaultGroup', 'MaxAbsSen', etc.
  Returns old value of the given attribute.
  Other non-scalar attributes should use special Set and Get methods.

=cut
sub SetValue {
    my($me, $attribute, $value) = @_;
    my $old = $me->{$attribute};
    $me->{$attribute} = $value;
    return $old;
}

=head2 GetValue() : A generic Get method for all scalar attributes.

  See SetValue() for examples and explanations.
  To get the value in a hash-typed attribute, a second attribute should 
  be given.
  Example: to get the computed abstracts of a patent, use
     $obj->SetValue('Title', $title_string); # title string is a must
     $obj->SetValue('Abstract', $Abs_string);
     $obj->SetValue('Task', $Task_string);
     $obj->SetValue('Application', $App_string);
     $obj->SetValue('Summary', $Sum_string);
     $obj->SetValue('Features', $Fea_string);
     $obj->SetValue('MaxAbsSen', 3); # default is 3
# or use next to re-define the number of sentences in the abstracts
     $obj->SetValue('MaxAbsSen_Application', 3); 
     $obj->SetValue('MaxAbsSen_Task', 3); 
     $obj->SetValue('MaxAbsSen_Abstract', 3); 
     $obj->SetValue('MaxAbsSen_Summary', 5); 
     $obj->SetValue('MaxAbsSen_Features', 5); 
     $obj->SetValue('MaxTopics', 5); 

     $obj->GetPatentAbstract(); # compute the abstracts of all fields

     $Abstr = $obj->GetValue('rPatentAbs', 'Abstract');
     $TaskStr = $obj->GetValue('rPatentAbs', 'Task');
     $AppStr = $obj->GetValue('rPatentAbs', 'Application');
     $SumStr = $obj->GetValue('rPatentAbs', 'Summary');
     $FeaStr = $obj->GetValue('rPatentAbs', 'Features');
  # sentences in the above are separated by "<BR><BR>"
     $TopStr = $obj->GetValue('rPatentAbs', 'Topics');
  # terms in the above are in the format: "t1:df1; t2:df2; ..."
=cut
sub GetValue {
    my($me, $attribute, $attr2) = @_;
    if ($attr2 eq '') {
    	return $me->{$attribute}
    }
    return $me->{$attribute}{$attr2};
}

sub load_env {
    my(@files) = @_; my(%ENV, $f, $file, $fh);
    for $f (@files) { if (-e $f) { $file = $f; last; } }
    open $fh, '<', $file or die "Could not open file: '$file': $!";
    while (<$fh>) {
        chomp;
        next if /^\s*#/;   # Skip comments
        next if /^\s*$/;   # Skip empty lines
        if (/^\s*(\w+)\s*=\s*(.*)\s*$/) {
            $ENV{$1} = $2;
        }
    }
    close $fh;
    return \%ENV;
}

=head2 ===Tools to get patents from a Website ===

=head2 $rPatent = $pat->get_uspto($patent_id); return the patent hash 

  Use PatentView API to fetch USPTO patent information

=cut
use Exporter 'import';
our @EXPORT_OK = ('get_uspto');
# C:\CATAR\src> perl -I. -MPatent=get_uspto -e 'get_uspto(0, 10165259)'
# The above command line works on 2024/11/25
use JSON;
sub get_uspto { # to replace ua_get() and Parse_Patent()
    my($me, $patent_id) = @_;
    my($ua, $req, $res, $url, $api_key, $query, $json_query, $patent, %Patent);
    # Create a UserAgent object
    $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 0);  # Disable SSL verification

    my $ENV = load_env('.env', 'myAPI_KEY.txt'); # check .env first
    $api_key =$ENV->{'API_KEY'};

# Step 1: fetch the patent information
    $url = 'https://search.patentsview.org/api/v1/patent/';
    $query = {
        q => { patent_id => $patent_id },
        f => [
            'patent_id', 'patent_date', 'patent_title', 'application', 'assignees',
            'inventors', 'cpc_at_issue', 'cpc_current', 'ipcr', 'patent_abstract'
        ]
    };
    $json_query = encode_json($query); # Convert the query from Hash to JSON string
    # Set up the request
    $req = HTTP::Request->new('POST', $url);
    $req->header('X-Api-Key' => $api_key);
    $req->header('Content-Type' => 'application/json');
    $req->content($json_query);
    # Execute the request
    $res = $ua->request($req);

    # Check the response
    if ($res->is_success) {
        my $data = decode_json($res->decoded_content);
# print("data=$data\n", $res->decoded_content, "\n"); exit();
#   data=HASH(0x1362ac0c8)
#   {"error":false,"count":1,"total_hits":1,"patents":[{"patent_id":"10165259", ...
#        print to_json($data, { pretty => 1 });
#        print("\n----------\n");
        $patent = $data->{patents}->[0];
#print to_json($patent, { pretty => 1 });
        $Patent{'PatNum'} = $patent->{'patent_id'};
        $Patent{'GovernCountry'} = 'US';
        $Patent{'IssuedDate'} = $patent->{'patent_date'};  
            $Patent{'IssuedDate'} =~ tr|\-|\/|;
        $Patent{'Appl. No.'} = $patent->{'application'}->[0]->{'application_id'};
        $Patent{'ApplyDate'} = $patent->{'application'}->[0]->{'filing_date'};
            $Patent{'ApplyDate'} =~ tr|\-|\/|; # to replace $Patent{'Filed'}
        $Patent{'Filed'} = $Patent{'ApplyDate'}; 
        # add $ApplyDate = $rPatent->{'ApplyDate'}; in PatentDB.pm
        $Patent{'Title'} = $patent->{'patent_title'};
        $Patent{'Abstract'} = $patent->{'patent_abstract'};
        $Patent{'Inventors'} = Inventors2str($patent->{'inventors'});
        $Patent{'Assignee'} = Assignees2str($patent->{'assignees'});
        $Patent{'Family ID'} = ''; # not important, no value so far
        $Patent{'Current CPC Class'} = cpc2str($patent->{'cpc_at_issue'});
        $Patent{'Current U.S. Class'} = '';
        $Patent{'Intern Class'} = cpc2str($patent->{'cpc_current'});
        $Patent{'Field of Search'} = ''; # not important, no value so far
        $Patent{'Cites'} = []; # not important, no value so far
        $Patent{'Parent Case'} = ''; # not important, no value so far
    } else {
        print "Error: " . $res->status_line . "\n";
        exit();
    }

=comment until next =cut
# So far all these fields: Application,Task,Summary,Drawings,Features,Claims 
#   are not available except from 2023. To know the update, see:
#     https://search.patentsview.org/docs/docs/Search%20API/TextEndpointStatus
# Step 2: fetch the patent claims
    $url = 'https://search.patentsview.org/api/v1/g_claim/';
    $query = {
        q => { patent_id => $patent_id },
        f => [ "patent_id", "claim_sequence", "claim_text" ]
    };
    $json_query = encode_json($query); # Convert the query from Hash to JSON string
    # Set up the request
    $req = HTTP::Request->new('POST', $url);
    $req->header('X-Api-Key' => $api_key);
    $req->header('Content-Type' => 'application/json');
    $req->content($json_query);
    # Execute the request
    $res = $ua->request($req);

    # Check the response
    if ($res->is_success) {
        my $data = decode_json($res->decoded_content);
# print("data=$data\n", $res->decoded_content, "\n"); exit();
#   data=HASH(0x1362ac0c8)
#   {"error":false,"count":1,"total_hits":1,"patents":[{"patent_id":"10165259", ...
print to_json($data, { pretty => 1 });
exit();
#        print("\n----------\n");
        $patent = $data->{patents}->[0];
        print to_json($patent, { pretty => 1 });
exit();
        $Patent{'Claims'} = $patent->{'patent_id'};

    } else {
        print "Error: " . $res->status_line . "\n";
        exit();
    }
=cut
    $me->{'rPatent'} = \%Patent; # 2003/12/01
    return \%Patent;
}

sub Inventors2str { 
    my($Inventors) = @_; # $Inventors is an array reference
# First sort the list elements by "inventor_sequence"
    my @sorted_inventors = sort { $a->{inventor_sequence} <=> $b->{inventor_sequence} } @$Inventors;
# Concatenate information into the desired format
    my $result = join(", ", map {
        sprintf("%s; %s (%s, %s)", $_->{inventor_name_last}, $_->{inventor_name_first}, 
                                    $_->{inventor_city}, $_->{inventor_country})
    } @sorted_inventors);
#print("inventors: $result\n"); #exit();
    return $result; 
}

sub Assignees2str { 
    my($Assignees) = @_; # $Assignees is an array reference
# First sort the list elements by "inventor_sequence"
    my @sorted_assignees = sort { $a->{assignee_sequence} <=> $b->{assignee_sequence} } @$Assignees;
# Concatenate information into the desired format
    my $result = join(", ", map {
        sprintf("%s (%s, %s)", $_->{assignee_organization},
                                    $_->{assignee_city}, $_->{assignee_country})
    } @sorted_assignees);
#print("assignees: $result\n"); #exit();
    return $result; 
}

sub cpc2str { 
    my($cpc) = @_; # $cpc is an array reference
    my @sorted_cpc = sort { $a->{cpc_sequence} <=> $b->{cpc_sequence} } @$cpc;
    my $result = join("; ", map {sprintf("%s", $_->{cpc_group_id})} @sorted_cpc);
#print("cpc: $result\n");
    return $result; 
}

sub ua_get {
    my($me, $url) = @_;
    my $TimeOut = $me->{TimeOut} || 5*60;
    my $ua = new LWP::UserAgent;
    $ua->timeout($TimeOut); # LWP::UserAgent's default is 180 seconds
# Set proxy URL for a scheme:
# $ua->proxy(['http', 'ftp'], 'http://proxy.sn.no:8001/');
#    $ua->proxy(['http', 'ftp'], 'http://proxy.fju.edu.tw/fju.pac');
# the above line seems not working, but next line works!!!
#    $ua->proxy(['http', 'ftp'], 'http://proxy.edu.tw:3128/');
    if( $me->{'ProxyServerURL'} )
    { $ua->proxy(['http'], $me->{'ProxyServerURL'}); }
# On 2020/08/27
    $ua->agent('Mozilla/5.0');

=Another way of creating a UserAgent
    my $ua = new LWP::UserAgent(
                'agent'       => "libwww-perl/$LWP::VERSION",
                'from'        => undef,
                'timeout'     => $TimeOut,
#                'proxy'       => 'http://proxy.fju.edu.tw/fju.pac', # undef,
# the above line seems not working, but next line seems to work!!!
                'proxy'       => 'http://proxy.edu.tw:3128/', # undef,
                'cookie_jar'  => undef,
                'use_eval'    => 1,
                'parse_head'  => 1,
                'max_size'    => undef,
                'no_proxy'    => [],
        );
=cut

# If the WebSite is password-protected, we may need the next line
#    $ua->credentials($netloc, $realm, $me->{UserName}, $me->{PassWord});

    my $request = new HTTP::Request('GET', $url);
    my $response = $ua->request($request);
#if ($response->is_success) {
    return $response->content;
#} else {
#        print STDERR $response->error_as_HTML;
}


=head2 $hits = $pat->SearchPatent($term1,$field1,$boolean_op,$term2,$field2);

  Given a query condition,
    search USPTO and get the first search result page

  For other patent search syntax not the same as USPTO, inherit this class 
    and overload this method.

  Return number of patents return from the search.

=cut
sub SearchPatent {
    my($me, $term1, $field1, $co1, $term2, $field2) = @_;
    my($search_url, $r, $n);
    $co1 = 'AND' if $co1 eq '';
#    $query =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    $search_url = $me->{Query_URL};

# Note the next 5 lines assume USPTO's search URL is used
    $search_url =~ s/\$term1/$term1/;
    $search_url =~ s/\$field1/$field1/;
    $search_url =~ s/\$co1/$co1/;
    $search_url =~ s/\$term2/$term2/;
    $search_url =~ s/\$field2/$field2/;
#print STDERR "term1='$term1', field1='$field1', co1='$co1', term2='$term2', field2='$field2'\n";
print STDERR "Search_URL=$search_url\n";
    $r = $me->ua_get( $search_url );

# Next line is also assumming USPTO's result page is got.
    if ($r =~ m#</strong> out of <strong>(\d+)</strong>#) { $n = $1; }
    return $n;
}


=head2 $rPatent = $pat->GetPatentPage($term1, 2, 2);

  Given a query string (phrase), a page number, and a record number
        get the patent document indicated by the record number.

  Although the $pat->GetPatentPage() can handle boolean queries, multiple
  query terms have not yet tested in this method.

  For other patent search syntax not the same as USPTO, inherit this class 
    and overload this method

  Return a reference to a hash with parsed patent stored in it.

=cut
sub GetPatentPage {
    my($me, $query, $page, $recno) = @_;
    my($patent_url, $orgPatent, $rPatent);
    $patent_url = $me->{Query_Patent_URL};
# Note the next 3 lines assumes USPTO's search URL is used
    $patent_url =~ s/\$query/"$query"/g; # only term1 is processed
    $patent_url =~ s/\$page/$page/g;
    $patent_url =~ s/\$recno/$recno/g;
    $orgPatent = $me->ua_get($patent_url);
    if ($me->{debug}) {
    	warn "$patent_url\n";
    }
    if (length($orgPatent) < 500) {
            $me->ReportError(
            "Fail to get the ${recno}th patent at page $page with query:'$query',".
            "may be due to connection error. " .
            "The fetched page is :\n<HR>'$orgPatent'<HR>\n");
            return {}; # return a ref to an empty hash
    }
    $rPatent = $me->Parse_Patent( $orgPatent );
    if (keys%$rPatent<5) {# if parsed patent does not yield correct structure
            $me->ReportError(
            "Fail to get the ${recno}th patent at page $page with query:'$query',".
            "may be due to parse error (patent page may have changed)");
            return {}; # return a ref to an empty hash
    }
    $me->SavePatent($rPatent, $orgPatent);
    return $rPatent;
}


=head2 $rPatent = $pat->Get_Patent_By_Number($patnum);

  Given a patent number, get the patent by looking at %Patent_Existed first. 
  If exists, then fetch the patent from the existing file in PatentDir, otherwise fetch 
    the patent from the USPTO and save the new patent document in the PatentDir and in
    Patent_Existed_DB (or Patent_Existed.txt).

  Return a reference to a hash with parsed patent stored in it.

=cut
sub Get_Patent_By_Number {
    my($me, $patnum) = @_; my($rPatent, $orgPatent) = ('', '');
    if ($me->Has_Patent_Existed($patnum)) {
        $rPatent = $me->Get_Patent_Existed($patnum);
print STDERR "Patent: $patnum already in DB\n" if $me->{debug}==1;
    } else {
#open FF,">d:/demo/STPIWG/Source_Data/tmp/$patnum.htm"; print FF $orgPatent; close(FF);
        $rPatent = $me->get_uspto($patnum);
    }
    $me->SavePatent($rPatent, $orgPatent);
    return $rPatent;
}

=head2 $rPatent = $pat->Get_Patent_By_Number_old($patnum, $pat_url);

  Given a patent number and a patent URL, get the patent by looking at
  %Patent_Existed first. If exists, then fetch the patent from the existing
  file, otherwise fetch the patent from the given URL and save the new patent
  document in the Patent_Existed_DB

  Return a reference to a hash with parsed patent stored in it.

=cut
sub Get_Patent_By_Number_old {
    my($me, $patnum, $pat_url) = @_; my($rPatent, $orgPatent);
    if ($me->Has_Patent_Existed($patnum)) {
        $rPatent = $me->Get_Patent_Existed($patnum);
print STDERR "Patent: $patnum already in DB\n" if $me->{debug}==1;
    } else {
print STDERR "$pat_url\n" if $me->{debug}==1;
        $orgPatent = $me->ua_get($pat_url);
        if (length($orgPatent) < 500) {
            $me->ReportError(
            "Fail to get patent (number:'$patnum') by \n$pat_url\n" .
            "may be due to connection error. " .
            "The fetched page is :\n<HR>'$orgPatent'<HR>\n");
            return {}; # return a ref to an empty hash
        }
#print STDERR "Save patent to d:/demo/STPIWG/Source_Data/tmp/$patnum.htm\n";
#open FF,">d:/demo/STPIWG/Source_Data/tmp/$patnum.htm"; print FF $orgPatent; close(FF);
        $rPatent = $me->Parse_Patent( $orgPatent );
        if (keys%$rPatent<5) {# parsed patent does not yield correct structure
            $me->ReportError("Fail to get patent (number:'$patnum')," .
            "may be due to parse error (patent page may have changed)".
            join(", ",keys%$rPatent) . $orgPatent . "\n"); # 2020/08/27
            return {}; # return a ref to an empty hash
        }
    }
    $me->SavePatent($rPatent, $orgPatent);
    return $rPatent;
}



=head2 === Save patent and patent abstracts in the file system ===

=head2 $pat->WriteOut($rPatent, $File);

  Given an output file and a ref to a Patent hash, write the patent to the file.

  The output file is currently in HTML format for ease of human inspection.
  (Also for WG 1.0 to make index for patent clustering experiments.)

  The same patent was fetched and saved in Patent_Existed_DB, but not in a
  format suitable for human reading. (But can be indexed by WG 3.0)

  The separator of the fields in the output file is "\n<HR>\n".

  Return nothing.

=cut
sub WriteOut {
    my($me, $rPatent, $file) = @_; my($f);
#use Cwd; print cwd() . "<br>\n";
    open F, ">$file" or print "Cannot write to file:'$file', $!" and die;
    print F "<HTML><head><title>$rPatent->{Title}</title></head><body>\n<HR>\n";
    foreach $f (@{$me->{Patent_Fields}}) {
            print F "<h3>$f</h3>\n";
            if (ref $rPatent->{$f}) {
                print F join "<br>\n", @{$rPatent->{$f}};
            } else {
            print F $rPatent->{$f};
        }
        print F "\n<HR>\n";
# next line is for dubegging
#print STDERR "warning: $rPatent->{PatNum} : '$f' has no content\n" if $rPatent->{$f} eq "";
    }
    print F "</body></html>\n";
    close(F);
}

=head2 $pat->WritePatentAbs($rPatent, $rPatentAbs, $File);

  Given an output file, a ref to a Patent hash, and a ref to a 
  patent abstract, write the patent abstract to the file.

  The output file is currently in HTML format for ease of human inspection.
  (Also for WG 1.0 to make index for patent clustering experiments.)

  The separator of the fields in the output file is "\n<HR>\n".

  Return nothing.

=cut
sub WritePatentAbs {
    my($me, $rPatent, $rPatentAbs, $file) = @_; my($f);
    open F, ">$file" or die "Cannot write to file:'$file', $!";
    print F "<HTML><head><title>$rPatent->{Title}</title></head><body>\n",
            "<h3>Patent</h3>\n$rPatent->{PatNum}\n<HR>\n",
            "<h3>Title</h3>\n$rPatent->{Title}\n<HR>\n";
    foreach $f (@{$me->{Patent_Abs_Fields}}) {
        print F "<h3>$f</h3>\n", $rPatentAbs->{$f}, "\n<HR>\n";
# next line is for dubegging
#print STDERR "warning $rPatent->{PatNum} : '$f' has no content\n" if $rPatentAbs->{$f} eq "";
    }
    print F "</body></html>\n";
    close(F);
}


=head2 --- Tools for Patent manipulations ---

=head2 $pat->InitializeSavePatent();

  Create the CSV file, save the field names in it.
  This method is like the method that connects to a DBMS.
  So you may inherit this class and overload this method when saving the
  patents using DBMS.
  Return nothing.

=cut
sub InitializeSavePatent {
    my($me) = @_;
=comment
    if ($me->{'Patent_Existed_DB'} eq '') {
    	die "DefaultGroup=" . $me->{DefaultGroup} . "\n" .
    	"SubFields=", $me->{SubFields} . "\n";
    }
=cut
    return if -e $me->{'Patent_Existed_DB'};
    open PE, "> $me->{Patent_Existed_DB}"
        or die "Cannot write to file:'$me->{Patent_Existed_DB}'";
    print PE join (",", map("\"$_\"", @{$me->{Patent_Fields}})), "\n";
    close(PE);
}


=head2 $pat->Set_Patent_Existed()

  This method is to set %Patent_Existed for fast matching of a
    given patnum with the existing patents. If matched, then the
    patent can be fetched from the stored file. If not, then the patent
    will be fetched from the website.

  But currently if matched, the patent is read from 
    "$me->{PatentDir}/$patnum.htm", instead of fetching from the stored file.

  This method is like to initialize %Patent_Existed from the patent table
  in a DBMS.

  So you may inherit this class and overload this method when saving the
  patents using DBMS. (Just do nothing in this method, delay actions to
  $pat->Get_Patent_Existed($PatNum);)

  Return nothing.

=cut
sub Set_Patent_Existed {
    my($me) = @_;    my($pn, $r, %Patent_Existed);
    open F, $me->{Patent_Existed_DB}
            or die "Cannot read file:'$me->{Patent_Existed_DB}'";
    while (<F>) {
            chomp;
            ($pn, $r) = split /","/, $_;
            $pn =~ s/^"//; # delete leading "
            $Patent_Existed{$pn} = 1; # only patnum is recorded
    }
    close(F);
if ($me->{debug}>=3){foreach $pn(sort keys %Patent_Existed){print STDERR "$pn, ";}print STDERR "\n";}
    $me->{Patent_Existed} = \%Patent_Existed;
}


=head2 $True_False = $pat->Has_Patent_Existed( $patnum );

  Given a patent number, check if the patent has been cached or not.

=cut
sub Has_Patent_Existed {
    my($me, $patnum) = @_;
    return $me->{Patent_Existed}{$patnum};
}


=head2 $rPatent = $pat->Get_Patent_Existed($PatNum);

  Given a patent number, read the patent into a hash %Patent from a CSV file,
    and return the ref to the hash

  This method is like the method fetches a patent by patnum from a DBMS.

  So you may inherit this class and overload this method when saving the
  patents using DBMS.

=cut
sub Get_Patent_Existed {
    my($me, $patnum) = @_;  my($orgPatent, $rPatent);
    my $file = $me->SavePatentPath($patnum);
    open P, "$file" or die "Cannot get existing Patent: '$file'";
    local $/; undef $/; $orgPatent = <P>;
    close(P);
    if (length($orgPatent)>100) { # $orgPatent has some text
        $rPatent = $me->Parse_Patent( $orgPatent );
    } else {
        $rPatent = $me->get_uspto($patnum);
    }
    return $rPatent;
}


=head2 $pat->SavePatent($rPatent, $orgPatent);

  Given the fetched patent document and the parsed patent structure,
  if the patent has not yet saved( and the parsed structure is correct), then
  save the patent document to the Original directory and patent structure
  to the $Patent_Existed_DB.

  This method is like an 'insert a patent' into a DBMS.

  So you may inherit this class and overload this method when saving the
  patents using DBMS.

=cut
sub SavePatent {
    my($me, $rPatent, $orgPatent) = @_;
    if ($me->Has_Patent_Existed( $rPatent->{PatNum} )) {
            return ; # already saved
    }
print STDERR "Save patent to : '$me->{Patent_Existed_DB}'\n" if $me->{debug}==1;
    open PE, ">>$me->{Patent_Existed_DB}"
        or die "Cannot append to file:'$me->{Patent_Existed_DB}'";
    print PE join (",", map("\"$rPatent->{$_}\"", @{$me->{Patent_Fields}})), "\n";
    close(PE);
# 2024/12/01, no more HTML files to save due to the changes of USPTO website.
#     my $file = $me->SavePatentPath($rPatent->{PatNum});
# print STDERR "Save patent to : '$file'\n" if $me->{debug}==1;
#     open P, ">$file" or die "Cannot write to file:'$file'";
#     print P $orgPatent;
#     close(P);
}

# Given a patent number, return the path that it should be saved
sub SavePatentPath {
    my($me, $patnum) = @_; my($file);
#   $file = $me->{PatentDir}; # if possible patents are in large number, use next
    $file = $me->{PatentDir} . '/' . substr($patnum, length($patnum)-2, 2); 
#    $me->CreatePath($file); # 2024/12/01, no more HTML files to save due to USPTO changes.
    return "$file/$patnum.htm";
}

=head2 CreatePath() : create the path to designated folder if it does not exist.

=cut
sub CreatePath {
    my($me, $path) = @_;  my(@Path, $dir, $i);
    @Path = split /[\/\\]/, $path;
    for($i=0; $i<@Path; $i++) {
    	$dir = join "/", @Path[0..$i];
    	if (not -d $dir) { 
    	    mkdir($dir, 0755) or die "Cannot create directory:'$dir'";
    	}
    }
}

=head2 ==== Parsing patent, Website dependent ====

=head2 ==== Parsing patent, written by ChatGPT 4o with Canvas ====

To test this fucntion, run:
C:\CATAR\src>perl -s patent.pl -Ofile tmp tmp\12136416.html
C:\CATAR\src>perl -s patent.pl -Ofile tmp tmp\12141757.html
The above html files are downloaded from USPTO basic search on 2024/11/13

This results are in C:\CATAR\src\tmp\pat and C:\CATAR\src\tmp\abs

=cut

use Data::Dumper;

use strict;
use warnings;
use HTML::TreeBuilder;

sub Parse_Patent {
    my ($me, $patent_in_html) = @_;
    my %patent;

    # Create a tree from the HTML content
    my $tree = HTML::TreeBuilder->new_from_content($patent_in_html);
#print($tree->dump); exit();

    # Extract data based on the HTML file structure
    $patent{'PatNum'}            = get_element_text($tree, 'span', 'MatchFromOtherFieldStyle');
    $patent{'IssuedDate'}        = parse_date(get_element_after_label($tree, 'span', 'Date of Patent'));
    $patent{'Title'}             = get_title($tree);
    $patent{'Inventors'}         = get_element_after_label($tree, 'p', 'Inventors:');
    $patent{'Assignee'}          = get_element_after_label($tree, 'p', 'Assignee:');
    $patent{'Family ID'}         = get_element_after_label($tree, 'p', 'Family ID:');
    $patent{'Appl. No.'}         = get_element_after_label($tree, 'p', 'Appl. No.:');
    $patent{'Filed'}             = parse_date(get_element_after_label($tree, 'p', 'Filed:'));
    $patent{'Current U.S. Class'} = get_element_after_label($tree, 'p', 'U.S. Cl.:');
    $patent{'Current CPC Class'} = get_element_after_label($tree, 'p', 'CPC');
    $patent{'Intern Class'}      = get_element_after_label($tree, 'p', 'Int. Cl.:');
    $patent{'Abstract'}          = get_Abstract_Claims_text($tree, 'Abstract');
    $patent{'Claims'}            = get_Abstract_Claims_text($tree, 'Claims');

    $patent{'Cites'}             = []; # get_Cites_text($tree, 'div', 'References Cited', ['Primary Examiner:']); # to-do
    $patent{'Application'}       = get_section_text($tree, 'h3', 'Background/Summary', 'FIELD[\W ]*', ['BACKGROUND[\W ]*']);
    $patent{'Task'}              = get_section_text($tree, 'h3', 'Background/Summary', 'BACKGROUND[\W ]*', ['SUMMARY[\W ]']);
    $patent{'Summary'}           = get_section_text($tree, 'h3', 'Background/Summary', 'SUMMARY[\W ]', ['ABITRARY']);
    $patent{'Features'}          = get_section_text($tree, 'h3', 'Description', 'DESCRIPTION OF EXAMPLE EMBODIMENTS|DESCRIPTION OF THE PREFERRED EMBODIMENTS', ['BRIEF DESCRIPTION OF THE DRAWINGS']);
    $patent{'Drawings'}          = get_section_text($tree, 'h3', 'Description', 'BRIEF DESCRIPTION OF THE DRAWINGS', ['DETAILED DESCRIPTION', 'DESCRIPTION OF EXAMPLE EMBODIMENTS']);

    # Set the hash to the object
    $me->{'rPatent'} = \%patent;

    # Clean up the tree to free memory
    $tree->delete;

    return \%patent;
}

# Helper function to get text of a specific element by tag and class
sub get_element_text {
    my ($tree, $tag, $class) = @_;
    my $element = $tree->look_down(_tag => $tag, class => $class);
    return $element ? $element->as_text : '';
}

# Helper function to get text following a specific label
sub get_element_after_label {
    my ($tree, $tag, $label) = @_;
    my $element = $tree->look_down(_tag => $tag, sub { $_[0]->as_text =~ /^\s*\Q$label\E\s*$/ });

    if ($element) {
        my $parent = $element->parent();
        if ($parent) {
            my @children = $parent->content_list();
            for (my $i = 0; $i < @children; $i++) {
                if (ref($children[$i]) && $children[$i] eq $element) {
                    # Find the next element that contains text
                    for (my $j = $i + 1; $j < @children; $j++) {
                        if (ref($children[$j]) && $children[$j]->can('as_text')) {
                            my $text = $children[$j]->as_text;
                            if ($text =~ /\S/) {
                                return $text;  # Return the text if it's not empty or whitespace
                            }
                        }
                    }
                }
            }
        }
    }

    return '';
}

# Helper function to get the title of the patent
sub get_title {
    my ($tree) = @_;
    my $title_element = $tree->look_down(_tag => 'h2');
    return $title_element ? $title_element->as_text : '';
}

# Helper function to get text from the Abstract section
sub get_Abstract_Claims_text {
    my ($tree, $h3_value) = @_; my($start_element, $current);
    # Next line can not locate any valid text, which is wiered (it should be)
#    $start_element = $tree->look_down(_tag => 'article', class => 'bottom-border padding');
#    print("article:", $start_element, "\n"); print($start_element->as_text, "\n");
    $start_element = $tree->look_down(_tag => 'h3', sub { $_[0]->as_text =~ /^\s*$h3_value\s*$/i });
#print($start_element->as_text, "\n");
    if ($start_element) {
        # Look for the <p> tag right after the <h3> Abstract
        $current = $start_element->right();
#print($current->as_text, "\n");
        return ($current)? $current->as_text : '';
    } else { return ''; }
}


# Generalized helper function to get text from a section with a specific start label and stop labels
sub get_section_text {
    my ($tree, $tag, $label, $start_label, $stop_labels) = @_;
    my($start_element, $text, $current, $start, $br, $acc_text);
#print("\ntag: $tag, label=$label, start: $start_label, stop:@$stop_labels=>");

# First, search the section under the $tag and $label:
    $current = $tree->look_down(_tag => $tag, sub { $_[0]->as_text =~ /\b$label\b/i });
#if ($current) { print("\n    text(30)=", substr($current->as_text, 0, 30), "\n"); }

# Second, loop over next segment until we find the $start_label in the segment
    do { 
        $current = $current->right(); # next right sibling
#if ($current) { print("        length=", length($current->as_text), ", text(40)=", substr($current->as_text, 0, 40), "\n"); }
        $start = $current->look_down(_tag => 'p', sub { $_[0]->as_text =~ /\b$start_label\b/i });
    } until ($start);
#if ($start) { print("            length=", length($start->as_text), ", text(50)=", substr($start->as_text, 0, 50), "\n"); }
#if ($start) { print("            length=", length($start->as_text), ", dump=", $start->dump, "\n"); }


# The $start point to the $start_label, extract the text until $stop_label
        $text = ''; $acc_text = 0; # status of starting to accumulate text is false
        foreach $br ($current->content_list) {
#print("    br length:", length($br), ", text(60):", substr($br, 0, 60), "\n");
            if (! ref($br)) {
                if ($br =~ /\b$start_label\b/) { $acc_text = 1; }
                next if ($acc_text == 0); # if not yet encounter the $start_label
                my $section_text = $br;
#print("section=$section_text\n  br dump:", $br->dump, "\n");
                # Stop if we encounter any of the stop labels
                foreach my $stop_label (@$stop_labels) {
                    if ($section_text =~ /\b$stop_label\b/i) {
                        return $text;
                    }
                }
                $text .= $section_text . " " if $section_text =~ /\S/;
            }
        }
        return $text;
    }
#    return '';
#}


# Helper function to parse date format from "Month DD, YYYY" to "YYYY/MM/DD"
sub parse_date {
    my ($date_str) = @_;
    if ($date_str =~ /(\w+)\s+(\d{1,2}),\s+(\d{4})/) {
        my %months = (
            'January'   => '01', 'February' => '02', 'March'    => '03',
            'April'     => '04', 'May'      => '05', 'June'     => '06',
            'July'      => '07', 'August'   => '08', 'September'=> '09',
            'October'   => '10', 'November' => '11', 'December' => '12'
        );
        return "$3/$months{$1}/$2";
    }
    return $date_str;
}

=head2 $rPatent = $pat->Parse_Patent_old($patent_in_html);

  Given a downloaded patent page from USPTO, parse the html page and return
    a reference to a hash %Patent with all the fields filled

  For other patent document not the same as USPTO, inherit this class and
    overload this method
  
  Attributes used: SubFields

  Attributes set:
  	Title, Abstract, Application, Summary, Task, Features, 
  	Application_SecTitle, Summary_SecTitle, Task_SecTitle,
  	Drwaings_SecTitle, Features_SecTitle,
  	PatNum, GovernCountry, IssuedDate, "Intern Class", Cites*, 
  	"Parent Case", Claims, Drawings,
  	( # below are also some minor attributes that has ben set
  	 Inventors and others, 
  	 U.S. Patent Documents and Other References
  	)
   

=cut
sub Parse_Patent_old {
    my($me, $r) = @_;
    my(%Patent, @R, $e, $i, $j, @D, @P, @Cites, @T, $table);
    my($patnum, $date, $title, $abs, $k, $v, $shift_i);

    @R = split /<[Hh][Rr]>/, $r; # split the segment by <HR>
print "\@R=", scalar @R, "\n" if $me->{debug}==1;
    $shift_i = 0; # some patent may have addtional sections before Claims
    for($i=0; $i<@R; $i++) {
#print "<p>Else($i): 4+$shift_i<br>\n";
	if ($i==0) { #  PatNum : from the HTML's title part
#	    if ($R[$i] =~ m#United States Patent: ([,\d]+)#) { # 2004/08/21
	    if ($R[$i] =~ m#United States Patent(\s\w+)?: ([,\d]+)#) {
		$patnum = $2; $patnum =~ s/,//g; 
		$Patent{'PatNum'}=$patnum;
		$Patent{'GovernCountry'} = 'US';
	    }
print "PatNum from :'$r'\n" if $patnum eq '' and $me->{debug}==1;
	} elsif ($i==1) { # Date, from the 2nd <HR> part
#	    if ($R[$i] =~ m#(\w+) (\d+), (\d+)\s*</B></TD>\s*</TR>\s*</TABLE>\s*$#i) {
	    if ($R[$i] =~ m#(\w+) (\d+), (\d+)#) {
		$date = $me->FormatDate($3, $me->Month($1), $2);
		$Patent{'IssuedDate'} = $date;
	    }
# match PatNum for Patent Application due to incorrect No. in Title field
	    if ($R[$i] =~ m#>\s*([,\d]+)\s*</#) { # 2004/08/21
		$patnum = $1; $patnum =~ s/,//g; 
		$Patent{'PatNum'}=$patnum;
#print "<h2>PatNum=$patnum<h2>\n";
	    } # else { print "<hr>No match:$R[$i]<hr>\n"; }
print "IssuedDate from :'$R[$i]'\n" if $date eq '' and $me->{debug}==1;
	} elsif ($i==2) { # Title and Abstract
        ($title, $abs) = split /<\/font><BR>/i, $R[$i];
	    $title =~ s/<[^>]+>//g; # delete all HTML tags
        $title =~ s/^\s*|\s*$//g; # delete leading and trailing space
	    $title =~ s/\s+/ /g; # delete line break
	    $abs =~ s/<[^>]+>//g;  # (Method)
	    $abs =~ s/\s+/ /g; # delete line break
	    $abs =~ s/^\s*Abstract\s*//i; # delete word:'Abstract' in the begining
	    $Patent{'Title'} = $title; $Patent{'Abstract'} = $abs;
print "Title from :'$R[$i]' \n" if $title eq '' and $me->{debug}==1;
print "Abstract from :'$R[$i]' is : '$abs'\n" if $abs eq '' and $me->{debug}==1;
#	} elsif ($i==3) { # inventors and others # 2007/11/10
	} elsif ($R[$i] =~ />Inventors:\s*<|>Assignee:\s*<| Class:\s*<|Field of Search:/i) {
NewFormat_USclass: # to deal with new format 
	    @D = split /<TR>/i, $R[$i];
# Note: Foreign Application Priority Data has no attribute name
	    for($j=0; $j<@D; $j++) {
		($k, $v) = split /<\/TH>/i, $D[$j]; # 2018/04/03
		($k, $v) = split /<\/TD>/i, $D[$j] if $v eq ''; # 2018/04/03
#print "\"$D[$j]\"\n'$k' => '$v'\n" if $me->{debug};
		$k =~ s/<[^>]+>//g; # delete all HTML tags
		$k =~ s/^\s*|\s*$//g; # delete leading and trailing space
		$k =~ s/:$//; # delete trailing semicolon;
		next if $k eq '';
		$Patent{$k.'_org'} = $v if $k =~/Inventors|Assignee/; # 2007/11/10
		$v =~ s/<[^>]+>//g; # delete all HTML tags
		$v =~ s/^\s*|\s*$//g; # delete leading and trailing space
		$v =~ s/\s+/ /g; # delete line break
		$k =~ s/'l//; # Convert 'Intern'l Class' into 'Intern Class'
		if ($k=~/Intern/) { $k = 'Intern Class'; } # 2006/12/07
		if ($k=~/Assignee/) { $k = 'Assignee' } # 2004/08/21 
#		if ($k=~/U\.S\. Current. Class/) { $k = 'Current U.S. Class' }
		if ($k=~/U\.S\..*Class/) { $k = 'Current U.S. Class' }
print "'$k' => '$v'\n\n" if $me->{debug};
		$Patent{$k} = $v;
	    }
# Next section is to deal with new format since 2006/07/10
	    if ($i==3 and ($Patent{'Current U.S. Class'} eq '' or
	    		   $Patent{'Intern Class'} eq '' or
	    		   $Patent{'Field of Search'} eq ''
	    		  ) 
	       ) { 
	    	$i=4; $shift_i += 1 ; # $NewFormat = 1; 
	    	goto NewFormat_USclass; 
	    }
	} elsif ($R[$i] =~ /Other References/) { # 2006/12/07

	} elsif ($R[$i] =~ /References Cited/) {
	# U.S. Patent Documents and Other References
print "References Cited :'$R[$i]'\n" if $me->{debug}==1;
            $i++; $r = $R[$i]; $shift_i += 2;
            @T = split /<\/TABLE>/i, $r;
            foreach $table (@T) { # for each table
                @D = split /<TR>/i, $table;
                next if @D == 0;
#                if (@D == 1) { @D = split /<br>/i, $table; } # 2007/07/20
                if ($table =~ /Other References/) { @D = split /<br>/i, $table; } # 2007/07/20
print "Table=$table<br>\n"  if $me->{debug}==1;
#print "Table=$table<br>\n" if $table =~ /Other References/;
# Note: U.S. Patent Documents has 4 fields and Other References has 1 field
                for($j=0; $j<@D; $j++) { # for each row
                    @P = split(/<\/TD>/i, $D[$j]); 
                    next if @P == 0;
                    for($k=0;  $k<@P; $k++) { # for each field
                        $P[$k] =~ s/<[^>]+>//g; # delete all HTML tags
                        $P[$k] =~ s/\s+/ /g; # delete line break
                        $P[$k] =~ s/^\s*|\s*$//g; # delete leading and trailing space
                    }
#                    push @Cites, join "\t", @P; 
# replace above line with next lines to allow empty rows and empty columns 
		     $v = join "\t", @P; 
		     $v =~ s/\t+/\t/g; $v =~ s/^\t*|\t*$//g; # delete leading and trailing tab
print "cite='$v'\n"  if $me->{debug}>=1;
		     push @Cites, $v if $v ne '';
                }
                $Patent{'Cites'} = \@Cites;
            }
#	} elsif ($R[4+$shift_i] =~ /Parent Case/) {
	} elsif ($R[$i] =~ /Foreign Patent Documents/) { # 2006/12/07

	} elsif ($R[$i] =~ /Parent Case/) {
            $i++; $shift_i += 2;
            $r = $R[$i];
            $r =~ s/\s+/ /g; # delete line break
            $Patent{'Parent Case'} = $r;
#	} elsif ($R[4+$shift_i] =~ /Claims/i) { # claim content
	} elsif ($R[$i] =~ /Claims/) { # claim content
#print "<p>Claims($i, $shift_i)$R[$i]\n" if $me->{debug}==1;
	    $i++; $r = $R[$i]; $shift_i += 2;
#	    $r =~ s/<[^>]+>//g; # delete all HTML tags
	    $r =~ s/\s+/ /g; # delete line break
	    $Patent{'Claims'} = $r;
#	} elsif ($R[4+$shift_i] =~ /Description/i) { # Description
	} elsif ($R[$i] =~ /Description/) { # Description
#print "<p>Description($i, $shift_i)$R[$i]\n" if $me->{debug}==1;
	    $i++; $r = $R[$i]; $shift_i += 2;
	    $Patent{'Description'} = $r; # 2004/04/11
	    @D = split /<BR><BR>/i, $r; # separate each paragraph
	    for ($j=0; $j<@D; $j++) {
	    	next if (length($D[$j]) > 80); # if headline too long
#		@P = split(' ', $D[$j]); next if @P>9; # if headline too long
		@P = ();

##		if ($D[$j] =~ /^([A-Z\(\)\s]+)$/) { # headline in uppercase
#		if ($D[$j] =~ /^([\.A-Z\(\)\s]+)$/) { # added on 2005/02/20
#		    $r = $1;  $r =~ s/^\s*|\s*$//g; # delete leading and trailing spaces
		if ($r = &IsHeadLine($D[$j]) ) { # added on 2005/02/20
		    next if $r =~ /^\s*$/; # escape if blank line
		    for ($k=$j+1; $k<@D and 
#			not $D[$k]=~/^([\.A-Z\(\)\s]+)$/; 
			not &IsHeadLine($D[$k]); # added on 2005/02/20
			$k++) {
			$D[$k] =~ s/\s+/ /g; # delete line break
			next if $D[$k] =~ /^\s*$/; # if blank line
			push @P, $D[$k]; # push until next upper-case line
	            }
	            next if @P == 0; # skip if empty content 2005/02/20
print "headline: '$r'\n" if $me->{debug}==1;
print "Next headline: '$D[$k]'\n" if $me->{debug}==1;

                    $j = $k - 1;
            # FIELD OF THE INVENTION (Application)
                    if ($r =~ /FIELD/i) {
			$Patent{'Application'} = join "<BR><BR>", @P;
			$Patent{'Application_SecTitle'} = $r;
            # BACKGROUND OF THE INVENTION (Task)
#		    } elsif ($r =~ /BACKGROUND OF THE INVENTION/) {
                    } elsif ($r =~ /BACKGROUND|Art/i) { # 2005/02/20
			$Patent{'Task'} = join "<BR><BR>", @P;
			$Patent{'Task_SecTitle'} = $r;
	    # for &GetBackground_SubField
            # SUMMARY OF THE INVENTION
#                    } elsif ($r =~ /SUMMARY/i) { # next line added 2005/02/20
                    } elsif ($r =~ /SUMMARY/i and $Patent{'Summary'} eq '') {
                        $Patent{'Summary'} = join "<BR><BR>", @P;
			$Patent{'Summary_SecTitle'} = $r;
            # BRIEF DESCRIPTION OF THE DRAWINGS
		    } elsif ($r =~ /DRAWINGS/i and $Patent{'Drawings'} eq '') {
			$Patent{'Drawings'} = join "<BR><BR>", @P;
			$Patent{'Drawings_SecTitle'} = $r;
            # DETAILED DESCRIPTION OF THE PREFERRED EMBODIMENT (Features)
                    } elsif ($r=~/DESCRIPTION|EMBODIMENT/i) {
			pop @P if $P[$#P] =~ /\* \* \* \* \*/;
			$Patent{'Features'} = join "<BR><BR>", @P;
			$Patent{'Features_SecTitle'} = $r;
#print "Feature has ", scalar @P, " paragraphs\n";
                    } else { # if the uppercase line does not match above name
                        open SF, ">>$me->{SubFields}"
                                or die "Cannot write to :'$me->{SubFields}'";
                        print SF "$patnum,'$r'\n"; close(SF);
                    }
                } # End of if uppercase line
            } # End of for ($j=0; $j<@D; $j++) {
            if ($Patent{'Application'} eq '') { # may be in Task (BACKGROUNG)
                $me->GetBackground_SubField(\%Patent);
            }
#	} elsif ($R[6+$shift_i] !~ /Claims/i) {
###	} elsif ($R[4+$shift_i] !~ /Claims/i) { # added on 2005/02/20, removed on 2006/12/12
###	    $i++; $shift_i += 2;
###print "<p>Else($i): 4+$shift_i<br>\n" if $me->{debug}==1;
	} # End of elsif () { # Description
    } # for($i=0; $i<@R
    $me->{'rPatent'} = \%Patent; # 2003/12/01
    return \%Patent;
}

# Given a line of text, return the headline if it is a headline,
#   otherwise, return '' if it is not a headline
sub IsHeadLine {
    my($line) = @_;
    if (length($line) > 80) { return ''; }
#    my @P = split(' ', $line); if (@P > 9) { return ''; } # if headline too long
    if ($line =~ /FIELD|BACKGROUND|SUMMARY|DRAWINGS|DESCRIPTION|EMBODIMENT/ 
      or $line =~ /Field|Art|Background|Summary|Description|Embodiment/) 
    { $line =~ s/^\s*|\s*$//g; return $line; } else { return ""; }
}

# Given the text and the field name, extract the field content in the text
sub GetBackground_SubField {
    my($me, $rPatent) = @_;
    my(@D, $j, @P, $r, $k);
    @D = split /<BR><BR>/i, $rPatent->{'Task'}; # separate each paragraph
print "paragraphs in Task (Background): ", scalar @D, "\n" if $me->{debug}==1;
    for ($j=0; $j<@D; $j++) {
            @P = split(' ', $D[$j]);
            next if @P > 8; # if headline too long
            @P = ();
#        if ($D[$j] =~ /^\d\.\s*([\w\s]+)$/) { # headline with number
#            $r = $1;
        if ($D[$j] =~ /^(\[\d+\]\s*)?\d\.\s*([\w\s]+)$/) { # # 2004/08/21
            $r = $2; # 2004/08/21
            $r =~ s/^\s*|\s*$//g; # delete leading and trailing spaces
            next if $r =~ /^\s*$/; # escape if blank line
#            for ($k=$j+1; $k<@D and not $D[$k]=~/^\d\.\s*([\w\s]+)$/; $k++) {
            for ($k=$j+1; $k<@D and not $D[$k]=~/^(\[\d+\]\s*)?\d\.\s*([\w\s]+)$/; $k++) { # 2004/08/21
                    $D[$k] =~ s/\s+/ /g; # delete line break
                push @P, $D[$k]; # push until next headline
               }
print "SubField headline: '$r'\n" if $me->{debug}==1;
#print "Next SubField headline: $k=>'$D[$k]'\n" if $me->{debug}==1;
            $j = $k - 1;
            # FIELD OF THE INVENTION (Application)
            if ($r =~ /Field/) {
                    $rPatent->{'Application'} = join "<BR><BR>", @P;
                $rPatent->{'Application_SecTitle'} = $r;
#print "Application: '$rPatent->{Application}'\n" if $me->{debug}==1;
            # Description of Related Art (Background) (Task)
            } elsif ($r =~ /Art/) {
                $rPatent->{'Task'} = join "<BR><BR>", @P;
                $rPatent->{'Task_SecTitle'} = $r;
#print "Task: '$rPatent->{Task}'\n" if $me->{debug}==1;
            }
        } # End of if headline with number
    } # End of for ($j=0; $j<@D; $j++) {
    if ($rPatent->{'Application'} eq '') { # 2004/08/21
    # if still empty, extract the first paragraph from Task
	@P = split /<BR><BR>/i, $rPatent->{'Task'};
	$rPatent->{'Application'} = shift @P;
	$rPatent->{'Task'} = join "<BR><BR>", @P;
    }
}

=head2 === Extract Other References ===

=head2 ($rUSRefs, $rForRefs, $rSciRefs) = $pat->GetOtherReference( $rPatent );

  Given a parse patent structure, 
    extracts the "Other Refereces" from the citation part.
  Return three references in an array: 
  	return (\@USPatRefs, \@ForPatRefs, \@SciRefs);
    each reference points to an array containing multiple citations.

=cut
sub GetOtherReference {
    my($me, $rPatent) = @_;  
    my($SciStart, $USStart, $ForStart, $c, @SciRefs, @USPatRefs, @ForPatRefs);
    $USStart = $SciStart = $ForStart = 0;
#print "====$rPatent->{PatNum}====\n", join("  <br>\n", @{$rPatent->{Cites}}), "\n";
    foreach $c (@{$rPatent->{Cites}}) {
    	if ($c =~ /^\s*U.S.\s+Patent/i) { 
    	    $USStart = 1; $SciStart = $ForStart = 0; next; }
    	if ($c =~ /^\s*Foreign\s+Patent/i) { 
    	    $ForStart = 1; $USStart = $SciStart = 0; next; }
    	if ($c =~ /^\s*Other\s+Reference/i) { 
    	    $SciStart = 1; $USStart = $ForStart = 0; next; }
    	if ($c =~ /^\s*Primary\s+Examiner:|^\s*Attorney/i) {
    	    $SciStart = $USStart = $ForStart = 0; next; }
    	next if $c =~ /^\s*$/; # skip if empty line
#Note:fields in the records of USPatRefs and ForPatRefs were separated by tab
    	if ($USStart) {  push @USPatRefs, $c; } # U.S. Patent Documents
    	if ($ForStart) {  push @ForPatRefs, $c; } # Foreign Patent Documents
    	if ($SciStart) {  push @SciRefs, $c; } # Other References
    }
#print "====\@USPatRefs====\n", join("  <br>\n", @USPatRefs), "\n";
#print "====\@ForPatRefs====\n", join("  <br>\n", @ForPatRefs), "\n";
#print "====\@SciRefs====\n", join("  <br>\n", @SciRefs), "\n";
#exit;
    return (\@USPatRefs, \@ForPatRefs, \@SciRefs);
}


=head2 $rPatRef = $pat->ParsePatRef( $citation_string );

 Given a Patent citation extracted from the "References Cited" in 
   a U.S. patent document, parse the citation and return the fields: 
   (PatentNo, Year, Inventor, USClass)

=cut
sub ParsePatRef {
    my($me, $c) = @_; 
    my($PatentNo, $Year, $Inventor, $USClass) = split /\t/, $c;
    if ($Year =~ /(\w+).+(\d\d\d\d)/ ) 
    { $Year = $me->FormatDate($2, $me->Month($1)); }
    $Inventor =~ s/\s*et\s+al|\.\s*$//g; # either inventor or a country code
    # delete et al in the inventor or . in the country code
    $USClass =~ s/\.\s*$//;
    return ($PatentNo, $Year, $Inventor, $USClass);
}

=head2 $rSciRef = $pat->ParseSciRef( $citation_string );

 Given a Scientific citation extracted from the "Other References" in 
   a U.S. patent document, classify the citation format and then parse the
   citation into fields: Type, Year, Vol, StartPage, Author, PubTitle, JouTitle.
 Type is only for internal use. if you do not know the type, just ignore it.
 Return a reference to an array containing the following fields:
   (Type, Year, Vol, StartPage, Author, PubTitle, JouTitle)
Actually this method does nothing but calls the same method in ParseSciRef.pm.

=cut
sub ParseSciRef {
    my($me, $c) = @_; 
    my $rSciRef = $me->{'SciRef_obj'}->ParseSciRef($c);
    $rSciRef->[1] = $me->FormatDate($rSciRef->[1]); 
    # modify the format of Year to fit the database format
    return $rSciRef;
}



=head2 === Extract Abstract ===

=head2 $rPatentAbs = $pat->GetPatentAbstract( $rPatent );

  Given a parse patent struture, extract abstracts for some sections.
  Return sections' abstracts.
  
  Attributes used: Title,Application,Task,Abstract,Summary,Features,Topics
    Patent_Abs_Fields=Application,Task,Abstract,Summary,Features,Topics
    MaxAbsSen=3
    # Max number of senteces generated in an abstract for a sectoin.
    # Attributes below will override the above if defined
    MaxAbsSen_Application=3
    MaxAbsSen_Task=3
    MaxAbsSen_Abstract=3
    MaxAbsSen_Summary=3
    MaxAbsSen_Features=3
    TaskClueWords
    MaxTopics

  Attributes set:
	Application,Task,Abstract,Summary,Features,Topics
# Next are for debugging
        "$fd\tKeyTerm", "$fd\tSenRank", "$fd\tSenWgt"

=cut
# Use MaxAbsSen, MaxAbsLen, MaxTopics, TaskClueWords
sub GetPatentAbstract {
    my($me, $rPatent) = @_;  my(%PatentAbs);
    
# next if is added on 2003/12/01
    if ($me->{'rPatent'} eq '') { # means texts are set from outside COM
	$rPatent->{'Title'} = $me->{'Title'};
	$rPatent->{'Abstract'} = $me->{'Abstract'};
	$rPatent->{'Application'} = $me->{'Application'};
	$rPatent->{'Task'} = $me->{'Task'};
	$rPatent->{'Summary'} = $me->{'Summary'};
	$rPatent->{'Features'} = $me->{'Features'};
    }

    my($rTWL, $rTFL, $rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN,
    $rLinkValue, $rSenList, $rSenRank, $text, $fd, $MaxSen, @SenNum, $w,
    %Topics, @Topics, $rTopics, @A, @B, $avg, $rSenWgt, $rST, $seg_obj);
    $seg_obj = $me->{'seg_obj'};

# Extract Title words, weight heavier when they appear.
    ($rTWL, $rTFL) = $seg_obj->ExtractKeyPhrase( $rPatent->{'Title'} );
    foreach $w (@$rTWL) { $Topics{$w} = $rTFL->{$w}; }

    # only these fields need abstracts
    foreach $fd (@{$me->{Patent_Abs_Fields}}) {
#print "$fd: $rPatent->{Application}\n" if $fd eq 'Application';
        ($rWL, $rFL, $rSenList, $rSenWgt) = $me->GetSenList($fd, $rPatent);
#print "$fd: @$rSenList\n" if $fd eq 'Application';


#if ($fd eq 'Abstract') { for (my $i=0; $i<@$rSenList; $i++) {
#  print "<p>$rSenList->[$i] ($rSenWgt->[$i])<p>\n"; } }

# accumulate keywords of each field to the %Topics
        foreach $w (@$rWL) { $Topics{$w} += $rFL->{$w}; }
# Add title word to the keyword list of each field
        foreach $w (@$rTWL) { $rFL->{$w} += $rTFL->{$w}; }

# if 'Task', add clue words to the keyword list
        if ($fd =~ /Task|Summary|Features/) {
#print "clue words=$me->{'TaskClueWords'}\n";
#print "After filtering, length=", length(join '. ', @$rSenList), "\n";
# If the text is too long, shrink it by getting rid of the middle half
            $w = @$rSenList;
            splice(@$rSenList, scalar(0.3*$w), scalar(0.6*$w)) if $w > 50;
            splice(@$rSenWgt , scalar(0.3*$w), scalar(0.6*$w)) if $w > 50;

#print "len=$w, after splice, len=", scalar @$rSenList, "\n";
            $avg=0; foreach(@$rWL){ $avg+=$rFL->{$_}; }
            $avg = (@$rWL>0)?($avg/@$rWL>0):(1);
            foreach $w (split /,/, $me->{'TaskClueWords'}) {
                    $rFL->{$w} += $avg; # weight of the clue words
            }
        }

# Recreate the keyword list
        @$rWL = sort {$rFL->{$b} <=> $rFL->{$a} } keys %$rFL; # Sort tf DESC
        ($rSN, $rST) = &SetSN($rSenList, $rWL); # create inverted structure
        ($rSenRank) = &RankSenList($rWL, $rFL, $rSN, $rST, $rSenWgt);
        $MaxSen = $me->{'MaxAbsSen_'.$fd} || $me->{'MaxAbsSen'};
        $MaxSen = (@$rSenRank>$MaxSen)?$MaxSen:@$rSenRank;
        @SenNum = sort {$a <=> $b} @$rSenRank[0..$MaxSen-1];
print "$fd=>MaxSen=$MaxSen, SenNum=@SenNum, SenRank=@$rSenRank\n" if $me->{debug};
#print "<p>$fd=>MaxSen=$MaxSen, SenNum=@SenNum, SenRank=@$rSenRank\n";
#print "WL=", join(', ', map("$_:$rFL->{$_}", @$rWL)), "\n" if $fd eq 'Task';
#print "SenList=", join("\n", @$rSenList), "\n" if $fd eq 'Task';
        $PatentAbs{$fd} = join "<BR><BR>", @$rSenList[@SenNum];
# Next are for debugging
        $PatentAbs{"$fd\tKeyTerm"} = join "\t", map "$_\t$rFL->{$_}", @$rWL;
# To restore: %KeyTerm = split /\t/, $PatentAbs{"$fd\tKeyTerm"}
        $PatentAbs{"$fd\tSenRank"} = join ", ", @$rSenRank;
        $PatentAbs{"$fd\tSenWgt"} = join ", ", @$rSenWgt;
    }

# Get topical terms, sort by tf and word_length
    @Topics = keys %Topics;
    $rTopics = $seg_obj->FilterTerms( \@Topics, \%Topics);
    @Topics = sort
#     &SortBy_tf_len(\%Topics) # only do the following things
    {$Topics{$b}*(@B=split' ',$b)<=>$Topics{$a}*(@A=split' ',$a)}#avoid warning
#    {$Topics{$b}*(split' ',$b) <=> $Topics{$a}*(split' ',$a)}
     @$rTopics;
    if (@Topics > 0) {
        my $max_index = $#Topics<($me->{'MaxTopics'}-1)?($#Topics):($me->{'MaxTopics'}-1);
print "Topics=", join(", ",map{"$_:$Topics{$_}"}@Topics[0..$max_index]), "\n" if $me->{debug};
        $PatentAbs{'Topics'} = join "; ", @Topics[0..$max_index];
    } else {
        $PatentAbs{'Topics'} = '';
    }
    $me->{'rPatentAbs'} = \%PatentAbs; # 2003/12/01
    return \%PatentAbs;
}


# Get enough sentence for abstracting
#   For each paragraph, skip those that contain Figure, steps.
#   Then parse each sentence and add a <pa> tag to each begining of the sen.
#   Compute the weight of each sentence and delete the inserted <pa> tags.
#   Finally, futher filter the sentences
sub GetSenList {
    my($me, $fd, $rPatent) = @_;
    my($text, $rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN, $i,
        $rLinkValue, $rSenList, $round, $done, $para, $p, @Para, @P,
        $rSenWgt, @SenWgt, $sen, $MaxPara, $PrevPara, $co, $seg_obj);
    $seg_obj = $me->{'seg_obj'};
    @$rSenList = (); # an empty list

    if (defined($rPatent->{$fd})) { @P = split /<BR><BR>/, $rPatent->{$fd}; } else { @P = (); }
    @Para = ();
    foreach $p (@P) {
	next if $p =~ /FIG|Figure/; # skip paragraphs with FIGures
	next if $p =~ /step\s+\d+/; # skip paragraphs with steps
	$p =~ s/<[^<]*>//g; # delete HTML tags
	$p .= ' .' if $p !~ /\.\s*$/; # add a period to end the sentence
	push @Para, $p;
    }
# insert <pa> tag to each paragraph for parsing the sentences
    $text = '<pa>' . join ('<pa>', @Para);
#print "Para=", join("\n", @Para), "\n" if $fd eq 'Abstract'; #'Features';
#print "$fd=>text=$text<p>\n" if $fd eq 'Features';

# Generate Sentence weight
    ($rIWL, $rIFL, $rWL, $rFL, $rName, $rSWL, $rSFL, $rSN,
        $rLinkValue, $rSenList) = $seg_obj->ExtractKeyPhrase( $text );
    $MaxPara = 0;
    foreach $sen (@$rSenList) { 
	if ($sen =~ /<pa=(\d+)>/) { # get leading paragraph number
	    $MaxPara=$1 if $MaxPara < $1;
	}
    }

    $PrevPara = -1;
    foreach $sen (@$rSenList) { 
	if ($sen =~ s/<pa=(\d+)>//) { # delete leading paragraph number
	    if ($PrevPara == $1 or $fd eq 'Abstract') {
		$co = 1; # still in the same paragraph
	    } else {   # increase the first sentence's weight
		$co = 1.5; $PrevPara = $1;
	    }
	    if ($1 == 0 or $1 == 1) { # if the first 2 paragraphs
		push @SenWgt, 2*$co;
	    } elsif (($1 == $MaxPara and $fd eq 'Task') or $1 == $MaxPara-1) {
		push @SenWgt, 4*$co; # if last second paragraph
	    } else {
		push @SenWgt, 1*$co;
	    }
	}
    }
#print "<br>Modified SenWgt=@SenWgt\n";
#print "SenList=@$rSenList\n" if $fd eq "Application";
    ($rSenList, $rSenWgt) = &FilterSentence($rSenList, 0, \@SenWgt);
#print "SenList=@$rSenList\n" if $fd eq "Application";
#print "abstract=@$rSenList\n" if $fd eq 'Abstract';
    return ($rWL, $rFL, $rSenList, $rSenWgt);
}


# Delete un-qualified sentences for abstracting.
sub FilterSentence {
    my($rSenList, $done, $rSenWgt) = @_;
    my($sen, $i, $j, @Sen, $SubEnd, @SenWgt);
    $SubEnd = 0; $j = -1;
NextLoop:    
    foreach $sen (@$rSenList) {
	$j++;
	if (not $done and $j == @$rSenList) {
	    push @Sen, $sen; push @SenWgt, $rSenWgt->[$j];
	    last; # push the last sentence if not yet $done
	}
#	next if $sen !~ /^[A-Z]/; # if not begin with a uppercase letter
	next if $sen !~ /^(\[\s\d+\s\]\s*)?[A-Z]/; # 2004/08/21
#	next if $sen =~ /FIGS?\s*\.|Figure\s*\.$/i; # if end with Figure.
	next if $sen =~ /\s[ie]$/; # if 'i.e.' or 'e.g.'
	next if $SubEnd; # last sentence ends with sub, this one is invalid
	if ($sen =~ /sub \.$/) { # end with Some.sub, then next sen is invalid
	    $SubEnd = 1;
	} else { $SubEnd = 0; }
	next if ($sen =~ tr/ / /) < 5; # setence too short
# delete the sentence if it contains too many figure numbers
	if ($sen !~ /^(\[\s\d+\s\]\s*)?[A-Z]/){ # 2004/08/21, if not begin with [0002]
	    $i = 0;
	    while ($sen =~ /(\d\d+)/g) { 
		$i++; next NextLoop if $i >= 2 or (length($1)==3 and $i>=1);
	    }
	}
	push @Sen, $sen;
	push @SenWgt, $rSenWgt->[$j];
    }
    return (\@Sen, \@SenWgt);
}

# private method
# Use @SenList, set %SN
sub SetSN {
    my($rSenList, $rRWL) = @_;  my($w, $i, $sen, %SenTerm);
    my %SN = (); # returned ref var, may be used outside this package
# Using next line would (over)emphasize Single English Word, good for some cases
#    foreach $w (@WL, keys %Stem) { # Note : Keys in %Stem are so far all stems
    foreach $w (@$rRWL) {
            $i = -1;
            foreach $sen (@$rSenList) {
                $i++;
# The \Q in next line ask Perl to disable special pattern char.
                 while ($sen =~ /\Q$w/ig) {
                         $SN{$w} .= "$i "; $SenTerm{$i} ++;
                 }
#print "$w : i=$i : $SN{$w} : $sen<br>\n"if $i==@$rSenList-1;
            }
    }
    return (\%SN, \%SenTerm);
}

# private method
# Given keyword list in @$rWL, %$rFL,
# the sentence number for which a term occurs, represented in %$rSN,
# compute which sentence contains most keywords listed in @$rWL
sub RankSenList { # private and public
  my($rWL, $rFL, $rSN, $rST, $rSenWgt) = @_;
  my($w, $s, $i, %RankSen, $max, $SenLen, @W);
    $max = 0;
    foreach $w (@$rWL) { $max = $rFL->{$w} if defined($rFL->{$w}) and $max < $rFL->{$w}; }
    foreach $w (@$rWL) { # for each sentence that contains the word
        next if not defined($rSN->{$w});
        foreach $s (split ' ', $rSN->{$w}) { # see &SetSN() to know the format
#      $RankSen{$s} += 1;
#      $RankSen{$s} += $rFL->{$w}; # accumulate the sentece's score
            $RankSen{$s} += 0.5 + $rSenWgt->[$s] * $rFL->{$w}/$max;
        }
    }
#print "<p>Modified SenWgt=@$rSenWgt\n";
#print "<br>Sentence Rank value:", join (", ", map"$_:$RankSen{$_}", sort {$a<=>$b}keys %RankSen) , "\n";
#print "<br>Sentence Term number:", join (", ", map"$_:$rST->{$_}", sort {$a<=>$b}keys %$rST) , "\n";
  while (($i, $w) = each %RankSen) {
#          $RankSen{$i} = $w / (($rST->{$i}>1)?log($rST->{$i})/log(2):1);
          $RankSen{$i} = $w / (($rST->{$i}>0)?($rST->{$i})**0.375:1);
#          $RankSen{$i} = $w / (($rST->{$i}>0)?$rST->{$i}:1);
  }
#print "<br>Sentence Rank value:", join (", ", map"$_:$RankSen{$_}", sort {$a<=>$b}keys %RankSen) , "<p>\n";
  my @SenRank = sort { $RankSen{$b} <=> $RankSen{$a} } keys %RankSen;
  return (\@SenRank);
}


=head2 $Num_of_Sections = $pat->GetPatentTOC( $PatentDescriptionString );

  Given the description of a Patent from USPTO, 
  extract titles from each section and generate the Table Of Content (TOC).
  
  Attributes used: none

  Attributes set:
    $me->{'PatentTOC_Title'} = \%PatentTOC_Title; # index begins from 0
    # Title of each Section
    $me->{'PatentTOC'} = \%PatentTOC; # index begins from 0
    # Content of each Section
    $me->{'PatentTOC_NumSections'} = $ith;
    return $ith; # return number of sections

=cut
sub GetPatentTOC {
    my($me, $DescStr) = @_;  my(%PatentTOC, %PatentTOC_Title);
    my($j, @D, @P, $NumWords, $ith, $r, $k); $ith = 0;
    @D = split /<BR><BR>/i, $DescStr; # separate each paragraph
    for ($j=0; $j<@D; $j++) {
#	@P = split(' ', $D[$j]); # see how many words in the paragraph
#	next if @P > 9; # if headline too long
	$NumWords = 1+($D[$j] =~ tr/ / /); # count number of words
	next if $NumWords > 9; # if headline too long, tr is fast that split
	@P = ();
	if ($D[$j] =~ /^([A-Z\(\)\s]+)$/) { # headline in uppercase
	    $r = $1;
	    $r =~ s/^\s*|\s*$//g; # delete leading and trailing spaces
	    next if $r =~ /^\s*$/; # escape if blank line
	    for ($k=$j+1; $k<@D and $D[$k]!~/^([A-Z\(\)\s]+)$/; $k++) {
		$D[$k] =~ s/\s+/ /g; # delete line break
		next if $D[$k] =~ /^\s*$/; # if blank line
		push @P, $D[$k]; # push until next upper-case line
            }
print "headline: '$r'\n" if $me->{debug}==1;
#print "Next headline: '$D[$k]'\n" if $me->{debug}==1;
            $j = $k - 1;
	    $PatentTOC_Title{$ith} = $r;
	    $PatentTOC{$ith} = join("<BR><BR>", @P);
	    $ith ++; # ith section
#print "Feature has ", scalar @P, " paragraphs\n";
        } # End of if uppercase line
    } # End of for ($j=0; $j<@D; $j++) {
    $me->{'PatentTOC_Title'} = \%PatentTOC_Title; # index begins from 0
    # Title of each Section
    $me->{'PatentTOC'} = \%PatentTOC; # index begins from 0
    # Content of each Section
    $me->{'PatentTOC_NumSections'} = $ith;
    return $ith;
}


=head2 $Num_of_Claims = $pat->ParseClaims( $PatentClaimString );

  Given the claims of a Patent from USPTO, 
  parse the claims and identify the leading claims.
  
  Attributes used: none

  Attributes set:
    $me->{'Claims_Leads'} = \%Claims_Leads; # index begins from 0
    # A list of integers referring to the leading claims in the Section Claims 
    $me->{'Claims_NumLeads'} = $cth; # index begins from 0
    $me->{'Claims_Items'} = \%Claims_Items;
    # Parsed claims, each claim item is saved in an element of @Claims
    $me->{'Claims_NumItems'} = $ith; # number of claim items
    return $ith; # return number of sections

=cut
sub ParseClaims {
    my($me, $ClaimStr) = @_;  my(%Claims_Items, %Claims_Leads);
    my($j, @D, @P, $ith, $r, $k, $cth); $ith = $cth = 0;
#print "ClaimStr=$ClaimStr<hr>\n";
    @D = split /<BR><BR>/i, $ClaimStr; # separate each paragraph
    for ($j=0; $j<@D; $j++) {
	@P = ();
	if ($D[$j] =~ /^(\d+)\./) { # detecting item number
	    $r = $1;
	    if ($D[$j] =~ /claim \d+/i) { # not a leading claim
	    } else {
		$Claims_Leads{$cth} = $r;	$cth ++;
#print "Claim Lead:$cth=>$r<Br>\n";
	    }
	    push @P, $D[$j];
	    for ($k=$j+1; $k<@D and $D[$k]!~/^(\d+)\./; $k++) {
#		$D[$k] =~ s/\s+/ /g; # delete line break
		next if $D[$k] =~ /^\s*$/; # if blank line
		push @P, $D[$k]; # push until next upper-case line
            }
print "Claim Item ID: '$r'\n" if $me->{debug}==1;
#print "Next claim item: '$D[$k]'\n" if $me->{debug}==1;
            $j = $k - 1;
	    $Claims_Items{$ith} = join("<BR><BR>", @P);
	    $ith ++; # ith claim
        } # End of detecting item number
    } # End of for ($j=0; $j<@D; $j++) {
    $me->{'Claims_Leads'} = \%Claims_Leads; # index begins from 0
    # A list of integers referring to the leading claims in the Section Claims 
    $me->{'Claims_NumLeads'} = $cth; # index begins from 0
    $me->{'Claims_Items'} = \%Claims_Items;
    # Parsed claims, each claim item is saved in an element of @Claims
    $me->{'Claims_NumItems'} = $ith; # number of claim items
    return $ith; # return number of sections
}


=head2 Auxiliary methods

=head2 $DateString = FormatDate($year, $month, $date)

  Given $year, $month, and $date, return a formatted date string for saving.
  EX: return "2003/11/02" if (2003, 11, 2) is given.
    return "9999/01/01" if $year eq '';
    return "$year/01/01" if $month eq '';
    return "$year/$month/01" if $date eq '';
    return "$year/$month/$date"; # year/month/date

=cut
sub FormatDate {
    my($me, $year, $month, $date) = @_;
    return "9999/01/01" if $year eq '';
    return "$year/01/01" if $month eq '';
    return "$year/$month/01" if $date eq '';
    return "$year/$month/$date"; # year/month/date
}


=head $month_num = Month( 'January' )

  Given an English month name, return the digital month name.
  Ex: 'Jan'=>'01', 'Dec'=>'12'.

=cut
sub Month {
    my($me, $mon) = @_;
    my %Month = ('Jan'=>'01', 'Feb'=>'02', 'Mar'=>'03', 'Apr'=>'04',
                  'May'=>'05', 'Jun'=>'06', 'Jul'=>'07', 'Aug'=>'08',
                  'Sep'=>'09', 'Oct'=>'10', 'Nov'=>'11', 'Dec'=>'12');
    return $Month{substr($mon, 0, 3)};
}

=head2 ReportError($msg)

  Report error message. You may inherit the method
  and overload it if your different output devise is used (default STDERR).

=cut
sub ReportError {
    my($me, $msg) = @_;
    print STDERR "$msg\n";
}


1;