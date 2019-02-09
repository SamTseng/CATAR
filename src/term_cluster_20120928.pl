#!/usr/bin/perl -s
# This program is copied and modified from D:\demo\SAM\CareerSegWord\filter_dic.pl
# This program is used in the following scenario:
# 一、將  38 萬篇中文新聞以 WG 3.25 建立索引 ：138 分鐘
# 二、利用 API 將所有3百萬個詞彙，倒出 71 萬個有效詞 ：約 3300 秒
# 三、將71 萬個有效詞按照其出現篇數由大到小排序 ：約 100 秒
# 四、把前1000個詞彙的關聯提示詞倒出來，
#      每個詞視為一份文件的標題，其所有（最多64個）關聯詞
#      視為該詞之文件內容：約 230 秒
# 五、進行此 1000 篇文件的 歸類 ：約 1200 秒
# 六、利用不同參數得到不同歸類結果：約 13 秒
# 
    use SamOpt;  &SamOpt();
    use vars;  use strict;
    use SAMtool::Progress;
    use SAMtool::Stopword;
    use SAMtool::Stem;
    use Cluster;
    use Win32::OLE;
    my $Stop = Stopword->new();
    my $me; # a global var to hold attributes

    my $stime = time();
    &InitWG(); # set $me
# perl -s term_cluster.pl -Oindex arg_idx_words.txt
    &DumpIndexTerms(@ARGV) if $main::Oindex;

# perl -s term_cluster.pl -Osort WGindexWords.txt >WGterms.txt
    &SortTerms(@ARGV) if $main::Osort;
    
# perl -s term_cluster.pl -Orw -OminDF=5 -OmaxDF=2166 -Oidx=File [-OminRT=3] WGterms.txt > WG_RKterms.txt
    &GetRelatedWords(@ARGV) if $main::Orw;

# perl -s term_cluster.pl -Orw_del -OminDF=10 -OmaxDF=10000 -OminRT=3 ..\Result\arg\arg_keys_rw.txt > ..\Result\arg\arg_keys_rw2.txt
    &RemoveKeysWithoutRT(@ARGV) if $main::Orw_del;

# perl -s term_cluster.pl -Oti -Ophrase -Oidx=NTCIR3 -OminTI=1 ..\Result\NTCIR3\NTCIR3_keys_rw.txt > ..\Result\NTCIR3\NTCIR3_keys_rw_ti.txt
    &Filter_out_non_title_keywords(@ARGV) if $main::Oti;
    
    &SeiveSelectedTerms(@ARGV) if $main::Oselected; # 2009/11/23 not finished...

# perl -s term_cluster.pl -Oclu -Oct_low_tf=0 -Odebug -Oall -OminDF=50 -OmaxDF=2000 term term WG_RKterms.txt > term\term.html
# perl -s term_cluster.pl -Oclu -Oct_low_tf=0 -Odebug -Oall -OkeyOnly Legal ..\Result\Legal ..\Result\Legal\Legal_kr.txt > ..\Result\Legal\krOnly.html
    &TermCluster(@ARGV) if $main::Oclu;

# perl -s term_cluster.pl -Olabel -OminCut=0.5 WGidxName term_cluster.html > doc_cluster.html
# perl -s term_cluster.pl -Olabel -OcluTerms WGidxName term_cluster.html > cluster_terms.html
    &AssignDoc2Cluster(@ARGV) if $main::Olabel;
    
#perl -s term_cluster.pl -Ots -OminDF=3 -OmaxDF=25500 -Omonth -Oidx=pub ..\Result\pub\pub_idxtm_s.txt "200012 200101 200102 200103" > ..\Result\pub\pub_kts.txt
    &GetKeyword_TimeSeries(@ARGV) if $main::Ots;

# perl -s term_cluster.pl -Ofil D:\STPI\2008_Project\data\product.txt ..\Result\InfoBank\InfoBank_kts_trend.txt > ..\Result\InfoBank\InfoBank_kts_trend_product.txt
    &Filter_Keyword_TimeSeries_By_Selected_Term(@ARGV) if $main::Ofil;
    print STDERR "It takes ", time() - $stime, " seconds\n";
    exit;

sub InitWG {
    my $wg = Win32::OLE->new('Topology.Genie20') ||
            die "Cannot Create Genie20 COM object\n";
    $wg->SetCodeType(1);
    if($wg->IsSystemInitialized == 0) {
#        $wg->InitializeSystem("kyosuka","","HRKL-78DJ-CR6PNDTF-2D6O62GI");
        $wg->InitializeSystem("\n\nHRKL-78DJ-CR6PNDTF-2D6O62GI\n1"); # 2007/01/30
# 第一行為使用者名稱(可不輸入)；第二行為公司名稱(可不輸入)；
# 第三行為序號；第四行1=試用安裝,0=正式安裝 (無第四行視同正式安裝)
    }
    my($ver, $vern, $other) = split /\n/, $wg->GetVersion(), 3;
    print STDERR "WebGenie Ver.: '$ver', $vern\n"; 
    $me->{'wg'} = $wg;
}

sub DumpIndexTerms {
    my($IdxWordFile) = @_; my($stime, $n);
    $stime = time();
#    $n = $seg->DumpWGindexWords(0, 'WGindexWords.txt');
#    $n = &DumpWGindexWords(0, 'WGindexWords.txt');
    $n = &DumpWGindexWords(0, $IdxWordFile);
    print STDERR "It takes ", time()-$stime, " seconds to dump $n index words\n";
    exit;
}

