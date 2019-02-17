#!/usr/bin/perl -s
package Stopword;
# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

Stopword -- A class for handling stop words. 

=head1 SYNOPSIS

    use Stopword;
    $Stop = Stopword->new( );
    $Stop->AddESW('font'); # add 'font' as an English Stop word
    $Stop->AddCSW('�o �A'); # add '�o �A' as a Chinese Stop word
    $Stop->AddEmark("\t"); # add "\t" as an English punctuation mark
    $Stop->AddCmark('�T'); # add '�T' as a Chinese punctuation mark
    $Stop->AddStopHead('�v'); # add '�v' as a Chinese stop head character
    $Stop->AddStopTail('�E'); # add '�E' as a Chinese stop tail character
    $Stop->DelESW('font'); # delete 'font' as an English Stop word
    $Stop->DelCSW('�o �A'); # delete '�o �A' as a Chinese Stop word
    $Stop->DelEmark("\t"); # delete "\t" as an English punctuation mark
    $Stop->DelCmark('�T'); # delete '�T' as a Chinese punctuation mark
    $Stop->DelStopHead('�v'); # delete '�v' as a Chinese stop head character
    $Stop->DelStopTail('�E'); # delete '�E' as a Chinese stop tail character
    if ($Stop->IsESW('the')) { print "'the'  is an English Stop Word\n"; }
    if ($Stop->IsCSW('�� �O')) { print "'�� �O' is a Chinese Stop Word\n"; }
    if ($Stop->IsEmark(',')) { print "',' is an English punctuation mark\n"; }
    if ($Stop->IsCmark('�A')) { print "'�A' is a Chinese punctuation mark\n"; }
    if ($Stop->IsStopHead(substr('�� �� ��', 0, 2))) { 
    	print "'��' is a Chinese Stop Head Character\n"; }
    if ($Stop->IsStopTail(substr('�� �� ��', 6, 2))) { 
    	print "'��' is a Chinese Stop Tail Character\n"; }
    print "English Stop Words: ", (join ', ', $Stop->GetESW()), "\n", 
	"Chinese Stop Words: ", (join ', ', $Stop->GetCSW()), "\n", 
	"English puntuation marks: ", (join ', ', $Stop->GetEmark()), "\n", 
	"Chinese puntuation marks: ", (join ', ', $Stop->GetCmark()), "\n", 
	"Chinese stop head characters: ", (join ', ', $Stop->GetStopHead()), "\n", 
	"Chinese stop tail characters: ", (join ', ', $Stop->GetStopTail()), "\n";

=head1 DESCRIPTION

    Stop words are often used as in a search engine to filter out 
    non-semantic-bearing terms.
  
Author:
    Yuen-Hsien Tseng. 
Date:
    1998/04/28, last update: 2003/06/02, 2003/11/07

=cut

#    use strict; use vars;
# Note: These are package variables, not object variables, use them carefully.
    use SAMtool::Stem;
    %ESW = ();	# English stop words
    %CSW =();	# Chinese stop words 
    %Emark = ();	# English punctuation marks
    %Cmark =();	# Chinese punctuation marks ���I�Ÿ�
    %StopHead = ();	# Chinese stop head
    %StopTail = ();	# Chinese stop tail 

=head1 Methods

=head2 new() : the constructor

  $Stop = Stopword->new( {'Attribute_Name'=>'Attribute_Value', ... } );

=cut
sub new {
    my($class, $rpara) = @_; 
    $class = ref($class) || $class; # ref() return a package name
    my $self = bless( {}, $class ); # same as  $self={}; bless $self, $class;
#print "in &new(): ref(\$rpara)='", ref($rpara), "'\n";
#    $self->Init($rpara) if ref($rpara);
    &SetStopHash();
    return $self;
}


=head2 IsStopHead() : test if a term is in the stop head dictionary

  $True_Or_False = $stop->IsStopHead( $term );

=cut
sub IsStopHead {
    my($pkg, $t) = @_;
    return exists $StopHead{$t};
}

=head2 IsStopTail() : test if a term is in the stop tail dictionary

  $True_Or_False = $stop->IsStopTail( $term );

=cut
sub IsStopTail {
    my($pkg, $t) = @_;
    return exists $StopTail{$t};
}	

=head2 IsCSW() : test if a term is in the Chinese Stop word dictionary

  $True_Or_False = $stop->IsCSW( $term );

=cut
sub IsCSW {
    my($pkg, $t) = @_;
    return exists $CSW{$t};
}

=head2 IsESW() : test if a term is in the English stop word dictionary

  $True_Or_False = $stop->IsWSW( $term );

=cut
sub IsESW {
    my($pkg, $t) = @_;
    return exists $ESW{$t};
}

=head2 IsEmark() : test if a term is an English punctuation mark

  $True_Or_False = $stop->IsEmark( $term );

=cut
sub IsEmark {
    my($pkg, $t) = @_;
    return exists $Emark{$t};
}

=head2 IsCmark() : test if a term is a Chinese punctuation mark

  $True_Or_False = $stop->IsCmark( $term );

=cut
sub IsCmark {
    my($pkg, $t) = @_;
    return exists $Cmark{$t};
}

=head2 AddStopHead() : add a term to the stop head dictionary

  $stop->AddStopHead( $term );

=cut
sub AddStopHead {
    my($pkg, $t) = @_;
    $StopHead{$t} = 1;
}

=head2 AddStopTail() : add a term to the stop tail dictionary

  $stop->AddStopTail( $term );

=cut
sub AddStopTail {
    my($pkg, $t) = @_;
    $StopTail{$t} = 1;
}	

=head2 AddCSW() : add a term to the Chinese stop word dictionary

  $stop->AddCSW( $term );

=cut
sub AddCSW {
    my($pkg, $t) = @_;
    $CSW{$t} = 1;
}

=head2 AddESW() : add a term to the English stop word dictionary

  $stop->AddESW( $term );

=cut
sub AddESW {
    my($pkg, $t) = @_;
    $ESW{$t} = 1;
}

=head2 AddEmark() : add a term to the English punctuation mark dictionary

  $stop->AddEmark( $term );

=cut
sub AddEmark {
    my($pkg, $t) = @_;
    $Emark{$t} = 1;
}

=head2 AddCmark() : add a term to the Chinese punctuation mark dictionary

  $stop->AddCmark( $term );

=cut
sub AddCmark {
    my($pkg, $t) = @_;
    $Cmark{$t} = 1;
}

=head2 DelStopHead() : delete a term from the stop head dictionary

  $stop->DelStopHead( $term );

=cut
sub DelStopHead {
    my($pkg, $t) = @_;
    delete $StopHead{$t};
}

=head2 DelStopTail() : delete a term from the stop tail dictionary

  $stop->DelStopTail( $term );

=cut
sub DelStopTail {
    my($pkg, $t) = @_;
    delete $StopTail{$t};
}	

=head2 DelCSW() : delete a term from the Chinese stop word dictionary

  $stop->DelCSW( $term );

