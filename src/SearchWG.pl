#!/usr/bin/perl -s
# Given a term, this program search WG and retrieve date, title, and content
# indexed by WG

    use vars;  use strict;
    use Win32::OLE;
    use SAMtool::Progress; # if you do not have SAMtool, remark these 2 lines
	my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );

    my $stime = time();
    my $wg; # a global var to hold attributes
    &InitWG(); # set $me
# perl -s SearchWG.pl -Os �֥| > PowerPlantFour.txt
    &SearchWG(@ARGV) if $main::Os;
    print STDERR "It takes ", time() - $stime, " seconds\n";
    exit;

sub InitWG {
    $wg = Win32::OLE->new('Topology.Genie20') ||
            die "Cannot Create Genie20 COM object\n";
    $wg->SetCodeType(1);
    if($wg->IsSystemInitialized == 0) {
#        $wg->InitializeSystem("kyosuka","","HRKL-78DJ-CR6PNDTF-2D6O62GI");
        $wg->InitializeSystem("\n\nHRKL-78DJ-CR6PNDTF-2D6O62GI\n1"); # 2007/01/30
# �Ĥ@�欰�ϥΪ̦W��(�i����J)�F�ĤG�欰���q�W��(�i����J)�F
# �ĤT�欰�Ǹ��F�ĥ|��1=�եΦw��,0=�����w�� (�L�ĥ|����P�����w��)
    }
    my($ver, $vern, $other) = split /\n/, $wg->GetVersion(), 3;
    print STDERR "WebGenie Ver.: '$ver', $vern\n"; 
}


sub SearchWG {
	my($t) = @_; 	my($N, $RN);
	my $MaxIndexNo = $wg->GetIndexNo();

	$wg->ClearQueryIndex(); # �M�����e���d�߯��ޡA�M���᤺�w���d�ߩҦ�������
#	$wg->AddQueryIndex($main::Oidx);       #�˯���Ʈw
	$wg->SetSearchMode(0); # �˯��Ҧ�: 0=��T�d�ߡB1=�D�D�d�ߡB2=�ҽk�d��
	$wg->SetQuerySentence($t);       #�˯��r��, ��X�Ҧ��ӯ��ު����
	$wg->SetQueryDocRange(0, 99999999); # �w�]��0-255,�N��אּ������X
	$wg->Search(0,0);                       #���Ұʴ��ܵ�
	$N = $wg->GetDocNo(); $RN = $wg->GetRealDocNo();
	warn "GetDocNo=$N, GetRealDocNo=$RN\n" if $N != $RN; # 2007/11/10
	print STDERR "Retrieving $N documents ...\n";
	
	my($Did, $I, $J, $percent);
	
	$wg->ClearBatchGetDocFieldContent();
	for ($I = 0; $I < $N; $I++) {
		$Did = $wg->GetDocID($I);  # ���o���ID
		$wg->BatchGetDocFieldContent(0,0,$Did,'$4$'); # $4$ = ������ɶ�
		$wg->BatchGetDocFieldContent(0,0,$Did,'$8$'); # $8$ = �����D
#		$wg->BatchGetDocFieldContent(0,0,$Did,'$7$'); # $7$ = ���W��
#		$wg->BatchGetDocFieldContent(0,0,$Did,'$10$'); # $10$ = �����W
#		$wg->BatchGetDocFieldContent(0,0,$Did,'$9$'); # $9$ = ���Summary
#		$wg->BatchGetDocFieldContent(0,0,$Did,'$11$'); # $11$ = ��󤺤�
#last
		$percent = $pro->ShowProgress($I/$N, $percent);
	}
	$percent = $pro->ShowProgress($I/$N, $percent);
	my($date, $title, $content, $filename, $docname, $summary, $p);
	my($year, $month, $day);
	$wg->StartBatchGetDocFieldContent();
	for ($I=0, $J=0; $I < $N; $I++) {
		$Did = $wg->GetDocID($I);  # ���o���ID
		$date = $wg->GetBatchDocFieldContent($J++);
		$title = $wg->GetBatchDocFieldContent($J++);
#		$docname = $wg->GetBatchDocFieldContent($J++);
#		$filename = $wg->GetBatchDocFieldContent($J++);
#		$summary = $wg->GetBatchDocFieldContent($J++);
#		$content = $wg->GetBatchDocFieldContent($J++); # did not work
#		$content = $wg->GetDocContent(0, 0, $Did, $filename); # not work
#		$content = $wg->GetDocumentText($filename, 1, -1); # get nothing
		$content = $wg->GetAbstractText(0, $Did); # get "title 0x01content"
		$p=index($content, chr(0x01));
		$content = substr($content, $p+1); # Get string after title
#print STDERR "Position before content: $p\n";
#		($day, $content) = split(/chr(0x01)/e, $content); # did not work
#print STDERR "Did=$Did\nDate=$date\ntitle=$title\ndocname=$docname\n",
#  "filename=$filename\nsummary=$summary\ncontent=$content\nday=$day\n";
#		($year, $month, $day) = split(/[\/ ]/, $date); # format: '2000/12/01 00:00:00'
#		$date = $year.sprintf("%02d", $month).sprintf("%02d", $day);
		($date, $day) =  split /\s/, $date;
		$title =~ s/\s+/ /g;
		$content =~ s/\s+/ /g;
		print "$date\t�C\t$title\t�C\t$content�C\n�C\n";
		$percent = $pro->ShowProgress($I/$N, $percent);
#last if $I>4;
	}
	$percent = $pro->ShowProgress($I/$N, $percent);
}