# This function is copied from BasicSegWord.pm
sub DumpWGindexWords {
#    my($me, $iid, $OutFile) = @_;  
    my($iid, $OutFile) = @_;  
    my($wg, $term_cnt, $i, $t, $d, $info, $df, $tid, $percent, $n);
    $wg = $me->{'wg'};
    open F, ">$OutFile" or die "Cannot write to file:'$OutFile'.\n$!";
    $term_cnt = $wg->GetTermNo();  $percent = 0;
    my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    print STDERR "There are $term_cnt terms\n";
    for ($i = 0; $i < $term_cnt; $i++) {
	$percent = $pro->ShowProgress($i/$term_cnt, $percent);
        $d = $wg->ShouldKeywordDisplay($i);
        $t = $wg->GetKeywordString($i);
        next if ($t eq '');
#        if ($t eq '') { print STDERR "i=$i, t='$t'\n";  next; }
        $tid = $wg->GetKeywordID($t);
        print STDERR "i=$i, tid=$tid, t='$t'\n" if $tid != $i;
        $info = $wg->GetTermDocInfo($tid, $iid);
        if ($info =~ /^(\d+),/) { $df = $1; } else { $df = -1; }
        next if $df <=0;
	print F "$t\t$d\t$df\n"; $n++;
    }
    $percent = $pro->ShowProgress($i/$term_cnt, $percent);
    close(F);
    return $n;
}

# Use option -Opos=EngWordPos.txt
sub SortTerms {
    my($t, $w, $show, $df, %T, @T, $rEngWordPos);
    if (-r $main::Opos) { $rEngWordPos = &ReadWordPos($main::Opos); }
    my ($i, $j) = (0, 0);
    while (<>) {
    	chomp; $i++;
    	($t, $show, $df) = split /\t/, $_;
    	next if $show == 0;
    	next if $t =~ /[^aeiou]ed$/; # if passive tense
    	$w = Stem::stem(lc $t);
    	next if defined $rEngWordPos->{$w} and $rEngWordPos->{$w} ne 'N';
    	$T{$t} = $df;  $j++;
    }
    @T = sort {$T{$b} <=> $T{$a} } keys %T;
    foreach $t (@T) {
    	print "$t\t$T{$t}\n";
    }
    print STDERR "There are $i terms before sorting and $j terms after sorting.\n";
}

sub ReadWordPos {
    my($f) = @_;  my($w, $pos, %W);
    open F, $f or die "Cannot read file:'$f'";
    while (<F>) {
    	chomp; ($w, $pos) = split ' ', $_;
    	$W{$w} = $pos;
    }
    close(F);
    return \%W;
}

# use option -Omin, -Omax, -Oidx, -OminRT (minimum number of related terms)
sub GetRelatedWords {
    my($i, $j, $t, $df, $wg);
    $wg = $me->{'wg'}; # set Global var.
    $wg->ClearQueryIndex(); # 清除之前的查詢索引，清除後內定為查詢所有的索引
    $wg->AddQueryIndex($main::Oidx);       #檢索資料庫
    ($i, $j) = (0, 0);
    while (<>) {
    	chomp; $i++; 
    	($t, $df) = split /\t/, $_;
    	next if $df <$main::OminDF;
    	next if $main::OmaxDF > 0 and $df>$main::OmaxDF;
    	$j += &PrintRelatedTerms($wg, $i, $t, $df);
    	print STDERR "." if $i%100 == 0;
    }
    print STDERR "\nThere are $i terms and $j of them have qualified related terms.\n";
}

# Use options: -OminDF, -OmaxDF, -OminRT (minimum number of related terms)
sub PrintRelatedTerms {
    my($wg, $ith, $t, $df) = @_;
    my($i, $j, $n, $w, @RT, @KT, $wdf, $nkw, $iw, @T);
    $wg->SetSearchMode(0); # 檢索模式: 0=精確查詢、1=主題查詢、2=模糊查詢
    $wg->SetQuerySentence($t);       #檢索字串
    $wg->SearchKeyword(1,1);                       #啟動提示詞

    $n = $wg->GetRelatedKeywordNo();   #取得關聯提示詞數目
#print STDERR "t=$t, n=$n\n";
    for($i=0; $i<$n; $i++) {
	$w = $wg->GetRelatedKeyword($i);	#取得關聯提示詞字串
# delete those terms which contain the stop words
    	@T = map {($_=~/^\w/)?Stem::stem(lc $_):$_} split ' ', $w;
    	$iw = join ' ', @T; # index term may repeat after stemming
    	next if $iw =~ /__/; # 2005/06/26
    	next if $iw =~ /\d$/; # end with a digit, 2005/08/20
	next if $Stop->IsESW($iw);
	next if $Stop->IsESW(substr($iw, 0, index($iw, ' '))); # 2005/06/19
	next if $Stop->IsESW(substr($iw, rindex($iw, ' ')+1, length($iw))); 
	$wdf = $wg->GetRelatedKeywordDocNo($i);#取得關聯提示詞的出現篇數
    	next if $wdf < $main::OminDF;
    	next if $main::OmaxDF > 0 and $wdf>$main::OmaxDF;
#	next if $wdf > $df; # only narrow terms
	push @RT, "$w\t$wdf";
    }
=comment
    $n = $wg->GetKeywordNo();   #取得動態分類提示詞數目
    $nkw = 0;
    for($i=0; $i<$n; $i++) {
	$w = $wg->GetKeyword($i);	#取得動態分類提示詞字串
	$wdf = $wg->GetKeywordDocNo($i);#取得動態分類提示詞的出現篇數
#	$nkw++; next if $nkw >= 12;
	push @KT, "$w\t$wdf" if index($w, $t)>-1; # only narrower terms 
    }
=cut
    my $rt = ($main::OminRT<=0)?1:($main::OminRT); # 2007/10/15
    if (@RT >= $rt) { $j++;
	print "$ith : $t : $df : ", join("\t", @RT), "\n";
#	print "$ith : $t : $df : ", join("\t", @KT), "\n";
    }
    return $j; # return number of terms having qualified related terms
}