=cut
sub DelCSW {
    my($pkg, $t) = @_;
    delete $CSW{$t};
}

=head2 DelESW() : delete a term from the English stop word dictionary

  $stop->DelESW( $term );

=cut
sub DelESW {
    my($pkg, $t) = @_;
    delete $ESW{$t};
}

=head2 DelEmark() : delete a mark from the English punctuation dictionary

  $stop->DelEmark( $term );

=cut
sub DelEmark {
    my($pkg, $t) = @_;
    delete $Emark{$t};
}

=head2 DelCmark() : delete a mark from the Chinese punctuation dictionary

  $stop->DelCmark( $term );

=cut
sub DelCmark {
    my($pkg, $t) = @_;
    delete $Cmark{$t};
}

=head2 GetStopHead() : get a reference to the stop head hash (dictionary)

  $rStopHead = $stop->GetStopHead( );

=cut
sub GetStopHead {
#  my $pkg = shift;
  return %StopHead;
}

=head2 GetStopTail() : get a reference to the stop tail hash (dictionary)

  $rStopTail = $stop->GetStopTail( );

=cut
sub GetStopTail {
#  my $pkg = shift;
  return %StopTail;
}

=head2 GetCSW() : get a reference to the Chinese stop word hash (dictionary)

  $rCSW = $stop->GetCSW( );

=cut
sub GetCSW {
#  my $pkg = shift;
   return %CSW;
}

=head2 GetESW() : get a reference to the English stop word hash (dictionary)

  $rESW = $stop->GetESW( );

=cut
sub GetESW {
#  my $pkg = shift;
   return %ESW;
}

=head2 GetEmark() : get a reference to the English punctuation mark hash

  $rEmark = $stop->GetEmark( );

=cut
sub GetEmark {
#  my $pkg = shift;
  return %Emark;
}

=head2 GetCmark() : get a reference to the Chinese punctuation mark hash

  $rCmark = $stop->GetCmark( );

=cut
sub GetCmark {
#  my $pkg = shift;
   return %Cmark;
}

#
# Copy all the texts from SetStopHash.txt generated by Stopword_gen.pl
#   and paste the texts below
#
sub SetStopHash {
    local $/; $/ = "\n\n";  my($a, @A);
#    @A = split /[\t\n]+/, <DATA>;  foreach $a (@A) { $StopHead{$a} = 1; }
    @A = split ' ', <DATA>;  foreach $a (@A) { $StopHead{$a} = 1; }
    @A = split ' ', <DATA>;  foreach $a (@A) { $StopTail{$a} = 1; }
    @A = split ' ', <DATA>;  foreach $a (@A) { $Emark{$a} = 1; }
    @A = split ' ', <DATA>;  foreach $a (@A) { $Cmark{$a} = 1; }
    @A = split ' ', <DATA>;  foreach $a (@A) { 
    	$ESW{lc $a} = 1; $ESW{Stem::stem(lc $a)} = 1; 
    }
    @A = split /\t|\n/, <DATA>;  foreach $a (@A) { $CSW{$a} = 1; }
}
1;
__DATA__
�D	�F	�]	�o	�w	��	��	��	
��	��	��	�H	�L	�i	�t	�u	
��	��	��	�T	�b	�o	�~	��	
��	��	��	��	�A	�`	�r	��	
�e	��	��	��	��	��	�M	�O	
�p	��	��	��	��	��	�h	��	
��	�O	�Q	��	�Y	�n	��	��	
��	��	��	�N	�q	�z	��	��	
�o	�N	��	��	��	��	��	�P	
��	��	��	�W	

�D	��	�@	�C	�D	�E	�F	�G	
�K	�Q	�T	�U	�]	�d	�w	��	
��	��	��	��	��	��	��	��	
��	�H	�L	�i	�u	�|	��	��	
�b	�o	�~	��	��	��	��	�A	
�Y	�r	��	�e	��	��	��	��	
��	�O	�p	��	��	��	��	��	
�h	��	��	�O	�Q	��	�Y	��	
��	�_	��	��	�N	�q	�z	�o	
�N	��	��	��	�P	��	��	��	
��	

!	"	#	$	%	&	'	(	
)	*	+	,	-	.	/	:	
;	<	=	>	?	@	[	\	
]	^	_	`	{	|	}	~	