# term_cluster.pl -Orw_del -OminDF=10 -OmaxDF=10000 -OminRT=3 ..\Result\arg\arg_keys_rw.txt > ..\Result\arg\arg_keys_rw2.txt
# Use option $OminDF, $OmaxDF, $OminRT
sub RemoveKeysWithoutRT {
    my($id, $title, $df, $text, %RT, @RT, $r, $rdf, $i);
    while (<>) {
    	chomp;
	($id, $title, $df, $text) = split / : /, $_;
	next if $text =~ /^\s*$/;
	next if $df < $main::OminDF; # skip terms with low DF
	next if $main::OmaxDF>0 and $df > $main::OmaxDF;
	@RT = split /\t/, $text;
	$text = '';
	for ($i=1; $i<@RT; $i+=2) {
	    next if $RT[$i] < $main::OminDF;  # skip RT with low DF
	    next if $main::OmaxDF>0 and $RT[$i] > $main::OmaxDF;
	    $text .= $RT[$i-1]."\t$RT[$i]\t";
	}
	chop $text; # chop off last tab
	next if $text eq '';
	next if ($text =~ tr/\t/\t/)/2 < $main::OminRT;
	print join(" : ", $id, $title, $df, $text), "\n";
    }
}

# 2009/11/23 Not finished....
# Given a selected terms in a file (e.g., Nations3.txt), 
#       an inverted file (e.g., Inv.txt)
# Output the inverted file with only those selected terms remained
sub SeiveSelectedTerms {
    my($SelectedFile, $InvF) = @_;  my($t, @PTG, %SelectedTerms);
    # Read selected terms into %SelectedTerms
    
    while (<IN>) { chomp;
    	($t, @PTG) = split /\t|,/, $_;  # forest	1726,2,1763,2,
    	next if not $SelectedTerms{$t};
    	print "$_\n";
    }
}


# term_cluster.pl -Oti -Ophrase -Oidx=NTCIR3 -OminTI=1 ..\Result\NTCIR3\NTCIR3_keys_rw.txt > ..\Result\NTCIR3\NTCIR3_keys_rw_ti.txt
# use options: -Ophrase -Oidx, -OminTI
sub Filter_out_non_title_keywords { 
    my($KW_RT_File) = @_;
    my($id, $kw, $kwdf, $rest, $rn, $i, $line, $tfn, $percent, $df, $minTI);
    my $wg = $me->{'wg'}; # set Global var.
    $wg->ClearQueryIndex(); # 清除之前的查詢索引，清除後內定為查詢所有的索引
    $wg->AddQueryIndex($main::Oidx);       #檢索資料庫
    $wg->SetSearchMode(0); # 檢索模式: 0=精確查詢、1=主題查詢、2=模糊查詢
    ($tfn, $rn, $i) = (0, 0, 0);
    open F, "$KW_RT_File" or die "Cannot read file:'$KW_RT_File'\n";
    while (<>) { $tfn++; }
    close(F);
    my $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    print STDERR "There are $tfn keywords\n";
    open F, "$KW_RT_File" or die "Cannot read file:'$KW_RT_File'\n";
    $minTI = ($main::OminTI<=0)?0:$main::OminTI;
    while ($line = <F>) {
    	if ($line =~ / : /) {
# format : '24282 : OVS : 5 : ECP	13	fence	29	Data	6985'
	    ($id, $kw, $kwdf, $rest) = split / : /, $line;
    	} else {
# format : '廠商	3346'
	    ($kw, $kwdf) = split /\t/, $line; chomp $kwdf;
    	}
	$rn++; # record number processed
# Now Search WG to see if it appear in the title
	if ($main::Ophrase) { # if only phrase are needed
	    if ($kw =~ /\W/) {# for terms contains Chinese
		next if length($kw)<=4; # skip if only two-character terms
	    } else {
		next if ($kw =~ tr/ / /) <= 0; # skip if non-phrase
	    }
	}
	$wg->SetQuerySentence('$8$:' . $kw);   #只查詢標題
	$wg->Search(0,0);
	$df = $wg->GetDocNo();
#print STDERR "idx=$main::Oidx, kw=$kw, df=$df\n";
	next if $df <= $minTI; # skip non-title terms or those too few in titles
	print $line;
	$i++;
	$percent = $pro->ShowProgress($rn/$tfn, $percent);
    } # End of while (<F>) {
    $percent = $pro->ShowProgress($rn/$tfn, $percent);
    close(F);
    print STDERR "No of keywords: $rn, number of title keywords: $i.\n";
}


sub Filter_Keyword_TimeSeries_By_Selected_Term {
    my($TermFile, $KeyTrend) = @_;  my($term, $df, $r, %Term);
#print STDERR "$TermFile, $KeyTrend\n";
#    my $seg = SegWord->new( { 'WordDir'=>'SAM/word' } );
    open F, $TermFile or die "Cannot read file:'$TermFile'";
    while (<F>) { chomp; 
#	$Term { join(' ', @{$seg->Tokenize($_)}) } = 1; 
	$Term{$_} = 1;
    }
    close(F);
    open K, $KeyTrend or die "Cannot read file:'$KeyTrend'";
    while (<K>) { 
    	if (/^term\t/) { print; next; } chomp; 
# term	df	b	b1	type	200505	200506	
	($term, $df, $r) = split /\t/, $_;
	next if not $Term { $term }; 
	print "$_\n";
    }
    close(K);
    
}

#-------------------- &GetKeyword_TimeSeries() ------------------------
# perl -s term_cluster.pl -Ots -OminDF=3 -OmaxDF=25500 -Omonth -Oidx=pub 
#  ..\Result\pub\pub_idxtm_s.txt "200012 200101 200102 200103" > ..\Result\pub\pub_kts.txt
# use option -Omin, -Omax, -Oidx, -OminRT (minimum number of related terms)
sub GetKeyword_TimeSeries {
    my($File, $DateSeries) = @_;    
    my($tfn, $rn, $i, $percent, $pro, $rDid2Date, $line, $df, $wg, $Iid);
    my($id, $kw, $kwdf, $rest, @DateSeries, $rDid2PK, $rDid2Title);
    @DateSeries = split ' ', $DateSeries;
    $wg = $me->{'wg'}; # set Global var.
    $Iid = &IndexName2ID($wg, $main::Oidx);
    ($rDid2Date, $rDid2PK, $rDid2Title) = &GetDoc_Date_PK_Title($wg, $Iid, $main::Oidx);
    $wg->ClearQueryIndex(); # 清除之前的查詢索引，清除後內定為查詢所有的索引
    $wg->AddQueryIndex($main::Oidx);       #檢索資料庫
    ($tfn, $rn, $i) = (0, 0, 0);
    open F, "$File" or die "Cannot read file:'$File'\n";
    while (<F>) { $tfn++; }
    close(F);
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'line'} );
    print STDERR "There are $tfn keywords\n";
    open F, "$File" or die "Cannot read file:'$File'\n";
    print "term\tdf\t", join("\t", @DateSeries), "\n"; # print out Field name
    while ($line = <F>) {
    	if ($line =~ / : /) {
# format : '24282 : OVS : 5 : ECP	13	fence	29	Data	6985'
	    ($id, $kw, $kwdf, $rest) = split / : /, $line;
    	} else {
# format : '廠商	3346'
	    ($kw, $kwdf) = split /\t/, $line; chomp $kwdf;
    	}
	$rn++; # record number processed
	$percent = $pro->ShowProgress($rn/$tfn, $percent);
    	next if $kwdf <$main::OminDF;
    	next if $main::OmaxDF > 0 and $kwdf>$main::OmaxDF;
    	$i++;
    	&PrintTimeSeries($wg, $kw, $kwdf, $Iid, $rDid2Date, \@DateSeries);
    } # End of while (<F>) {
    $percent = $pro->ShowProgress($rn/$tfn, $percent);
    close(F);
    print STDERR "Extracting time series for $i (out of $tfn) keywords.\n";
}

# Use options: -OminDF, -OmaxDF, -OminRT (minimum number of related terms)
sub PrintTimeSeries {
    my($wg, $w, $kwdf, $Iid, $rDid2Date, $rDateSeries) = @_;
    my($tid, $df, @DTF, $dtf, $did, $tf, $date, %Date, @Date);
    $tid = $wg->GetKeywordID($w); # get term id (for WG3.5)
    next if $tid < 0; # 沒有這個詞
    @DTF = split /,/, $wg->GetTermDocInfo($tid, $Iid);#get index infomation
    $df = shift @DTF; # document frequency
warn "Index=$main::Oidx, Iid=$Iid, df=$df, w=$w\n" if $main::Odebug;
#warn join(', ', @DTF), "\n" if @DTF <= 20;
    next if $df <= 0;
    foreach $dtf (@DTF) { # for each document
        ($did, $tf) = split /:/, $dtf;
        $date = $rDid2Date->[$did];
        $Date{$date} ++; # accumulate dates ...
    }
    print "$w\t$kwdf\t", join("\t", map{$Date{$_}eq''?0:$Date{$_}}@$rDateSeries), "\n";
}
#-------------------- &GetKeyword_TimeSeries() ------------------------

# given IndexName, return index ID
sub IndexName2ID { # okey with WG 2.8 and WG 3.57
    my($wg, $IndexName) = @_;
    my $MaxIndexNo = $wg->GetIndexNo();
    for (my $i=0;$i<$MaxIndexNo;$i++) {
        return $wg->GetIndexID($i) if ($IndexName eq $wg->GetIndexName($i));
    }
    return -1; # if not found
}