�@	�A	�B	�C	�D	�E	�F	�G	
�H	�I	�J	�K	�M	�N	�Q	�S	
�U	�X	�]	�^	�_	�`	�a	�b	
�e	�f	�i	�j	�m	�n	�q	�r	
�s	�u	�v	�w	�x	�y	�z	�{	
�|	��	��	��	��	��	��	��	
��	��	��	��	��	��	��	��	
��	��	��	��	��	��	��	��	
��	��	��	��	��	��	��	�@	
�C	�H	�I	�q	�r	�s	�t	�w	
�x	�z	�{	�|	�}	��	Ƥ	��	
��	��	��	��	��	��	��	��	
��	�]	

nbsp quot gt lt
br    presented    preferred    prior    sub    present    invention
method    thereof    therefor	thereto	
contain    process    obtain    use    used    
relate    related	tried	tries	improve	improved
describe    written    provide    provided providing	
specific	specifical	specifically	recent	recently
using    two    thereon    include	included
respectively	report	accept	accepted	acceptable
one	two	three	four	five	six	seven	eight	nine	ten
optional example preferably preferable year    sup    step
alternative    let given    see    claim    table    invent
prepared	prepare	preparation	preparing follow	presently
particular	particularly need	arbitrary	arbitrarily
various	simply	concurrently	completely
artificially	nearly	near	basically	necessarily	moderately
accord		accordance	according	accordingly
develop	developed	comprised	comprise	comprising
inside	outside	correspond	easy	easily	consequently	widely
certain	certainly	forward	conventional	conventionally
disclosed	aforemention	generally	removed	removing
desirable	useful	require    required	requiring
especial	especially	made	enhance	enhancing	enhanced
possible	possibly	impossible	impossibly	specially
subsequently	subsequent	sequentially	simultaneous	simultaneously
dynamically	continuously	offer	advantagously
know	known	avoid	found	find	modify	defined	defining
suitable	attractive	merely	peculiar	peculiarly
locally	therefore	greatly	make	made	experimentally	normally
significantly	formally	previously	previous	typically
approximately	appropriately	quickly	extremely	mainly	currently
relatively	additionally	broadly	uniquely	functionally
unfortunately	completely	apparently	preferentially	usually
rarely	actually	clearly	remarkably	advantageously	strongly
initially	commonly	largely	substantially	independently
essentially	theoretically	extensively	successfully	temporarily
variously	readily	carefully	ultimately	precisely
alternatively	shortly	rapidly	proximately	periodically	properly
inadequately	accurately	sufficiently	preferebly	partially
practically	primarily	likely	potentially	alternately
similarly	severely	conveniently	originally	fairly
separate	select	selectively	al
take	investigate	able	successive	complicate
grown	indicate	shown	explain	study	paper	investigation
show	result	alternate	newly	demonstrate	total
based	multiple
a	about	above	across	after	afterwards	again	against	
all	almost	alone	along	already	also	although	always	
among	amongst	an	and	another	any	anyhow	anyone	
anything	anywhere	are	around	as	at	be	became	
because	become	becomes	becoming	been	before	beforehand	behind	
being	below	beside	besides	between	beyond	both	but	
by	can	cannot	co	could	das	de	der	
des	down	du	during	e.g	each	eg	egli	
ein	eine	either	el	ella	ellas	ellos	else	
elsewhere	enough	essi	et	etc	even	ever	every	
everyone	everything	everywhere	except	few	first	for	former	
formerly	from	further	gli	gt	had	has	have	
having	he	hence	her	here	hereafter	hereby	herein	
hereupon	hers	herself	him	himself	his	how	however	
i	ie	if	il	in	inc	indeed	into	
is	it	its	itself	je	la	las	last	
latter	latterly	le	least	les	less	lo	los	
lt	ltd	many	may	me	meanwhile	might	more	
moreover	most	mostly	much	must	my	myself	namely	
nbsp	neither	never	nevertheless	next	no	nobody	noi	
none	noone	nor	nosotros	not	nothing	nous	now	
nowhere	of	off	often	on	once	one	only	
onto	or	other	others	otherwise	our	ours	ourselves	
out	over	own	per	perhaps	quot	rather	said	
same	say	seem	seemed	seeming	seems	several	she	
should	since	so	some	somehow	someone	something	sometime	
sometimes	somewhere	still	such	than	that	the	their	
them	themselves	then	thence	there	thereafter	thereby	therefore	
therein	thereupon	these	they	this	those	though	through	
throughout	thru	thus	to	together	too	toward	towards	
tu	un	una	unas	und	under	une	unos	
until	up	upon	us	very	via	voi	vosotros	
vous	was	we	well	were	what	whatever	when	
whence	whenever	where	whereafter	whereas	whereby	wherein	whereupon	
wherever	whether	which	while	whither	who	whoever	whole	
whom	whose	why	will	with	within	without	would	
yet	yo	you	your	yours	yourself	yourselves	

�@ �@	�@ �f	�@ �f ��	�@ ��	�@ ��	�@ ��	�@ �� ��	�@ �j �L	
�@ ��	�@ �@	�@ �A	�@ �P	�@ �V	�@ �p	�@ �r	�@ ��	
�@ �� �A	�@ ��	�@ ��	�@ �� ��	�@ ��	�@ ��	�@ ��	�@ ��	
�@ ��	�@ �u	�@ �w	�@ �w �n	�@ �w �|	�@ �� ��	�@ ��	�@ �� ��	
�@ �b ��	�@ �h	�@ �l	�@ ��	�@ ��	�@ ��	�@ �N	�@ �O	
�@ ��	�@ ��	�@ ��	�@ �� ��	�@ �� ��	�@ �w ��	�@ ��	�@ �� �H	
�@ �_	�@ �� �L	�@ �� �l	�@ �M ��	�@ ��	�@ �s	�@ �w	�@ ��	
�@ �L	�@ ��	�@ ��	�@ �� ��	�@ �N	�@ �|	�@ ��	�@ �� ��	
�@ ��	�@ �� �W	�@ ��	�@ �D	�@ �D ��	�@ ��	�@ �� ��	�@ ��	
�@ ��	�@ �K	�@ �|	�@ �� ��	�@ ��	�@ ��	�@ �� ��	�@ �� �l	
�D ��	�D �� ��	�F �@	�G ��	�G �u	�G �h	�H ��	�H ��	
�L �G	�O ��	�O ��	�Q �C �K	�Q ��	�S �H	�S ��	�S �n	
�S ��	�T ��	�T �u	�T �h	�U ��	�U �b	�U �b �~	�U �h	
�U ��	�W �@ �u	�W ��	�W �b	�W �b �~	�W ��	�W �z	�W �g	
�Z ��	�Z �O	�[ �[	�] ��	�] �i	�] �b	�] ��	�] �� ��	
�] �O	�] �n	�] �N	�] �\	�] �L	�] �|	�_ �O	�a ��	
�d �U	�j �O	�j �Z	�j �f	�j �[	�j �i	�j �� ��	�j �B	
�j ��	�j �D �i	�j �f �f	�j ��	�j ��	�j �P	�j �P �W	�j ��	
�j �W ��	�j ��	�j �T	�j ��	�j ��	�j �v	�j �|	�m �M	
�p �@	�p �T	�v ��	�v �g	�w �b	�w ��	�w �� ��	�w ��	
�w �i	�w ��	�w ��	�w �� ��	�w �v ��	�w �M	�w �g	�w �g �X	
�w �F	�x �g	�~ �O	�~ ��	�~ �|	�� �@ �w	�� �U	�� �j	
�� ��	�� ��	�� ��	�� ��	�� �[	�� �h	�� �i	�� �i �H	
�� �i ��	�� �u	�� �~	�� ��	�� �� �A	�� ��	�� �� ��	�� ��	
�� �� �a	�� �� �o	�� ��	�� �A	�� �h �[	�� �� �T	�� ��	�� ��	
�� �J	�� �K	�� �[	�� �[ ��	�� ��	�� �� �o	�� �� �a	�� ��	
�� ��	�� �O	�� ��	�� �P	�� �P ��	�� �Y	�� �n	�� ��	
�� �e	�� ��	�� ��	�� ��	�� �� ��	�� �S	�� ��	�� �� ��	
�� �� ��	�� �t	�� �o	�� �o ��	�� ��	�� �\	�� ��	�� ��	
�� ��	�� �� ��	�� �_	�� ��	�� �� �M	�� �M	�� ��	�� ��	
�� �� ��	�� �Q	�� �\	�� �v	�� �|	�� �| �C	�� �| �N	�� �g �N	
�� �L	�� �N	�� ��	�� ��	�� ��	�� ��	�� �W	�� ��	
�� �_	�� ��	�� ��	�� �� ��	�� ��	�� ��	�� �@	�� �G	
�� �H	�� �K �E	�� �Q	�� �S	�� �T	�� �U	�� �W	�� �[	
�� �f	�� �h	�� �j	�� �k	�� �l	�� �p	�� �~	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �� �_	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� �D	�� �H	�� �\	�� �_	�� �b	�� �|	�� �~	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� �C	�� �W	�� �a	�� �b	�� �h	�� �r ��	�� �~	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� �@	
�� �L	�� �O	�� ��	�� �a	�� ��	�� ��	�� ��	�� ��	
�� �M	�� �]	�� �d	�� ��	�� �� �H	�� ��	�� �e	�� ��	
�� ��	�� ��	�� ��	�� ��	�� �K	�� �a	�� �e	�� ��	
�� ��	�� ��	�� �G	�� �y	�� ��	�� ��	�� ��	�� �p	
�� ��	�� ��	�� ��	�� ��	�� �a	�� �t	�� �t �O	�� �{	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� �� ��	
�� �]	�� ��	�� ��	�� ��	�� �w	�� ��	�� ��	�� �z	
�� ��	�� �B	�� �N	�� ��	�� ��	�� �L	�� ��	�� �h	
�� �u	�� ��	�� �q	�� ��	�� ��	�� ��	�� �N	�� ��	
�� ��	�� �S	�� �o	�� �q	�� ��	�� ��	�� �D	�� �L	
�� �j	�� ��	�� ��	�� ��	�� ��	�� �A ��	�� �q	�� ��	
�� �y	�� ��	�� ��	�� �� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �l	�� ��	�� �I	�� �n	�� �|	�� ¾	�� ��	
�� ��	�� ��	�� �_	�� ��	�� �w	�� ��	�� ԣ	�� �H	
�� ��	�� ��	�� ��	�� �H	�� �i	�� ��	�� �b	�� ��	
�� �O	�� ��	�� �N	�� �M	�� ��	�� �� ��	�� ��	�� �~	
�� �~ ��	�� ��	�� �_	�� ��	�� ��	�� �e	�� �q	�� �G	
�� �M	�� ��	�� �X	�� �~	�� �O	�� ��	�� ��	�� �Y	
�� ��	�� ��	�� ��	�� ��	�� ��	�� �A ��	�� ��	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� �`	�� �_	
�� ��	�� ��	�� ��	�� ��	�� �_	�� ��	�� ��	�� �L	
�� �L ��	�� ��	�� �� �O	�� ��	�� ��	�� ��	�� �}	�� �_	
�� �H	�� �s ��	�� ��	�� ��	�� �M	�� �~	�� �i	�� ��	
�� ��	�� �l	�� ��	�� �U ��	�� �W ��	�� ��	�� �b	�� ��	
�� �]	�� �e	�� �q	�� �_	�� ��	�� ��	�� ��	�� ��	
�� ��	�� ��	�� ��	�� ��	�� �} �l	�� �e	�� ��	�� ��	
�� �h �~	�� ��	�� ��	�� �t	�� ��	�B ��	�D �n	�D �n �O	
�E �M	�H �U	�H �W	�H ��	�H ��	�H ��	�H �� ��	�H �K	
�H �C	�H ��	�H ��	�H ��	�H �K	�H �e	�H ��	�H �O	
�H ��	�H �P	�H �P ��	�H ��	�H �W	�H �T	�L �]	�L ��	
�L �b	�L ��	�L �� ��	�L �� �X	�L �O	�L ��	�L �N	�L �j ��	
�L ��	�L �{ ��	�L ��	�O �H	�R �� �q	�R ��	�X �{	�[ �J	
�[ �W	�[ �H	�[ �N	�] �t	�] �A	�] ��	�b �~	�b �~ �e	
�d ��	�d ��	�f �l	�h �~	�i �� ��	�i �� �� 	�i �H	�i �H ��	
�i �H �� 	�i �H ��	�i �H �� 	�i ��	�i ��	�i �� ��	�i �� �� 	�i �A	
�i �C	�i �P ��	�i �P �� 	�i �s	�i ��	�i ��	�i �@	�i �K	
�i �_	�i �e �{	�i �e �{ 	�i ��	�i ��	�i �� �o	�i ��	�i ��	
�i �� ��	�i ��	�i ��	�i ��	�i ��	�i �� �M	�i �� �M 	�i ��	
�i ��	�i �� 	�i ��	�i �� ��	�i �� �� 	�i �O	�i ��	�i �� �}	
�i �� �} 	�i �n	�i ��	�i �� ��	�i �� �� 	�i �� ��	�i �� �� 	�i �� �O	
�i �� ��	�i �� �� 	�i �� �|	�i ��	�i �N	�i ��	�i �� 	�i �i ��	
�i �i �� 	�i �g ��	�i �g �� 	�i �F	�i �� ��	�i �� �� 	�i ��	�i �P ��	
�i �P �� 	�i ��	�i �� ��	�i �� �� 	�i ��	�i �� 	�i �� �s	�i �� �s 	
�i �� ��	�i �� �� 	�i �� ��	�i �� �� 	�i �k	�k �C	�l �}	�m �m	
�m �N	�m ��	�t �@	�t �� ��	�t �~	�t ��	�t ��	�t �� �@ ��	
�t ��@ ��	�u �� �L	�u �n	�u ��	�u �O	�u �n	�u �� ��	�u ��	
�u ��	�u �o	�z �z	�z ��	�| �U	�| �u	�| �h	�| �B	
�~ �e	�~ ��	�� ��	�� �k	�� ��	�� ��	�� ��	�� ��	
�� ��	�� ��	�� �w	�� �n	�� �o	�� �M	�� ��	�� ��	
�� �D	�� �w �w	�� ��	�� �P	�� �u	�� ��	�� ��	�� ��	
�� ��	�� �g	�� ��	�� �W	�� ��	�� �[	�� ��	�� �]	
�� ��	�� �K	�� �� �o	�� ��	�� �l	�� �w	�� �K	�� ��	
�� �o	�� ��	�� ��	�� ��	�� �b	�� �n	�� ��	�� �O	
�� �`	�� ��	�� �@	�� ��	�� �� �W	�� �� ��	�� ��	�� ��	
�� ��	�� �� �F	�� �� ��	�� ��	�� ��	�� �H	�� ��	�� ��	
�� ��	�� ��	�� �_	�� �� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �J	�� �U	�� �e	�� �e �w	�� �Y	�� ��	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� �b	�� �Y	�� �N	
�� ��	�� ��	�� �N	�� ��	�� ��	�� �~	�� �[	�� ��	
�� ��	�� �Y	�� �O	�� �� ��	�� ��	�� �~	�� ��	�� ��	
�� �t	�� �M	�� �{	�� �v	�@ ��	�A �@ ��	�A �T	�A �U �h	
�A �U ��	�A �� �M	�A �B	�A �[	�A �[ �W	�A �A	�A ��	�A �� �T	
�A ��	�A �@	�A ��	�A ��	�A �h	�A ��	�A ��	�A �N �O	
�A ��	�A �L	�A ��	�C ��	�C ��	�L ��	�P �@	�P ��	
�P �� �]	�P ��	�P �z	�P ��	�P ��	�P �� �a	�P �n	�R �� �s	
�S �S	�U �j �t	�U �a	�U ��	�U ��	�U ��	�U �O	�U ��	
�U ��	�U ��	�U ��	�U �t ��	�V ��	�W ��	�X �O	�Y ��	
�] ��	�] ��	�] ��	�] ��	�] ��	�] ��	�] �G	�] ��	
�a ��	�a �A	�b �@	�b ��	�b ��	�b �L	�b �x	�b �U	
�b �b	�b ��	�b ��	�b ��	�b ��	�b �o	�b �O	�h ��	
�h ��	�h �[	�h �b	�h �h	�h �~	�h ��	�h �i	�h ��	
�h �U	�h ��	�h ��	�j �j	�k �[	�k ��	�k �M	�n ��	
�n ��	�n �[ �b	�n ��	�n �b	�n �n	�n �n ��	�n ��	�n ��	
�n �e ��	�n ��	�o ��	�o ��	�p �U	�p �W	�p ��	�p ��	
�p �G	�p �G ��	�p ��	�p �Y	�p ��	�p ��	�p ��	�p ��	
�s ��	�w �o	�w �M	�y �n	�} �B	�~ ��	�~ ��	�~ �� �y	
�~ �~	�~ ��	�~ ��	�~ �� �e	�~ ��	�~ ��	�~ ��	�~ �_	
�~ ��	�� �� ��	�� ��	�� �F	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �@ ��	�� �@ �I	�� �w	�� ��	�� ��	�� ��	�� ��	
�� �I	�� �N	�� �@	�� �@ ��	�� �@ �I	�� �F	�� �H	�� �[	
�� �i	�� �i 	�� �i ��	�� �i �� 	�� �i ��	�� �h	�� �p	�� ��	
�� �U ��	�� �_	�� �S ��	�� ��	�� ��	�� �t	�� ��	�� �� ��	
�� ��	�� �o	�� �L	�� ��	�� �D �O	�� �I	�� �I ��	�� ��	
�� Ų ��	�� ų ��	�� ��	�� �@	�� �~	�� ��	�� ��	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� �R	�� �e	�� ��	
�� �b ��	�� ��	�� ��	�� �O	�� �� ��	�� ��	�� ��	�� ��	
�� �B	�� �]	�� �b	�� ��	�� ��	�� �D	�� ��	�� �O	
�� �O	�� �p	�� �v ��	�� �j	�� ��	�� ��	�� ��	�� �l	
�� ��	�� �O	�� ��	�� �q	�� ��	�� ��	�� �@ ��	�� �U ��	
�� ��	�� ��	�� ��	�� �h	�� ��	�� �� ��	�� ��	�� ��	
�� ��	�� �� ��	�� ��	�� �N	�� ��	�� �b	�� ��	�� ��	
�� �H	�� �u	�� ��	�� �� ��	�� ��	�� ��	�� �p	�� �G	
�� ��	�� �W	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� �p	�� ��	�� ��	�� �G	�� ��	�� �Z	�� �H	�� �L	
�� �]	�� �b	�� �O	�� ��	�@ �X	�@ ��	�A ��	�C ��	
�C ��	�C �n	�K �� �F	�K �o	�N �� �B	�N �� ��	�N ��	�N �� ��	
�O �H	�Q ��	�Y �w	�Y ��	�Y ��	�Y �O	�Y �i	�Y ��	
�Y �i	�Y ��	�Y ��	�Y ��	�Y �K	�Y ��	�Y �u	�Y �N	
�Y ��	�\ ��	�_ �h	�r �M	�s �s	�t ��	�� �w	�� ��	
�� �i	�� ��	�� ��	�� ��	�� �Y	�� ��	�� ��	�� �L	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �� ��	�� �� �W	�� ��	�� �� ��	�� �Y	�� �T	�� �B	
�� �n	�� �I	�� �I ��	�� �]	�� ��	�� ��	�� �b	�� �O	
�� ��	�� ��	�� �J	�� ��	�� �O	�� ��	�� ��	�� ��	
�� ��	�� �B	�� �[	�� �h	�� ��	�� �� �p	�� ��	�� �O	
�� ��	�C �@	�C �H	�C �� 	�C ��	�C ��	�C ��	�C �~	
�C �C	�C �u	�C ��	�C ��	�C �{	�C ��	�C �j	�C ��	
�F �F	�L �L	�M ��	�M �w	�M �M	�S �H	�S ��	�S �k	
�S �k ��	�S �o	�S �Q ��	�V �V	�e ��	�p �U	�p ��	�p ��	
�p �� �U	�p �@	�s ��	�� �H	�� �i	�� ��	�� ��	�� �Y	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� ��	�� ��	�� �� ��	�� �� ��	�� ��	�� �B	�� �i	
�� ��	�� �b	�� �S ��	�� ��	�� ��	�� �D	�� �N	�� �L	
�� ��	�� �M	�� ��	�� �� �W	�� ��	�� ��	�� ��	�� �k	
�� ��	�� �M	�� �}	�� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �� �W	�� �� ��	�� ��	�� �o	�� �H	�� �z	�� ��	
�� �p	�� �� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� �o	
�� �o ��	�� ��	�� ��	�� ��	�� �T �U	�� ��	�� ��	�� ��	
�� �@	�� �G	�� ��	�� �L	�� ��	�� ��	�� ��	�� �N	
�� �� ��	�� �F	�� ��	�� �a	�� ��	�� �� ��	�� �B	�� �Y ��	
�� �P	�� ��	�� ��	�B �P	�I �a	�I �I	�I ��	�I �P	
�I �P �P	�I �~	�I ��	�K �K	�M ��	�M ��	�N �N	�T �M	
�Z �Z	�] �]	�^ �O	�^ �l	�^ �R	�^ ��	�` �]	�` ��	
�e ��	�h �B	�l ��	�t ��	�u ��	�u �� �l	�u ��	�u ��	
�u �� �u	�u �� ��	�w ��	�w �w ��	�w �n	�w ��	�w ��	�w �M	
�w ��	�y ��	�| �B	�| ��	�~ ��	�~ �M	�~ ��	�� ��	
�� ��	�� ��	�� �n	�� ��	�� ��	�� �e	�� �^	�� ��	
�� �`	�� ��	�� �a	�� ��	�� ��	�� �j	�� �M	�� �M ��	
�� ��	�� �� �a	�� �� �a	�� �� �o	�� �v	�� �b ��	�� �i	�� ��	
�� �O	�� �\	�� �H	�� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �Y	�� ��	�� ��	�� ��	�� �Y	�� �n	�� �x	
�� �h	�� ��	�� ��	�� ��	�� �p	�� �O	�� �O �G	�� �j	
�� �~	�� ��	�� �� ��	�� ��	�� �M	�� ��	�� �~	�� ��	
�� ��	�G �Y	�G �u	�G �M	�P ��	�Y �M	�g �g	�i ��	
�o �M	�p �B	�p �G	�q �M	�u ��	�u ��	�x ��	�y �y	
�� ��	�� ��	�� �o	�� ��	�� �� ��	�� ��	�� �T	�� �� ��	
�� �� ��	�� ��	�� ��	�� ��	�� �D	�� ��	�� ��	�� ��	
�� �N	�� ��	�� ��	�� �B	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �F	�� �V	�� ��	�� ��	�� �Y	�� �� ��	�� ��	
�� ��	�� �~	�� ��	�� �L	�� ��	�� ��	�� ��	�� �� ��	
�� �i	�� ��	�� �� �|	�� ��	�� �]	�D ��	�D �{	�D �`	
�D �o	�E ��	�E ��	�E ��	�H �f	�H ��	�H �B	�K �i	
�K �O	�K �|	�P ��	�P ��	�P ��	�S ��	�U �� ��	�U �y ��	
�X ��	�_ ��	�_ �M	�b �M	�e 3 �u	�e �@ �~	�e �@ �u	�e �@ �g	
�e �T �u	�e ��	�e ��	�e ��	�e ��	�h ��	�h �� ��	�h �O	
�h ��	�i ��	�j �O	�j ��	�k �M	�z �z	�z �z �a	�z ��	
�| �|	�} �}	�� ��	�� ��	�� �s	�� ��	�� �� ��	�� �� ��	
�� ��	�� ��	�� ��	�� �� �~	�� ��	�� �� �a	�� �� ��	�� �M	
�� ��	�� �|	�� �| ��	�� �~	�� �A	�� ��	�� ��	�� ��	
�� �n	�� ��	�� �B	�� �� �a	�� �t	�� ��	�� �@	�� ��	
�� �J	�� ��	�� ��	�� �a	�� ��	�� ��	�� �|	�� ��	
�� ��	�� �Y	�� �M ��	�� �i	�� ��	�� �n	�� ��	�� �� �a	
�� �`	�� ��	�� ��	�� ��	�� �}	�� �O	�� ��	�� ��	
�� �z	�� ��	�� ��	�� ��	�� �X	�� ��	�� �W	�� ��	
�� ��	�B ��	�G ��	�G ��	�J �w	�J ��	�J ��	�J �D	
�J �M	�N ��	�O �@	�O �@ ��	�O �@ ��	�O ��	�O �� �O	�O �H	
�O �L	�O ��	�O �] ��	�O �b	�O ��	�O �_	�O �_ �|	�O ��	
�O �� ��	�O ��	�O ��	�O �G	�O ��	�O �� �F	�O �n	�O ��	
�Q ��	�Q ��	�Q �� �b	�Q �]	�Q ��	�T ��	�X �n	�� ��	
�� �F	�� ��	�� �� ��	�� ��	�� �D	�� �L	�� ��	�� �� ��	
�� ��	�� �� �K	�� ԣ	�� ԣ �l	�� �l	�� ��	�� �� ��	�� �� �a	
�� ��	�� ��	�� �B	�� ��	�� ��	�� �� ��	�� ��	�� ��	
�� �i	�� ��	�� �o	�� ��	�� �� ��	�� �� �a	�� �� ��	�� ��	
�� ��	�� �v	�� ��	�� �� ��	�� ��	�� �~	�� �U	�� �W �h	
�� ��	�� ��	�� �� �l	�� �n	�� ��	�� �O	�� �n	�� �a	
�� ��	�� �� �a	�� �M	�� �b	�� ��	�� ��	�� ��	�� ��	
�� ��	�I �a ��	�J ��	�P ��	�Y �� �M	�Y ��	�Y �G	�Y �D	
�Y �O	�Y �n	�l �M	�n ��	�n �� �O	�n �� �n	�n �� �M	�n ��	
�n �D	�n �O	�n ��	�p ��	�p ��	�t ��	�~ �M	�� ��	
�� �s	�� �Y	�� ��	�� ��	�� �{	�� �] ��	�� ��	�� ��	
�� ��	�� �u	�� ��	�� �]	�� �K	�� ��	�� ��	�� ��	
�� ��	�� �[	�� ��	�� ��	�� ��	�� �D	�� �� �p	�� �O	
�� �Y	�� ��	�� ��	�� �Y	�� �K	�� ��	�� �H	�� ��	
�� �{	�� ��	�� ��	�� ��	�� �n	�� ��	�� ��	�� �� �n	
�� �_ �B	�� ��	�� ��	�� ��	�� ��	�� �w	�� �h �W	�� �f ��	
�� ��	�� ��	�� �� �D	�� �O	�� ��	�A �A	�D �� ��	�I �Y	
�U �U	�e ��	�i �}	�t �@ �I	�t �I	�t �I ��	�u �a	�{ ��	
�} �} ��	�� ��	�� �N	�� �N �a	�� ��	�� �B	�� ��	�� �M	
�� �n	�� �M	�� �U	�� ��	�� ��	�� �u	�� ��	�� ��	
�� ��	�� �� ��	�� ��	�� �� ��	�� ��	�� �`	�� ��	�� �n	
�� ��	�� ��	�� �~	�� ��	�� ��	�� �� ��	�� ��	�� ��	
�� ��	�� �w	�K �K	�M �M	�S �a	�S ��	�S �N	�q �[	
�q ��	�q �o	�u ��	�u ��	�u �O	�u ��	�u ��	�y �y	
�} �f	�} ��	�� �b	�� ��	�� �`	�� ��	�� ��	�� ��	
�� �M	�� ��	�� ��	�� �� ��	�� �A	�� �_	�� ��	�� ��	
�� ��	�J ��	�Q ��	�S �S	�S �S �a	�U �f	�Z ��	�Z �� �O	
�Z ��	�Z �i	�Z �u	�Z �D	�Z �O	�Z ��	�Z ��	�_ ��	
�_ ��	�_ ��	�_ ��	�_ ��	�_ �X	�e ��	�e �F	�t �W	
�u ��	�u �q	�w ��	�~ �M	�� �F	�� �� �~	�� �D	�� ��	
�� �W	�� �L �L	�� ��	�� �F	�� �n	�� �}	�� �p	�� ��	
�� �Y	�� �N	�� ��	�� �k	�� ��	�� �M	�� ��	�� ��	
�� ��	�� ��	�� ��	�� �� �a	�� �� ��	�� ��	�� ��	�� ��	
�� ��	�� �n	�� ��	�� �G	�� �a	�� ��	�� ��	�� �M	
�� �Y	�� ��	�� ��	�� �� ��	�� ��	�� ��	�� �[	�� �P	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� �D	�� ��	
�� �W	�� ��	�� �~	�� �F ��	�� ��	�� ��	�� ��	�C �P	
�E ��	�E ��	�E �P	�H �P ��	�M �{	�M �v	�M ��	�N �H	
�N �i	�N ��	�N �b	�N ��	�N ��	�N ��	�N ��	�N ��	
�N �O	�N �n	�N �|	�` �~	�` ��	�` �`	�a ��	�a �i	
�a ��	�f �X	�j ��	�j ��	�j ��	�j ��	�o �H	�o �h	
�o ��	�o ��	�o �K	�o ��	�o �o	�o �W �L	�o �W	�q �p	
�q ��	�q ��	�q ��	�q ��	�q ��	�q �S	�q ��	�q ��	
�q �t	�q ��	�q �Y	�x ��	�x ��	�x ��	�y �y �M	�y �� �a	
�� ��	�� �p	�� �p �U	�� ��	�� �W	�� �U �h	�� �U ��	�� �f	
�� ��	�� ��	�� �s	�� ��	�� ��	�� ��	�� ��	�� �X	
�� ��	�� ��	�� �W ��	�� ��	�� ��	�� ��	�� �Y	�� ��	
�� �W	�� ��	�� ��	�@ ��	�@ ��	�M �@ ��	�M ��	�X �w	
�` ��	�` �]	�` �`	�j ��	�r �O	�r �a ��	�r �M	�v ��	
�v ��	�v ��	�v �M	�v �N	�v ��	�z ��	�z ��	�z ��	
�{ �w	�{ �b	�{ ��	�{ ��	�� �~	�� �� �I	�� �[	�� ��	
�� ��	�� �L	�� ��	�� �h	�� �U	�� �� ��	�� �C �C	�� 1 �u	
�� 2 �u	�� 3 �u	�� 4 �u	�� �@ �u	�� �G �u	�� �T �u	�� �| �u	�� �X	
�� ��	�� �[	�� �n	�� ��	�� �@	�� �[	�� �_	�� ��	
�� �~	�� ��	�� �� ��	�� �i	�� �s	�� �]	�� ��	�� ��	
�� �k	�� �f	�� ��	�� �� �O	�� ��	�� �p	�� �D	�B �H	
�B �b	�B ��	�B �B	�Q �H	�\ �h	�] ��	�] �b	�] �Y	
�e ��	�o �@	�o �@ ��	�o �H	�o �U	�o �j	�o ��	�o ��	
�o �H ��	�o �L	�o �i	�o �y	�o ��	�o ��	�o ��	�o �W	
�o �^	�o ��	�o ��	�o ��	�o ��	�o �A	�o ��	�o ��	
�o �B	�o ��	�o ��	�o ��	�o ��	�o ��	�o �M	�o ��	
�o �h	�o ��	�o ��	�o �O	�o �[	�o �q	�o ��	�o �M	
�o �a	�o �y	�o ��	�o �u	�o ��	�o ��	�o �i	�o ��	
�o ��	�o ��	�o �N �O	�o �T	�o �X	�o ��	�o �f ��	�o ��	
�o ��	�o ��	�o ��	�o ��	�o �| ��	�o ��	�o ��	�o ��	
�o �D	�o ��	�o �P	�o ��	�o �� ��	�o �� ��	�o ��	�o �l	
�o �r	�o ��	�o �g	�o ��	�o ��	�o ��	�o ��	�o ��	
�o �I	�o ��	�o ��	�o ��	�q �O	�q �d	�q �`	�q �q	
�q �L	�q ��	�s ��	�s �� ��	�s �W	�s �~	�s ��	�s �]	
�s ��	�s �L	�s �a	�s �s	�s �f	�s ��	�s �n	�s ½	
�s ��	�t �� ��	�v �@	�v ��	�v �r	�v �~	�v ��	�v �i	
�v �B	�v �B �a	�v ��	�v ��	�v ��	�v ��	�v ��	�v ��	
�v ��	�w ��	�w �I	�w ��	�w ��	�w ��	�y ��	�z ��	
�z �L	�� ��	�� ��	�� ��	�� �O	�� ��	�� �N	�� �Q	
�� ��	�� �P	�� ��	�� �M	�� ��	�� ��	�� �]	�� ��	
�� �M	�� ��	�� �h	�� ��	�� ��	�� �e	�� ��	�� ��	
�� ��	�� �n	�� ��	�� ��	�� ��	�� ��	�� �U	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	
�� �W	�� �M	�� ��	�� ��	�� �i ��	�� ��	�N ��	�N �a	
�N �b	�N ��	�N ��	�N ��	�N ��	�N �O	�N �|	�N ��	
�X �G	�X ��	�X ��	�X ��	�X �g	�_ ��	�` ��	�` ��	
�` �`	�` ��	�` �u	�` �n	�c �� ��	�c �N	�e �Y	�i �i	
�n �M	�� �X	�� ��	�� ��	�� ��	�� �_	�� ��	�� �� ��	
�� ��	�� �V	�� �_	�� �Q	�� �g	�� ��	�� ��	�� �M	
�� ��	�L ��	�L �� �j	�L ��	�L ��	�L ��	�L �H	�L �i	
�L ��	�L �p	�L ��	�L ��	�L �� �G	�L �k	�L �D	�L �G	
�L ��	�L �e	�L �q	�L �� ��	�L ��	�L ��	�L �� �a	�L ��	
�L �� ��	�L ��	�L ��	�L ��	�L �v	�M �Z	�M �]	�M ��	
�M �h	�M ��	�S �i	�S ��	�h �[	�n ��	�o ��	�o ��	
�o �i	�o ��	�w ��	�w �� ��	�w ��	�w �O	�y �[	�y �@	
�y ��	�y ��	�y ��	�y �\	�y �y	�y ��	�y �L	�{ ��	
�� �@ �|	�� �H	�� �U	�� ��	�� ��	�� �| ��	�� ��	�� ��	
�� �G	�� ��	�� ��	�� �f	�� ��	�� ��	�� �D	�� ��	
�� ��	�� �L	�� ��	�� �z	�� ��	�� ��	�� �[	�� ��	
�� ��	�� �M	�� ��	�� ��	�� ��	�T �M	�T �T �M	�V �[	
�V �� �V	�V �o	�W �L	�X ��	�X ��	�X ��	�X ��	�X ��	
�^ ��	�^ �� ��	�i �@ �B	�i ��	�i ��	�} �l	�} �o �X	�} �h	
�� ��	�� ��	�� �@	�� �C	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �� ��	�� ��	�� �Q	�� �K	�� �y	�� �a	�� ��	
�� �D	�� �I	�� �n	�� �o	�� �j	�� ��	�� �u	�� ��	
�� �� ��	�� ��	�� ��	�� ��	�� �O	�� ��	�� �[	�� ��	
�� �N	�� ��	�� ��	�� ��	�� ��	�� �� ��	�� ��	�� ��	
�� �j	�F ��	�F ��	�L �A	�L �T	�L �L	�N �� ��	�Q �� ��	
�Q ��	�Q ��	�Q ��	�Q �� �M	�U �[	�U ��	�U �� �U	�U �q	
�U �o	�U ��	�V �[	�[ �q	�d �� �n	�f �f	�n ��	�p �� �W	
�s ��	�s ��	�t ��	�t �a	�t �a ��	�t ��	�t �t	�| �� �|	
�| ��	�| �b	�| ��	�| �_	�| ��	�| �|	�~ �w	�~ �� ��	
�~ ��	�~ ��	�~ �` �|	�� �F	�� �O	�� ��	�� ��	�� ��	
�� ��	�� �n �a	�� ��	�� �� �a	�� ��	�� �M	�� ��	�� �z	
�� ��	�� ��	�� ��	�� ��	�� �O	�� ��	�� ��	�� ��	
�� ��	�� �~	�� �@	�� �Y	�� ��	�� ��	�� ��	�� �x	
�� ��	�� ��	�� ��	�� �M	�� ��	�� �Y	�� ��	�� ��	
�@ ��	�I ��	�U �@	�U �H	�U ��	�U ��	�U ��	�U ��	
�U �x	�U �x ��	�U �� ��	�U �M	�U ��	�U �i	�U ��	�U �U	
�U ��	�` �q	�` �`	�g ��	�g ��	�g �~	�g �`	�g �N	
�g �L	�s �_	�v �N	�� �h	�� ��	�� ��	�� ��	�� �M	
�� �� ��	�� ��	�� �� �q	�� ��	�� ��	�� �|	�� ��	�� �[	
�� ��	�� �J	�� �M	�� ��	�� ��	�� �W	�� ��	�� ��	
�� �J	�� ��	�� �A	�@ ��	�B ��	�E �i	�E �B	�F ��	
�L �_	�L �h	�L ��	�L ��	�L ��	�L ��	�O ��	�j �s	
�j ��	�j �N	�j �]	�j ��	�j �J	�j �g	�s �I	�w ��	
�w ��	�w �w	�w �p	�w ��	�w ��	�y ��	�y �M	�� �O	
�� �O	�� ��	�� �M	�� ��	�� ��	�� ��	�� �a	�� �b	
�� �h	�� �L	�� ��	�� �L	�� �~	�� ��	�� ��	�� ��	
�� ��	�� �]	�B �M	�C �C ��	�C ��	�I �O	�I ��	�I �M	
�N ��	�c ��	�p �M	�u �^ �h	�w ��	�| �]	�� ��	�� ��	
�� ��	�� ��	�� �h	�� �]	�� ��	�� �i ��	�� ��	�� ��	
�� �q	�� ��	�� ��	�� ��	�� �O	�� ��	�� �{	�� �M	
�� �U ��	�� ��	�� �O	�� �W	�� ��	�� �� ��	�� ��	�D ��	
�O �_ �T	�P ��	�P ��	�P �|	�W ��	�W �N	�\ �]	�t �K	
�{ ��	�} ��	�� �� �w	�� ��	�� �� ��	�� �O	�� �u ��	�� ��	
�� �M	�� ��	�� ��	�� ��	�� ��	�� ��	�� ��	�� �N	
�� �n	�� �D	�� �� �a	�� �D	�� �n	�� ��	�� �O	�� �n	
�� ��	�� �x ��	�� �� ��	�� ��	�A �f	�A ��	�A ��	�A �Y	
�F �n	�H �H	�M ��	�M ��	�M �� ��	�M �M	�N �� ��	�N �N	
�P �q	�P �P	�P ��	�T �K	�T ��	�T �T	�W �[	�W ��	
�W ��	�W �]	�n �M	�s �[	�s ��	�v �T	�� �M	�� ��	
�� �O	�� ��	�� �q	�� �P �P	�� �� ��	�� ��	�� ��	�� �B	
�� �i	�� ��	�� �M	�� �f �f	�� ��	�� �b	�� ��	�� �I �I	
�� ��	�T �O	�T �M	�T ��	�a ��	�w �B	�� �M	�� �f	
�� ��	�� �h	�� ��	�� ��	�� ��	�� �� ��	�� �y	�� ��	
�� �f	�� ��	�� ½	�A �~	�A ��	�A ��	�A �� �H	�A ��	
�E ��	�G ��	�a ��	�a ��	�� �O	�� �i ��	�� ��	�� ��	
�� �t	�� �q	�� ��	�� ��	�� ��	�� ��	�� �j	�� �O	
�� ��	�� �i	�� �M	�� ��	�� �P	�� �H	�� ��	�� ��	
�� ��	�� �F ��	�� ��	�� �H	�� �H	�� �x	�� �z	�� �� �p	
�� ��	�� ��	�� ��	�� �D	�� ��	�� �n	�� ��	�� ��	
�� �[	�� �V	�� ��	�� �[	�� �~ ��	�W �O	�W ��	�W �� ��	
�W �W	�n ��	�� �f	�� ��	�� ��	�� ��	�� ��	�� ��	
�� ��	�� �L	�� ��	�� ��	�H �f	�H ��	�H ��	�H �a	
�H ��	�H �Y	�H �B	�H ��	�H ��	�H ��	�H ��	�H ��	
�H �B	�H ��	�H ��	�I ��	�K �� ��	�K ��	�K �� ��	�N �a	
�N �M	�W ��	�W �W	�Z �M	�b �M	�q �q	�� ��	�� �� ��	
�� ��	�� �� ��	�� ��	�� ��	�� �_	�� ��	�� ��	�� ��	
�� ��	�� �O	�� �M	�� ��	�� ��	�� �B	�� ��	�� �{	
�� �o	�� �w	�� �^	�� ��	�� �M	�� �n	�� �x	�� �Y	
�F ��	�P �P	�` ��	�` �@	�` �� ��	�` �O	�` �p	�` �o	
�` �|	�` ��	�` �k	�a �O	�a ��	�a ��	�a ��	�a ��	
�a �M	�p �W	�p �X	�p �L	�x ��	�{ �h	�{ ��	�{ �M	
�{ ��	�{ �O	�{ ��	�{ �}	�{ ��	�{ ��	�| �Z	�| ��	
�| ��	�| �a	�� �o	�� �M	�� ��	�� �M	�� ��	�� �� �p	
�� �� �O	�� �i �H	�� ��	�� �O	�� �n	�� �V	�� ��	�� �B	
�� ��	�� �M	�� ��	�� �� �a	�� �h	�� �M	�� ��	�A ��	
�S �o ��	�X �R	�_ �M	�_ ��	�k ��	£ �M	§ �� �a	² �� ��	
² ��	�� �H	�� ��	�� ��	�� �G	�� ��	�� ��	�� ��	
�� ��	�� ��	�� ��	�� ��	�� ��	�[ ��	�l ��	ê ��	
í �B	�� ��	�� �M	�� ��	�� ��	�� ��	�� �� ��	�� �H	
�� �K	�� ��	�� �� �G	�� �O	�� ��	�� �D	�� �D ��	�A �y	
�X �X	�Y �[	�Y ��	�d �y	�v ��	�~ ��	�~ ��	ı �o	
�� �M	�� ��	�� ��	�� �M	�� ��	�� �M	�F �q	�F �M	
�F ��	�F �� ��	�F �F	�K �w	�R ��	�R ��	�S ��	�T �T	
�Z �a	�Z �M	�Z �M ��	�f �M	�k �M	�w �M	ť ��	ť ��	
Ū ��	Ų ��	ų ��	�� ��	�� ��	�� ��	�� �X	�� ��	
�� �Y	�� �M	�� �L	�J �M	�\ ��	�\ �B	�\ ��	�J ��	
�` ��	�� ��	�{ �M	�{ �{	�� ��	�� �D	�` �M	�p ��	�� �e	�Y �o
�p �p	�� ��	�� ��	�� ��	�� ��	�� �� �@	�� �o ��
�] ��	�] �b	�� ��	�W �z	�e �z	�� ��	�� ��	�� ��	�� ��
�� ��	�p �P	�� �~	�� ��	�i ��	�p ��	�� ��	�A ��	�� ��
�@ ��
�U �C
�� ��	�� ��
�S �w	�S �O
�� �W	�� �� �W
�t ��	�A �Q ��

1;