sub GetDoc_Date_PK_Title { # Okey with WG 2.8 and WG 3.57, 2007/01/30
    my($wg, $Iid, $IdxName) = @_;  
    my(@Did2Date, $N, $I, $J, $Did, $date, $year, $month, $day, $stime, $etime);
    my(@Did2PK, @Did2Title, $RN, $run, $MaxR, $min, $max);
    $stime = time();
    my($version, $vern, $other) = split /\n/, $wg->GetVersion(), 3; # 2007/01/30
    $wg->ClearQueryIndex(); # 清除之前的查詢索引，清除後內定為查詢所有的索引
    $wg->AddQueryIndex($IdxName);       #檢索資料庫
    $wg->SetSearchMode(0); # 檢索模式: 0=精確查詢、1=主題查詢、2=模糊查詢
    $wg->SetQuerySentence('*');       #檢索字串, 找出所有該索引的文件
    if ($version < 3.5) {
	$wg->SetQueryDocumentNo(1000,1000); # 設定檢索時應出現的文件數,已取消，無用
    } else {
#	$wg->SetQueryDocRange(0, 99999999); # 預設為0-255,將其改為全部輸出
			$MaxR = 1000000; # the maximun of SetQueryDocRange per run #2012/01/09 	
    }
    $wg->Search(0,0);                       #不啟動提示詞
    $N = $wg->GetDocNo(); $RN = $wg->GetRealDocNo();
    warn "GetDocNo=$N, GetRealDocNo=$RN\n" if $N != $RN; # 2007/11/10
    
  if ($version < 3.35) {
#  if (1) { warn "use GetDocFieldContent()\n"; # test GetDocFieldContent() under WG 3.57
    for ($I = 0; $I < $N; $I++) {
        $Did = $wg->GetDocID($I);  # 取得文件ID, 用來取得文件大小
        $date = $wg->GetDocFieldContent(0, $Iid, $Did, '$4$'); # $4$ = 文件日期時間
        ($year, $month, $day) = split(/[\/ ]/, $date); # format: '2000/12/01 00:00:00'
        if ($main::Oday) { $date = $year.sprintf("%02d", $month).sprintf("%02d", $day); } 
        elsif ($main::Omonth) { $date = $year.sprintf("%02d", $month); }
        else { $date = $year; }
        $Did2Date[$Did] = $date;
        $Did2PK[$Did] = $wg->GetDocFieldContent(0, $Iid, $Did, '$7$');    # $7$ = 文件名稱
        $Did2Title[$Did] = $wg->GetDocFieldContent(0, $Iid, $Did, '$8$'); # $8$ = 文件標題
    }
  } else { # $me->{'WG_Version'} >= 3.35
		for ($run=0; $run<(int(($N-1)/$MaxR)+1); $run++) {
			$min = $run*$MaxR-1; $max = (($run+1)*$MaxR-1)>$N?$N:(($run+1)*$MaxR-1);
			$wg->SetQueryDocRange($min, $max);
  	  $wg->ClearBatchGetDocFieldContent();
    	for ($I = $min; $I <= $max; $I++) {
      	  $Did = $wg->GetDocID($I);  # 取得文件ID
					$wg->BatchGetDocFieldContent(0, $Iid, $Did, '$4$'); # $4$ = 文件日期時間
					$wg->BatchGetDocFieldContent(0, $Iid, $Did, '$7$'); # $7$ = 文件名稱
					$wg->BatchGetDocFieldContent(0, $Iid, $Did, '$8$'); # $8$ = 文件標題
    	}
    	$wg->StartBatchGetDocFieldContent();
    	for ($I=$min, $J=$min*3; $I <= $max; $I++) {
        $Did = $wg->GetDocID($I);  # 取得文件ID
				$date = $wg->GetBatchDocFieldContent($J++);
				$Did2PK[$Did] = $wg->GetBatchDocFieldContent($J++);
				$Did2Title[$Did] = $wg->GetBatchDocFieldContent($J++);
        ($year, $month, $day) = split(/[\/ ]/, $date); # format: '2000/12/01 00:00:00'
        if ($main::Oday) { $date = $year.sprintf("%02d", $month).sprintf("%02d", $day); } 
        elsif ($main::Omonth) { $date = $year.sprintf("%02d", $month); }
        else { $date = $year; }
#print STDERR "Did=$Did, date=$date\n"; exit;
        $Did2Date[$Did] = $date;
    	}
		}
  } # end of if ($me->{'WG_Version'} < 3.5) {
    $etime = time();
print STDERR "Retrieve dates for $N documents from $IdxName in ", $etime-$stime, " seconds.\n";
    return (\@Did2Date, \@Did2PK, \@Did2Title, $N);
}


# Given a WG index name, a file having clusterd terms,
#   output the result of assigning documents to each cluster
sub AssignDoc2Cluster {
    my($WGidxName, $ClusterFile) = @_;
    my($Progress, $i, $percent, $n, $wg, $Iid, $rDid2Date, $rDid2PK, $rDid2Title);
    my($file, @Clusters, $cid, @Chead, %CDesc, @CTerm, @T, $rDid2CidSim, $c, $str);
    my($Cerr, @CidDid2Sim, $TotalDocNo, @Cid2CTerm);

    open F, $ClusterFile or die "Cannot read file:'$ClusterFile'";
    undef $/; $file = <F>; $/ = "\n"; # get all content in one read
    close(F);

    $wg = $me->{'wg'}; # set Global var.
    $Iid = &IndexName2ID($wg, $WGidxName);
    ($rDid2Date, $rDid2PK, $rDid2Title, $TotalDocNo) 
	= &GetDoc_Date_PK_Title($wg, $Iid, $WGidxName);

    @Clusters = split /<p>/, $file;
    shift @Clusters; shift @Clusters; # shift out first two non-cluster
    use SAMtool::Progress;
    $Progress = Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'}); $i = 0; 
    foreach $c (@Clusters) {
	$percent = $Progress->ShowProgress(++$i/@Clusters, $percent);
# Step 1. 取得每個類別的代表性詞彙（關鍵詞+共同關聯詞）
	# Get cluster id and cluster head
    	if ($c =~ /^((\d+).+\n.+\n.+\n)/) { $Chead[$1] = $1; $cid = $2; }
    	else { $Cerr++; next; }
    	# cluster id and head of the cluster, like this:
	#  1(47):<UL>
	#  <li>683443 : 47筆 : <font color=green>0.0027</font>
	#  (<b>electrode</b>: 27.7, <b>pixel electrode</b>: 11.1)
	@CTerm = (); %CDesc = ();
	# 2nd, get cluster descriptors (common related terms): <b>multicolor image</b>
	while ($c =~ /<b>([^<]+)<\/b>/g) { $CDesc{$1} += 1; }
	# 3rd, get cluster terms, format: " : protective layer</a>"
	while ($c =~ / : ([^<]+)<\/a>/g) { push @CTerm, $1; }
	$Cid2CTerm[$cid] = join ", ", @CTerm;
	@T = sort {$CDesc{$b} <=> $CDesc{$a}} keys %CDesc; # sort by frequency
	$n = @CTerm; $n = exp(1-$n**0.5)*log(5*$n+3)/log(2); #
	$n = (@T<int($n*@CTerm))?@T-1:int($n*@CTerm-1); 
#print  "cid=$cid, n_CDesc_Term=$n, chead=$Chead[$cid], CTerm=@CTerm\nT=@T\n\n";
#	$Cid2CTerm[$cid] = join(", ", @T[0..$n]) . " / " . join( ", ", @CTerm);
	$Cid2CTerm[$cid] = join( ", ", @CTerm);
	@T = (@CTerm, @T[0..$n]); # get the first $n*@CTerm cluster descriptors
	if ($main::OcluTerms) { print "$cid\t",scalar@T,"\t",join(',',@T),"\n"; next; }
# Now we have $cid, @Chead, %CDesc, @CTerm, and @T
# Step 2. 以上述詞彙，用主題檢索模式，查詢WebGenie（指定索引）
#	  蒐集每篇文件在每個類別的相似度
	$rDid2CidSim = &SearchWG($wg, $WGidxName, \@T, $cid, $rDid2CidSim, \@CidDid2Sim);
    }
    exit if ($main::OcluTerms);
    $percent = $Progress->ShowProgress(++$i/@Clusters, $percent);
    print STDERR "Could not extract cluster ID and headline from $Cerr clusters\n" if $Cerr>0;
# Step 3. 針對每篇文件，按照相似度排序所有類別，取相似度最高的類別，
#	  為其所屬的類別，從而求得類別到文件的對應表
#         選項：1.若有多個類別，相似度都接近最高，則同時歸到此多個類別
#	  選項：2.若相似度最高的類別，其相似度低於門檻，則該文件不分類
    my($did, %Cid2Sim, @Cid2Did, @Cid, @Cdid, $MaxCut, $MinCut, $Nlabel, $pk);
    my(%Clustered_Did, $EmptyClusters, @Cid2DocNo);
    $MaxCut = $main::OmaxCut; # ratio for high threshold of similarity
    $MaxCut = 0.9 if not defined $main::OmaxCut;
    $MinCut = $main::OminCut; # low threshold of similarity
    $MinCut = 0.5 if not defined $main::OminCut;
    $Nlabel = 0;
    for($did=0; $did<@$rDid2CidSim; $did++) {
    	next if $rDid2CidSim->[$did] eq '';
    	%Cid2Sim = split /\t/, $rDid2CidSim->[$did]; # "Cid1\tSim1\tCid2\tSim2\t"
    	@Cid = sort {$Cid2Sim{$b} <=> $Cid2Sim{$a}} keys %Cid2Sim;
#print "did=$did, Cid=@Cid, \$rDid2CidSim->[$did]=$rDid2CidSim->[$did]\n";
    	next if @Cid <= 0;
    	for($n=1; $n<@Cid; $n++) { last if $Cid2Sim{$Cid[$n]} < $MaxCut * $Cid2Sim{$Cid[0]}; }
    	for($i=0; $i<$n; $i++) { # $did should belongs to the first (n-1)th cids
	    $Cid2Did[$Cid[$i]] .= $did . "\t" if $Cid2Sim{$Cid[$i]}/100 > $MinCut;
#	    $Cid2Did[$Cid[$i]] .= "$did\t$Cid2Sim{$Cid[$i]}\t" if $Cid2Sim{$Cid[$i]}/100 > $MinCut;
	    # Note: WG's similarity ranges from 0 to 100.
	    $Clustered_Did{$did}++;
    	}
#$i--;print "did=$did, n=$n, i=$i, Cid[0..$i]=",join(', ', map{"$_:$Cid2Sim{$_}"}@Cid[0..$i]),"\n";
#print "did=$did, \$Cid2Did[$Cid[0]]=$Cid2Did[$Cid[0]]\n";
    	# count the number of documents that are labelled to multiple clusters
    	$Nlabel++ if $n>1; 
    }
    print STDERR "$Nlabel documents are assigned to multiple clusters.\n";

# Step 4. 根據類別到文件的對應表，以及原來的「詞彙歸類結果」檔案，
#	  輸出「文件歸類結果」檔
#   use @$rDid2PK, @$rDid2Title
    $Progress = Progress->new({'OUT'=>*STDERR{IO},'Format'=>'line'});
    $percent = 0; $EmptyClusters = 0;
#    foreach $cid (@Chead) {
    for ($cid=0; $cid<@Chead; $cid++) {
	$percent = $Progress->ShowProgress($cid/@Chead, $percent);
	next if $Chead[$cid] eq '';
	$n = @T = sort {$CidDid2Sim[$cid][$b]<=>$CidDid2Sim[$cid][$a]} split /\t/, $Cid2Did[$cid]; 
#print "T=@T\n";
	$Cid2DocNo[$cid] = $n; # number of documents in each cluster
	$EmptyClusters++ if @T<=0;
	$str .= $Chead[$cid] . "<OL>$n documents ($Cid2CTerm[$cid])\n";
	foreach $did (@T) {
	    $pk = $rDid2PK->[$did];
# <li><a href='http://localhost/demo/STPIWG/src/ShowDoc.pl?f=6239026&st=html'>1423 : 6239026 : Nitride etch stop for poisoned unlanded vias</a>\n<br>
	    $str .= "<li><a href='http://localhost/demo/STPIWG/src/ShowDoc.pl?f=$pk&st=html'>".
	    $CidDid2Sim[$cid][$did] . ' : ' . $pk . ' : ' . $rDid2Title->[$did] . "</a>\n<br>\n",
	}
	$str .= "</OL>\n</UL>\n\n<p>";
    }
    $percent = $Progress->ShowProgress($cid/@Chead, $percent);
    $n = keys %Clustered_Did; $i = @Chead;
    print "<html><head><META content='text/html; charset=big5'></head>"
    	. "<body bgcolor=white>",
    "There are $i clusters, $n documents, $EmptyClusters clusters are empty.<br>",
    "$Nlabel documents are assigned to multiple clusters.\n<p>\n",
    $str, "\n<br></body></html>\n";
} # End of &AssignDoc2Cluster()


sub SearchWG {
    my($wg, $WGidxName, $rT, $cid, $rDid2CidSim, $rCidDid2Sim) = @_;
    my(@Did2CidSim, $N, $I, $J, $RN, $Did, $sim);
    my($version, $vern, $other) = split /\n/, $wg->GetVersion(), 3; # 2007/01/30
    $wg->ClearQueryIndex(); # 清除之前的查詢索引，清除後內定為查詢所有的索引
    $wg->AddQueryIndex($WGidxName);       #檢索資料庫
    $wg->SetQuerySentence(join(",",map{"'$_'"}@$rT)); #檢索字串,找出所有該索引的文件
    if ($version < 3.5) {
	$wg->SetQueryDocumentNo(1000,1000); # 設定檢索時應出現的文件數,已取消，無用
    } else {
	$wg->SetQueryDocRange(0, 99999999); # 預設為0-255,將其改為全部輸出
    }
    $wg->SetSearchMode(1); # 檢索模式: 0=精確查詢、1=主題查詢、2=模糊查詢
    $wg->SetSearchThreshold(50); # 設定主題／模糊查詢的門檻值,最高分的%數，0～100，0表不做門檻值篩選，100表只輸出最高分的文件
    $wg->AddSortField('$3$'); # $3$ = 文件檢索相似度, 未設定時視同相似度排序（由大至小）
    $wg->Search(0,0);                       #不啟動提示詞
    $N = $wg->GetDocNo(); $RN = $wg->GetRealDocNo();
    warn "GetDocNo=$N, GetRealDocNo=$RN\n" if $N != $RN; # 2007/11/10
    for ($I = 0; $I < $N; $I++) {
        $Did = $wg->GetDocID($I);  # 取得文件ID, 用來取得文件大小
        $sim = $wg->GetDocSimilarity($I); # 取得檢索到的文件之相似度值：0～100
        $rDid2CidSim->[$Did] .= "$cid\t$sim\t";
#print "Did=$Did, sim=$sim, cid=$cid\n\$rDid2CidSim->[$Did]=$rDid2CidSim->[$Did]\n";
	$rCidDid2Sim->[$cid][$Did] = $sim;
    }
    return $rDid2CidSim;
}

#-------------------- Term Clustering Functions -----------------------
# perl -s term_cluster.pl -Oclu -Oct_low_tf=0 -Odebug -Oall -OminDF=50 -OmaxDF=2000 term term WG_RKterms.txt > term\term.html
# perl -s term_cluster.pl -Oclu -Oct_low_tf=0 -Odebug -Ocut=0.5 -OminDF=50 -OmaxDF=2000 term2 term2 > term2\term2-0.50.html
# Add a new option: $OkeyOnly on 2008/11/12
sub TermCluster {
    my($IndexName, $IndexPath, $FileList) = @_;
    $main::Oct_low_tf = 1 if not defined $main::Oct_low_tf;
    my($rDC, $pro) = &Init($IndexName, $IndexPath);
    &FromDoc2CutTree($rDC, $pro, $FileList) if $main::Oall;
    &FromIndex2CutTree($rDC, $pro) if $main::Osim;
    &FromFile2CutTree($rDC, $pro) if $main::Ocut;
}

# Use global variable : $Odebug, $IndexName, $IndexPath
# set global variables : $pro, $rDC
sub Init {
    my($IndexName, $IndexPath) = @_;    my($rDC, $pro);
    $pro = Progress->new( {'OUT'=>*STDERR{IO},'Format'=>'percent'} );
    $rDC = Cluster->new( { 'debug'=>1 } );
    $rDC->SetValue('debug', $main::Odebug) if $main::Odebug;

    $rDC->SetValue('DocType', 'doc'); # 'doc' or 'term' (clustering)
    my $value = $rDC->GetValue('DocType'); # get attribute's value if needed
    $rDC->SetValue('IndexBy', 'me'); # or by 'WG' or 'me' (this program)
    $rDC->SetValue('Save2File', 1); # default is 0
    # if you want to save the results to files for fast later re-use, 
    # set 'Save2File' to 1 (0 otherwise), and set the next 2 attributes.
    $rDC->SetValue('IndexName', $IndexName);
    $rDC->SetValue('IndexPath', $IndexPath); # needed if 'IndexBy' is 'me'
    $rDC->CreateIndexPath(); if ($rDC->{'error'}) { die $rDC->{'error'}; }
    $rDC->SetValue('Sim', $main::Sim) if $main::Sim; # e.g. 'PureDice' 2009/11/27
print STDERR "IndexName=$IndexName, IndexPath=$IndexPath, Sim='$main::Sim'\n";
    return ($rDC, $pro);
}


# This function shows how to cluster the documents from the begining to the end.
# use global variables : $OminDF, $OmaxDF
sub FromDoc2CutTree {
    my($rDC, $pro, $FileList) = @_;
    my($sot, @FileList, $fi, $percent, $i, $tfn, $id, $title, $text, $df);
    my($NumDoc, $htmlstr, $root, %Text, $rtn, @text);
# if 'IndexBy' is 'me' and not yet built the index, insert docs for later use
#   foreach $term (@Term) { $rDC->AddIndexTerm( $term );#if extra terms needed
    $sot = time();
    open F, "$FileList" || die "Cannot read file:'$FileList', $!";
    $/ = "\n"; @FileList = <F>; chomp @FileList; close(F);
    $rtn = $fi = $percent = 0; $tfn = @FileList;
    for($i=0; $i<@FileList; $i++) {
	($id, $title, $df, @text) = split / : |\t/, $FileList[$i];#2009/11/23
# e.g., 14 : nigeria : 3 : ISI_000083037500002_	1	ISI_000240477700004_	1	ISI_A1992HC32700013_	1	
#	($id, $title, $df, $text) = split / : |\t/, $FileList[$i];
#	($id, $title, $df, $text) = split / : /, $FileList[$i];
#	($title, $text) = split / : /, $FileList[$i];
#	$i++;
	if (($df < $main::OminDF) or ($main::OmaxDF>0 and $df > $main::OmaxDF)) {
	    $title = $text = ''; # do not insert any text for processing
	} else { $rtn++; } # we still have to call $rDC->AddDoc() to get correct internal Doc_ID
#    	%Text = split /\t/, $text; $text = join ", ", keys %Text;
    	%Text = @text; $text = join ", ", keys %Text; # 2009/11/23
#print STDERR "$title, $text\n"; exit;
	$text = '' if $main::OkeyOnly;
	$rDC->{'TextOnly'}=1 if $text =~ /^ISI/i; # 2009/11/29, affect &AddDoc() in cluster.pm
	$rDC->AddDoc("$FileList\t$i", $title, $text); # insert those to be clustered
	$percent = $pro->ShowProgress($i/$tfn, $percent) if $main::Odebug;
    }
    $percent = $pro->ShowProgress($i/$tfn, $percent) if $main::Odebug;
    $NumDoc = $rDC->SaveDocIndex() if $rDC->GetValue('Save2File');
    $NumDoc = $rDC->GetValue('NumDoc'); # return number of documents inserted
    undef @FileList; undef %Text; undef $text; undef $title;
print STDERR "  It takes ", time() - $sot, " seconds to insert $rtn (out of $tfn) documents\n" if $main::Odebug;

    $rDC->SetValue('Method', 'CompleteLink'); # 'SingleLink', 'Cluto', or 'SOM'
    $rDC->SetValue("low_df", 0); # do not use term whose df <= 2
    $rDC->SetValue("low_tf", 0); # do not use those term whose tf in doc is<=0
    $root = $rDC->DocSimilarity();
    $rDC->SaveSimilarity() if $rDC->GetValue('Save2File');

    $rDC->CompleteLink();
    $rDC->SaveTree() if $rDC->GetValue('Save2File');

    $rDC->SetValue("ShowDoc", "http://localhost/cgi-ig/ShowDoc4.pl");
    $rDC->SetValue('NumCatTitleTerms', 5);
    $rDC->SetValue("ct_low_tf", $main::Oct_low_tf); # do not use term whose tf <= 1
# set the URL to show the full content of the inserted file (using its )
    $htmlstr = $rDC->CutTree(0.0);
    $htmlstr = "<html><head><META content='text/html; charset=big5'></head>"
    		. "<body bgcolor=white>" . $htmlstr . "\n<br></body></html>";
    print $htmlstr; # print out to the browser in CGI environment
}


# If you have already saved the results, just read them back to compute
# another ways of clustering using different thresholds.
sub FromIndex2CutTree {
    my($rDC, $pro) = @_;
    my($NumDoc, $htmlstr, $root);
    $NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
    $rDC->SetValue('Method', 'CompleteLink'); # 'SingleLink', 'Cluto', or 'SOM'
    $rDC->SetValue("low_df", 2); # do not use term whose df <= 2
    $rDC->SetValue("low_tf", $main::Olow_tf); # do not use those term whose tf in doc is<=0
    $root = $rDC->DocSimilarity();
    $rDC->SaveSimilarity() if $rDC->GetValue('Save2File');

    $rDC->CompleteLink();
    $rDC->SaveTree() if $rDC->GetValue('Save2File');

    $rDC->SetValue("ShowDoc", "http://localhost/cgi-ig/ShowDoc4.pl");
    $rDC->SetValue('NumCatTitleTerms', 4);
    $rDC->SetValue("ct_low_tf", $main::Oct_low_tf); # do not use term whose tf <= 1
    $htmlstr = $rDC->CutTree(0.14);
    $htmlstr = "<html><head><META content='text/html; charset=big5'></head>"
    	 	. "<body bgcolor=white>" . $htmlstr . "\n<br></body></html>";
    print $htmlstr; # print out to the browser in CGI environment
}


# If you have already saved the results, just read them back to compute
# another ways of clustering using different thresholds.
sub FromFile2CutTree {
    my($rDC, $pro) = @_;
    my($NumDoc, $htmlstr);
    $NumDoc = $rDC->ReadDocIndex(); # for computing clusters' title terms
#    $root = $rDC->ReadSimilarity(); # no longer needed for re-cluster
    $rDC->ReadTree();
# set the URL to show the full content of the inserted file (using its )
    $rDC->SetValue("ShowDoc", "http://localhost/cgi-ig/ShowDoc4.pl");
    $rDC->SetValue('NumCatTitleTerms', 4);
    $rDC->SetValue("ct_low_tf", $main::Oct_low_tf); # do not use term whose tf <= 1
    $main::Ocut = 0.14 if not defined $main::Ocut;
#    $htmlstr = $rDC->CutTree(0.14);
    $htmlstr = $rDC->CutTree($main::Ocut);
    $htmlstr = "<html><head><META content='text/html; charset=big5'></head>"
    		. "<body bgcolor=white>" . $htmlstr . "\n<br></body></html>";
    print $htmlstr; # print out to the browser in CGI environment
}
#-------------------- Term Clustering Functions -----------------------

