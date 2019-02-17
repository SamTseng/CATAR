#!/usr/bin/perl -s
package Stopword;
# Next is a comment segment in POD format. Comment ends until '=cut'

=head1 NAME

Stopword -- A class for handling stop words. 

=head1 SYNOPSIS

    use Stopword;
    $Stop = Stopword->new( );
    $Stop->AddESW('font'); # add 'font' as an English Stop word
    $Stop->AddCSW('牽 涉'); # add '牽 涉' as a Chinese Stop word
    $Stop->AddEmark("\t"); # add "\t" as an English punctuation mark
    $Stop->AddCmark('﹗'); # add '﹗' as a Chinese punctuation mark
    $Stop->AddStopHead('逐'); # add '逐' as a Chinese stop head character
    $Stop->AddStopTail('遂'); # add '遂' as a Chinese stop tail character
    $Stop->DelESW('font'); # delete 'font' as an English Stop word
    $Stop->DelCSW('牽 涉'); # delete '牽 涉' as a Chinese Stop word
    $Stop->DelEmark("\t"); # delete "\t" as an English punctuation mark
    $Stop->DelCmark('﹗'); # delete '﹗' as a Chinese punctuation mark
    $Stop->DelStopHead('逐'); # delete '逐' as a Chinese stop head character
    $Stop->DelStopTail('遂'); # delete '遂' as a Chinese stop tail character
    if ($Stop->IsESW('the')) { print "'the'  is an English Stop Word\n"; }
    if ($Stop->IsCSW('但 是')) { print "'但 是' is a Chinese Stop Word\n"; }
    if ($Stop->IsEmark(',')) { print "',' is an English punctuation mark\n"; }
    if ($Stop->IsCmark('，')) { print "'，' is a Chinese punctuation mark\n"; }
    if ($Stop->IsStopHead(substr('第 五 號', 0, 2))) { 
    	print "'第' is a Chinese Stop Head Character\n"; }
    if ($Stop->IsStopTail(substr('第 五 日', 6, 2))) { 
    	print "'日' is a Chinese Stop Tail Character\n"; }
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
    %Cmark =();	# Chinese punctuation marks 標點符號
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
乃	了	也	寸	已	不	之	今	
及	尺	月	以	他	可	另	只	
它	用	由	吋	在	她	年	式	
此	而	至	但	你	呎	呀	我	
牠	那	並	些	其	到	和	呢	
妳	或	所	於	的	者	則	型	
很	是	昨	為	若	要	們	個	
哪	除	啊	將	從	您	條	第	
這	就	等	僅	該	較	對	與	
麼	還	讓	灣	

．	○	一	七	乃	九	了	二	
八	十	三	下	也	千	已	不	
之	五	今	元	六	及	支	日	
月	以	他	可	只	四	它	未	
在	她	年	有	百	而	至	你	
即	呀	我	牠	那	並	些	其	
到	呢	妳	或	所	於	的	者	
則	很	後	是	昨	為	若	個	
哪	起	隻	啊	將	從	您	這	
就	等	裡	該	與	說	麼	還	
顆	

!	"	#	$	%	&	'	(	
)	*	+	,	-	.	/	:	
;	<	=	>	?	@	[	\	
]	^	_	`	{	|	}	~	

　	，	、	。	．	‧	；	：	
？	！	︰	…	﹐	﹑	﹔	﹖	
｜	—	（	）	︵	︶	｛	｝	
〔	〕	【	】	《	》	〈	〉	
︿	「	」	﹁	﹂	『	』	﹃	
﹄	﹝	﹞	‘	’	“	”	〞	
＃	＆	＊	※	●	△	▲	◎	
☆	★	◆	□	■	＋	－	＜	
＞	＝	～	↑	←	→	／	＼	
＄	％	＠	┼	┴	┬	┤	─	
│	┌	┐	└	┘	˙	々	╔	
╗	╚	╝	╧	╥	╫	╢	╨	
╯	�]	

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

一 一	一 口	一 口 氣	一 切	一 心	一 手	一 方 面	一 古 碌	
一 旦	一 共	一 再	一 同	一 向	一 如	一 字	一 早	
一 而 再	一 至	一 行	一 屁 股	一 把	一 些	一 來	一 併	
一 味	一 季	一 定	一 定 要	一 定 會	一 忽 而	一 直	一 股 腦	
一 剎 間	一 則	一 勁	一 度	一 律	一 怒	一 昧	一 是	
一 面	一 個	一 時	一 時 間	一 晃 眼	一 眨 眼	一 般	一 般 人	
一 起	一 骨 碌	一 桿 子	一 清 早	一 眼	一 連	一 逕	一 朝	
一 無	一 筆	一 塊	一 塊 兒	一 意	一 會	一 概	一 溜 煙	
一 路	一 路 上	一 跤	一 道	一 道 兒	一 鼓	一 窩 蜂	一 齊	
一 樣	一 霎	一 舉	一 轉 眼	一 蹴	一 邊	一 邊 兒	一 攬 子	
乃 至	乃 至 於	了 一	二 來	二 季	二 則	人 均	人 們	
几 乎	力 予	力 於	十 七 八	十 分	又 以	又 有	又 要	
又 對	三 成	三 季	三 則	下 午	下 半	下 半 年	下 去	
下 來	上 一 季	上 午	上 半	上 半 年	上 次	上 述	上 週	
凡 此	凡 是	久 久	也 不	也 可	也 在	也 有	也 表 示	
也 是	也 要	也 將	也 許	也 無	也 會	于 是	兀 自	
千 萬	大 力	大 凡	大 口	大 加	大 可	大 老 遠	大 步	
大 抵	大 非 可	大 剌 剌	大 為	大 約	大 致	大 致 上	大 略	
大 規 模	大 都	大 幅	大 筆	大 概	大 肆	大 舉	孑 然	
小 作	小 幅	己 見	己 經	已 在	已 成	已 成 為	已 有	
已 告	已 往	已 於	已 核 准	已 逐 漸	已 然	已 經	已 經 出	
已 達	巳 經	才 是	才 能	才 會	不 一 定	不 下	不 大	
不 太	不 少	不 日	不 止	不 加	不 去	不 可	不 可 以	
不 可 能	不 只	不 外	不 必	不 必 再	不 用	不 用 說	不 由	
不 由 地	不 由 得	不 光	不 再	不 多 久	不 自 禁	不 住	不 但	
不 克	不 免	不 吝	不 吝 於	不 妨	不 見 得	不 忿 地	不 明	
不 肯	不 是	不 為	不 致	不 致 於	不 若	不 要	不 准	
不 容	不 料	不 時	不 消	不 消 說	不 特	不 能	不 能 不	
不 能 夠	不 配	不 得	不 得 不	不 符	不 許	不 勝	不 啻	
不 單	不 單 單	不 復	不 期	不 期 然	不 然	不 須	不 僅	
不 僅 僅	不 想	不 愧	不 暇	不 會	不 會 列	不 會 將	不 經 意	
不 過	不 遑	不 盡	不 管	不 需	不 論	不 獨	不 應	
不 斷	中 午	中 有	中 有 關	中 的	中 長	之 一	之 二	
之 人	之 八 九	之 十	之 又	之 三	之 下	之 上	之 久	
之 口	之 士	之 大	之 女	之 子	之 小	之 才	之 不	
之 中	之 五	之 內	之 六	之 分	之 友	之 夫	之 心	
之 日	之 日 起	之 比	之 水	之 火	之 父	之 犬	之 王	
之 主	之 以	之 功	之 北	之 半	之 四	之 外	之 本	
之 母	之 用	之 由	之 交	之 份	之 光	之 兆	之 先	
之 列	之 名	之 地	之 在	之 多	之 字 形	之 年	之 死	
之 百	之 而	之 肉	之 至	之 色	之 行	之 位	之 作	
之 兵	之 別	之 志	之 災	之 見	之 角	之 言	之 事	
之 和	之 夜	之 妻	之 所	之 所 以	之 明	之 河	之 爭	
之 物	之 初	之 長	之 門	之 便	之 冠	之 前	之 客	
之 度	之 後	之 故	之 流	之 為	之 秋	之 美	之 計	
之 音	之 首	之 值	之 冤	之 家	之 差	之 差 是	之 徒	
之 恩	之 旁	之 旅	之 時	之 氣	之 泰	之 神	之 能 事	
之 財	之 馬	之 側	之 國	之 患	之 情	之 欲	之 理	
之 眾	之 處	之 術	之 都	之 鳥	之 尊	之 殼	之 痛	
之 短	之 詞	之 量	之 間	之 亂	之 勢	之 意	之 極	
之 源	之 祿	之 罪	之 義	之 貉	之 路	之 道	之 過	
之 隔	之 境	之 墓	之 夢	之 實	之 態 度	之 歌	之 福	
之 語	之 際	之 價	之 價 值	之 數	之 誼	之 談	之 論	
之 輩	之 餘	之 戰	之 險	之 聲	之 舉	之 職	之 辭	
之 難	之 類	之 寶	之 鐘	之 歡	之 戀	之 啥	予 以	
互 相	什 麼	仍 不	仍 以	仍 可	仍 未	仍 在	仍 有	
仍 是	仍 能	仍 將	仍 然	仍 舊	今 仍 未	今 天	今 年	
今 年 不	今 後	今 起	介 於	內 之	內 容	公 司	公 佈	
公 然	分 之	分 出	分 外	分 別	分 批	分 期	分 頭	
切 切	切 勿	切 莫	切 嚓	刈 嚓	化 服 務	升 至	及 早	
及 時	反 之	反 手	反 正	反 而	反 倒	反 躬	反 復	
反 複	反 覆	天 天	天 數	夫 復	太 早	太 甚	太 過	
太 過 於	尤 其	尤 其 是	尤 為	尤 須	巴 巴	巴 腳	引 起	
戶 人	手 連 手	支 持	支 援	斗 然	方 才	方 可	方 式	
方 自	方 始	方 面	日 下 午	日 上 午	日 日	日 在	日 形	
日 夜	日 前	日 益	日 起	日 圓	日 漸	日 臻	日 趨	
月 中	月 份	月 底	月 第	月 開 始	毋 庸	毋 須	毋 寧	
比 去 年	比 肩	比 較	火 速	牙 牙	且 較	主 要	主 要 是	
乍 然	以 下	以 上	以 及	以 次	以 至	以 至 於	以 免	
以 每	以 防	以 來	以 往	以 便	以 前	以 後	以 是	
以 為	以 致	以 致 於	以 資	以 增	以 確	他 也	他 不	
他 在	他 並	他 表 示	他 指 出	他 是	他 們	他 將	他 強 調	
他 對	他 認 為	他 說	令 人	充 其 量	充 滿	出 現	加 入	
加 上	加 以	加 意	包 含	包 括	包 準	半 年	半 年 前	
卡 擦	卡 嚓	卯 勁	去 年	可 月 產	可 月 產 	可 以	可 以 把	
可 以 把 	可 以 做	可 以 做 	可 巧	可 用	可 用 做	可 用 做 	可 再	
可 列	可 同 時	可 同 時 	可 存	可 至	可 行	可 作	可 免	
可 否	可 呈 現	可 呈 現 	可 把	可 見	可 見 得	可 言	可 使	
可 使 用	可 供	可 取	可 幸	可 放	可 放 映	可 放 映 	可 於	
可 直	可 直 	可 知	可 持 股	可 持 股 	可 是	可 看	可 突 破	
可 突 破 	可 要	可 能	可 能 有	可 能 有 	可 能 使	可 能 使 	可 能 是	
可 能 為	可 能 為 	可 能 會	可 望	可 就	可 期	可 期 	可 進 行	
可 進 行 	可 經 由	可 經 由 	可 達	可 維 持	可 維 持 	可 說	可 銷 售	
可 銷 售 	可 謂	可 選 擇	可 選 擇 	可 錄	可 錄 	可 錄 製	可 錄 製 	
可 應 用	可 應 用 	可 檢 測	可 檢 測 	可 歸	右 列	召 開	叮 叮	
叮 咚	叮 噹	另 一	另 方 面	另 外	另 有	另 行	另 行 一 個	
另 行一 個	只 不 過	只 好	只 有	只 是	只 要	只 限 於	只 消	
只 能	只 得	叭 叭	叭 噠	四 下	四 季	四 則	四 處	
外 庸	外 傳	它 們	左 右	市 場	平 心	平 白	平 空	
平 時	平 素	必 定	必 要	必 得	必 然	必 須	必 需	
打 道	扑 瀝 瀝	本 來	本 周	本 季	本 屆	本 於	本 報	
本 期	本 週	本 該	未 上	未 及	未 加	未 必	未 因	
未 有	未 免	未 見 得	未 來	未 始	未 定	未 便	未 曾	
未 發	未 嘗	未 滿	正 巧	正 在	正 好	正 式	正 是	
正 常	正 該	永 世	永 遠	犯 不 上	犯 不 著	生 來	生 產	
用 不	用 不 了	用 不 著	用 之	用 化	用 以	用 來	用 於	
用 的	用 資	由 于	由 不 住	由 它	由 次	由 此	由 其	
由 於	由 衷	目 下	目 前	目 前 已	立 即	立 刻	立 時	
交 互	交 相	交 絡	交 給	亦 未	亦 在	亦 即	亦 將	
仿 佛	任 何	任 意	任 憑	仰 天	份 外	先 加	先 行	
先 時	先 頭	全 力	全 天 候	全 心	全 年	全 面	全 神	
全 速	全 然	全 程	全 權	共 有	再 一 次	再 三	再 下 去	
再 下 來	再 不 然	再 且	再 加	再 加 上	再 再	再 次	再 而 三	
再 行	再 作	再 來	再 者	再 則	再 度	再 按	再 就 是	
再 提	再 過	再 說	列 為	列 隊	印 怎	同 一	同 時	
同 時 也	同 氣	同 理	同 期	同 樣	同 樣 地	同 聲	吐 米 酒	
吁 吁	各 大 廠	各 地	各 自	各 位	各 佔	各 別	各 界	
各 國	各 項	各 種	各 廠 商	向 來	名 為	合 力	吃 來	
因 之	因 公	因 此	因 而	因 何	因 其	因 故	因 為	
地 區	地 茍	在 一	在 中	在 內	在 他	在 台	在 各	
在 在	在 此	在 我	在 於	在 國	在 這	在 臺	多 少	
多 方	多 加	多 半	多 多	多 年	多 所	多 張	多 項	
多 萬	多 麼	多 虧	夸 夸	妄 加	妄 自	妄 然	好 不	
好 歹	好 加 在	好 生	好 在	好 好	好 好 兒	好 言	好 的	
好 容 易	好 像	她 們	她 說	如 下	如 上	如 此	如 何	
如 果	如 果 說	如 約	如 若	如 斯	如 期	如 實	如 數	
存 心	安 得	安 然	尖 聲	并 且	年 之	年 內	年 全 球	
年 年	年 來	年 底	年 底 前	年 初	年 度	年 時	年 起	
年 第	忙 不 迭	忙 著	成 了	成 天	成 心	成 日	成 立	
成 為	早 一 些	早 一 點	早 已	早 日	早 早	早 些	早 歲	
早 點	曲 意	有 一	有 一 些	有 一 點	有 了	有 人	有 加	
有 可	有 可 	有 可 為	有 可 為 	有 可 能	有 多	有 如	有 何	
有 助 於	有 否	有 沒 有	有 些	有 所	有 差	有 時	有 時 候	
有 夠	有 得	有 無	有 著	有 道 是	有 點	有 點 兒	有 關	
有 鑑 於	有 鑒 於	次 第	此 一	此 外	此 次	此 行	此 後	
此 時	此 間	此 項	此 種	死 死	死 命	死 前	百 般	
老 半 天	老 早	老 來	老 是	老 實 說	老 遠	而 不	而 今	
而 且	而 因	而 在	而 成	而 言	而 非	而 後	而 是	
自 力	自 小	自 己 的	自 古	自 幼	自 此	自 行	自 始	
自 於	自 是	自 相	自 從	自 當	自 應	自 願 性	自 顧 自	
至 今	至 少	至 心	至 多	至 於	至 於 說	至 為	至 極	
行 不	行 不 行	行 使	行 將	位 於	住 在	何 不	何 止	
何 以	何 只	何 必	何 至 於	何 妨	何 其	何 況	何 故	
何 為	何 苦	何 時	何 曾	何 等	何 須	何 嘗	何 種	
估 計	伺 機	佔 有	似 乎	似 未	但 凡	但 以	但 他	
但 因	但 在	但 是	但 須	作 出	作 為	你 們	低 於	
低 度	低 聲	免 不 了	免 得	冷 不 丁	冷 不 防	冷 眼	冷 瑟 瑟	
別 人	利 用	即 已	即 今	即 日	即 令	即 可	即 行	
即 告	即 使	即 刻	即 或	即 便	即 指	即 席	即 將	
即 興	吭 哧	否 則	呀 然	吱 吱	含 恨	均 已	均 不	
均 可	均 未	均 由	均 有	均 係	均 為	均 能	均 無	
均 較	均 需	均 應	圾 隆	坏 坏	妥 為	完 全	完 成	
希 望	希 望 能	形 式 上	彷 彿	彷 彿 間	彷 若	忍 俊	快 步	
快 要	快 點	快 點 兒	我 也	我 不	我 方	我 在	我 是	
我 們	我 國	投 入	抑 或	抑 是	改 天	改 日	改 用	
改 為	更 且	更 加	更 多	更 有	更 何 況	更 形	更 是	
更 為	每 一	每 人	每 天 	每 日	每 月	每 片	每 年	
每 每	每 季	每 股	每 個	每 逢	每 當	每 隔	每 種	
沙 沙	汪 汪	決 不	決 定	決 然	沒 人	沒 有	沒 法	
沒 法 兒	沒 得	沒 想 到	汲 汲	牠 們	私 下	私 自	私 行	
私 底 下	私 毫	究 竟	足 以	足 可	足 見	足 足	迅 即	
迄 今	迄 未	那 天	那 些	那 呵	那 怕	那 個	那 般	
那 裡	那 種	那 麼	那 麼 著	那 麼 樣	並 不	並 且	並 可	
並 未	並 在	並 沒 有	並 於	並 肩	並 非	並 將	並 無	
並 對	並 騎	事 先	事 實 上	依 次	依 此	依 序	依 法	
依 約	依 然	依 稀	依 照	依 樣	依 憑	依 據	依 舊	
使 用	使 用 上	使 用 之	使 其	使 得	供 人	供 述	供 應	
例 如	來 不 及	來 日	來 自	來 到	來 的	來 看	來 得	
來 得 及	來 說	侃 侃	併 肩	兩 三 下	兩 相	具 有	具 備	
其 一	其 二	其 中	其 他	其 次	其 實	刻 正	刻 意	
刷 啦 啦	到 了	到 底	到 家	到 時	到 時 候	到 處	到 頭 來	
協 同	受 到	呵 呵	咕 嚕	呼 地	呼 呼	呼 哨	呼 嚕	
呼 嚕 嚕	呼 籲	呼 哧	呱 呱	和 衣	和 身	咚 咚	固 然	
坦 坦	夜 夜	奉 令	奉 召	奉 命	奉 派	奈 也	奈 何	
委 實	姑 且	始 終	孤 身	季 中	季 盈 餘	季 時	季 第	
季 單 季	季 營 收	定 有	定 定 的	定 要	定 能	定 期	定 然	
定 睛	宜 於	尚 且	尚 未	居 中	居 然	居 間	屆 時	
屆 期	幸 未	幸 好	幸 而	幸 虧	底 前	往 回	往 往	
往 常	彼 此	忽 地	忽 而	忽 的	忽 焉	忽 然	忽 然 間	
忿 忿	怔 怔 地	怯 怯 地	怪 不 得	怪 哉	性 半 導	或 可	或 者	
或 是	或 許	所 以	所 有	所 幸	所 為	所 提	所 需	
所 謂	抹 頭	拒 不	抽 空	抵 死	抱 頭	放 聲	放 膽	
放 懷	於 今	於 公	於 此	於 私	於 是	於 是 乎	於 焉	
昔 年	昔 時	易 言 之	易 於	昂 然	明 文	明 年	明 明	
明 顯	果 若	果 真	果 然	枉 自	欣 然	沾 沾	波 及	
油 然	況 且	況 乎	沮 然	沿 街	沿 路	泛 指	泊 泊	
爭 先	爭 相	的 卻	的 很	的 時 候	的 話	的 確	直 勾 勾	
直 刷 刷	直 到	直 接	直 須	知 道	秉 公	空 手	空 身	
空 咚	虎 虎	初 次	初 步	初 初	初 度	初 時	初 期	
表 示	表 達	迎 向	迎 面	迎 風	迎 頭	近 日 來	近 來	
近 期	長 年	長 李	長 林	長 的	長 約	長 效	長 時 間	
長 張	長 陳	長 選 舉	附 近	附 設	非 但	非 徒	非 常	
非 得	亟 須	亟 需	亟 應	信 口	信 手	信 步	便 可	
便 是	便 會	促 成	促 使	促 膝	俟 機	俗 話 說	俗 語 說	
俄 而	冒 死	冒 然	剎 然	前 3 季	前 一 年	前 一 季	前 一 週	
前 三 季	前 天	前 來	前 往	前 項	則 有	則 表 示	則 是	
則 為	勇 於	勉 力	勉 為	勃 然	哇 哇	哇 哇 地	哇 啦	
咽 咽	咪 咪	哈 哈	哈 啾	咯 吱	咯 咯	咯 咯 兒	咯 咯 咯	
咻 咻	咩 咩	咿 咿	型 企 業	宣 布	幽 幽 地	幽 幽 的	幽 然	
很 少	待 會	待 會 兒	後 才	後 再	後 來	後 的	怒 目	
怒 聲	急 忙	急 步	急 迫 地	急 速	急 須	急 劇	急 遽	
急 驟	怎 不	怎 生	怎 地	怎 的	怎 能	怎 會	怎 麼	
怎 樣	恍 若	恍 然 間	恰 可	恰 巧	恰 好	恰 恰	恨 恨 地	
恆 常	按 日	按 月	按 住	按 址	按 呢	按 怎	按 時	
按 理	按 期	拼 死	持 續	指 出	指 示	指 名	指 稱	
拱 手	拾 級	故 此	故 而	既 已	既 有	既 而	既 非	
既 然	昧 心	是 一	是 一 個	是 一 種	是 不	是 不 是	是 以	
是 他	是 由	是 因 為	是 在	是 有	是 否	是 否 會	是 我	
是 我 們	是 很	是 指	是 故	是 為	是 為 了	是 要	是 個	
昨 天	昨 日	昨 日 在	昨 夜	昨 晚	曷 不	柔 聲	活 活	
為 了	為 之	為 什 麼	為 止	為 主	為 他	為 何	為 甚 麼	
為 期	為 避 免	為 啥	為 啥 子	狠 勁	狠 狠	狠 狠 心	狠 狠 地	
狡 詰	甚 少	甚 且	甚 而	甚 至	甚 至 於	甚 或	甚 為	
皆 可	皆 為	省 得	相 互	相 互 間	相 反 地	相 反 的	相 形	
相 偕	相 率	相 當	相 對 的	相 關	相 繼	相 顧	看 上 去	
看 來	看 到	看 樣 子	祇 好	祇 有	祇 是	祇 要	突 地	
突 來	突 突 地	突 然	約 在	約 佔	約 為	約 略	約 莫	
美 元	背 地 裡	胡 亂	致 使	若 不 然	若 使	若 果	若 非	
若 是	若 要	衍 然	要 不	要 不 是	要 不 要	要 不 然	要 有	
要 求	要 是	要 麼	計 件	計 有	負 氣	迥 然	重 行	
重 新	重 頭	降 至	面 對	面 臨	飛 也 似	飛 快	首 先	
首 次	首 季	首 度	乘 夜	乘 便	乘 勢	乘 隙	乘 機	
乘 興	倍 加	倍 極	俯 首	借 勢	借 題	倒 不 如	倒 是	
倒 頭	個 月	倘 使	倘 若	俾 便	俾 能	兼 以	兼 具	
兼 程	凌 空	凌 晨	凌 雲	凌 聲	剛 巧	剛 剛	剛 剛 好	
剛 起 步	原 本	原 先	原 有	原 來	原 定	原 則 上	原 審 採	
哪 些	哪 來	哪 知 道	哪 是	哪 裏	唧 唧	唏 哩 哩	埋 頭	
娓 娓	容 或	展 開	差 一 點	差 點	差 點 兒	席 地	徒 手	
徐 徐 的	恣 情	恣 意	恣 意 地	恐 怕	悄 步	悄 悄	悄 然	
悄 聲	悍 然	拿 下	挾 怨	振 翅	振 臂	挨 戶	挨 次	
挨 身	時 不 時	時 而	時 表 示	時 時	時 常	時 爾	朗 聲	
根 本	根 據	格 外	格 格	殊 不	殊 不 料	殊 為	殊 料	
殊 堪	涓 滴	涔 涔	烘 烘	特 地	特 此	特 意	益 加	
益 形	益 發	真 正	真 的	真 是	真 個	真 箇	砰 砰	
破 口	破 格	站 在	素 來	素 常	索 性	索 索	索 興	
純 然	純 粹	紛 紛	能 不 能	能 再	能 否	能 事	能 夠	
草 草	衷 心	討 論	訕 訕	訕 訕 地	託 病	豈 不	豈 不 是	
豈 止	豈 可	豈 只	豈 非	豈 是	豈 料	豈 能	起 先	
起 見	起 來	起 於	起 初	起 碼	送 來	送 達	配 上	
酌 情	酌 量	針 對	陡 然	除 了	除 此 外	除 非	隻 身	
馬 上	骨 碌 碌	高 於	高 達	高 聲	鬥 陣	假 如	假 使	
假 若	假 意	做 來	做 法	做 為	偉 然	偶 而	偶 爾	
側 耳	側 眼	偷 偷	偷 偷 地	偷 偷 兒	偷 眼	偷 著	偏 巧	
偏 生	偏 要	偏 偏	倏 乎	倏 地	倏 而	倏 忽	倏 然	
兜 頭	務 必	務 期	動 不 動	動 輒	區 區	參 加	參 與	
啪 啪	啪 啦	啞 啞	啊 喲	唱 來	問 問	問 題	唯 有	
唯 獨	國 內	國 外	國 政 府	國 國	基 於	婉 言	婆 娑	
孰 知	孰 料	孰 與	寄 銷 式	專 程	專 肆	專 誠	將 以	
將 可	將 由	將 在	將 成	將 有	將 來	將 於	將 近	
將 是	將 要	將 會	常 年	常 時	常 常	帶 著	帶 進	
帶 傷	庶 幾	強 自	強 行	強 制	強 調	得 以	得 多	
得 到	得 空	得 便	得 很	得 得	得 超 過	得 慌	從 小	
從 不	從 中	從 未	從 此	從 而	從 沒	從 來	從 旁	
從 速	從 實	從 頭	悉 心	悉 皆	悉 數	悠 悠 然	悠 閒 地	
情 事	情 況	情 況 下	惟 有	惟 獨	接 下 去	接 下 來	接 口	
接 受	接 近	接 連	接 著	接 踵	接 獲	掉 到	推 出	
推 動	採 用	排 名 第	救 急	敘 明	斜 眼	旋 即	旋 踵	
晚 上	晚 間	條 條	毫 不	毫 未	清 一 色	清 晨	淅 瀝	
深 有	深 夜	深 深	焉 有	猛 力	猛 地 裡	猛 然	率 先	
率 而	率 皆	率 然	率 意	率 爾	理 當	理 該	理 應	
現 已	現 在	現 有	現 行	產 品	產 據 點	略 加	略 為	
略 略	略 微	畢 竟	眾 多	眼 下	眼 巴 巴	眼 睜 睜	第 1 季	
第 2 季	第 3 季	第 4 季	第 一 季	第 二 季	第 三 季	第 四 季	符 合	
統 統	細 加	細 聲	累 月	累 世	終 久	終 于	終 日	
終 年	終 而	終 至 於	終 告	終 究	終 夜	終 於	終 須	
終 歸	脫 口	莫 不	莫 不 是	莫 及	莫 如	莫 非	處 以	
處 在	處 於	處 處	被 人	許 多	設 立	設 在	設 若	
貫 徹	這 一	這 一 來	這 人	這 下	這 大	這 太	這 支	
這 以 後	這 他	這 可	這 句	這 本	這 件	這 份	這 名	
這 回	這 有	這 次	這 死	這 位	這 你	這 把	這 批	
這 步	這 身	這 些	這 使	這 兒	這 招	這 杯	這 股	
這 則	這 娃	這 封	這 是	這 架	這 段	這 個	這 套	
這 家	這 座	這 時	這 真	這 般	這 副	這 張	這 條	
這 部	這 場	這 就 是	這 幅	這 幾	這 期	這 番 話	這 等	
這 筆	這 間	這 項	這 塊	這 會 兒	這 號	這 裡	這 話	
這 道	這 種	這 與	這 麼	這 麼 個	這 麼 樣	這 價	這 幢	
這 廝	這 樣	這 篇	這 輛	這 錢	這 幫	這 還	這 顆	
這 點	這 雙	這 邊	這 類	通 力	通 宵	通 常	通 通	
通 盤	通 體	連 手	連 日 來	連 名	連 年	連 忙	連 夜	
連 根	連 袂	連 帶	連 連	連 番	連 著	連 聲	連 翻	
連 續	速 成 長	逐 一	逐 日	逐 字	逐 年	逐 次	逐 告	
逐 步	逐 步 地	逐 級	逐 條	逐 第	逐 筆	逐 詞	逐 項	
逐 漸	逕 予	逕 付	逕 自	逕 行	逕 直	造 成	透 頂	
透 過	部 分	都 不	都 有	都 是	都 能	都 將	都 被	
閉 目	陪 同	陸 續	陶 然	竟 日	竟 自	竟 夜	竟 敢	
竟 然	竟 爾	頂 多	頃 刻	頃 間	魚 貫	備 至	備 極	
最 先	最 好	最 早	最 近	最 為	最 最	創 下	喀 啦	
喀 喀	喀 喳	喀 嚓	喔 喔	喃 喃	喳 喳	單 手	單 單	
單 獨	單 騎	單 邊	啾 啾	報 告 中	報 導	就 不	就 地	
就 在	就 有	就 此	就 兒	就 近	就 是	就 會	就 算	
幾 乎	幾 件	幾 度	幾 時	幾 經	復 次	循 序	循 例	
循 循	循 跡	循 線	循 聲	惡 狠 狠	惡 意	悶 頭	惺 惺	
慨 然	提 出	提 先	提 供	提 到	提 起	援 例	換 言 之	
敢 情	曾 向	曾 否	曾 被	曾 經	曾 對	期 間	渾 然	
滋 滋	無 不	無 不 大	無 心	無 日	無 比	無 以	無 可	
無 由	無 如	無 有	無 怪	無 怪 乎	無 法	無 非	無 故	
無 時	無 庸	無 從	無 條 件	無 須	無 疑	無 疑 地	無 端	
無 端 端	無 需	無 論	無 謂	無 償	然 后	然 因	然 而	
然 則	然 後	猶 可	猶 自	痛 加	登 時	發 言	發 表	
發 展	發 奮	硬 生	硬 生 生	硬 行	硬 是	稍 加	稍 作	
稍 事	稍 後	稍 為	稍 許	稍 稍	稍 嫌	稍 微	程 度	
等 一 會	等 人	等 下	等 國	等 等	等 會 兒	答 答	結 伴	
結 果	結 隊	結 夥	絕 口	絕 不	絕 少	絕 非	絕 偏	
絕 頂	絕 無	絕 對	絕 漠	給 予	給 我	善 加	善 自	
善 為	肅 然	著 著	著 實	視 為	貿 然	貿 貿 然	越 加	
越 來 越	越 發	超 過	趁 早	趁 勢	趁 隙	趁 熱	趁 機	
跌 打	跌 撞 撞	進 一 步	進 而	進 行	開 始	開 發 出	開 懷	
間 有	間 而	間 作	間 低	間 或	間 的	間 關	閒 來	
隆 隆	集 中 於	順 水	順 利	順 便	順 流	順 帶	順 勢	
順 道	順 囗	須 要	須 得	亂 槍	僅 止	僅 只	僅 有	
僅 次 於	僅 於	僅 僅	僅 管	傾 力	傾 刻	勤 加	勢 必	
勢 將	勢 須	嗣 後	嗤 嗤	嗤 溜	嗚 哩 哩	嗚 嗚	嗡 嗡	
嗆 啷	幹 嗎	幹 麼	微 服	微 幅	微 微	意 味 著	想 不 到	
想 必	想 來	想 著	想 當 然	愈 加	愈 形	愈 來 愈	愈 益	
愈 發	愈 趨	慎 加	愴 惶	搞 不 好	搭 搭	搖 身	搆 不 上	
新 的	新 近	暗 中	暗 地	暗 地 裡	暗 自	暗 暗	會 不 會	
會 中	會 在	會 有	會 否	會 的	會 會	業 已	業 市 場	
業 者	業 務	業 總 會	極 了	極 力	極 早	極 其	極 度	
極 為	概 要 地	概 略	楞 楞 地	源 源	溘 然	照 例	照 理	
照 章	照 實	照 說	照 樣	煞 是	煞 為	瑟 瑟	當 天	
當 日	當 年	當 作	當 即	當 局	當 初	當 面	當 庭	
當 時	當 眾	當 場	當 然	當 街	當 頭	當 衢	痴 痴	
睹 氣	碰 巧	萬 一	萬 人	萬 元	萬 分	萬 方	萬 片	
萬 台	萬 台 幣	萬 美 元	萬 套	萬 般	萬 張	萬 部	萬 萬	
萬 顆	節 量	節 節	經 月	經 由	經 年	經 常	經 意	
經 過	群 起	肆 意	落 去	蜂 湧	蜂 擁	補 提	解 決	
該 不 該	該 公	該 公 司	該 所	該 校	該 會	該 當	詳 加	
詳 敘	誇 入	誠 然	話 說	跡 近	跟 上	跟 腔	跟 著	
跨 入	較 為	載 譽	辟 拍	運 用	遂 告	遂 步	達 到	
過 于	過 去	過 份	過 來	過 於	過 度	逾 時	隔 山	
隔 日	隔 代	隔 夜	隔 岸	隔 宿	隔 週	零 點	預 先	
預 估	預 定	預 計	預 料	預 期	頓 時	頓 然	鼎 力	
像 是	嘎 啦	嘎 然	嘎 嘎	嘖 嘖	奪 門	實 地	實 在	
實 則	實 無	實 際	對 他	對 外	對 此	對 於	屢 次	
屢 屢	徹 夜	慷 然	慢 慢 兒	慢 說	截 力	截 至	截 然	
摸 黑	構 成	歉 然	滾 回 去	滴 答	漏 夜	滿 心	漸 次	
漸 形	漸 漸	漸 層	澈 夜	爾 後	盡 可 能	盡 快	盡 情	
盡 量	盡 管	盡 數	種 種	竭 力	竭 誠	竭 慮	端 然	
算 下 來	算 來	算 是	綜 上	綽 綽	緊 接 著	維 持	聞 風	
臺 北 訊	與 日	與 其	與 會	蓄 勢	蓄 意	蓋 因	裨 便	
認 為	誓 死	說 不 定	說 來	說 到 底	說 是	說 真 的	說 著	
赫 然	趕 忙	趕 早	趕 快	趕 著	趕 緊	輕 易	輕 意	
輕 聲	遠 道	遙 遙 地	需 求	需 要	頗 為	齊 力	齊 聲	
億 元	億 台 幣	億 美 元	價 價	劈 口	劈 哩	劈 啪	劈 頭	
厲 聲	嘻 嘻	嘩 拉	嘩 啦	嘩 啦 啦	嘩 嘩	噓 溜 溜	噓 噓	
噗 通	噗 噗	噗 哧	嘰 呱	嘰 哩	嘰 嘰	增 加	增 為	
增 產	增 設	幡 然	廣 加	廣 為	影 響	憤 然	憤 憤	
戮 力	撲 的	撲 通	撲 簌 簌	撲 騰 騰	撥 冗	暫 不	暫 且	
暫 告	暫 時	毅 然	潑 剌 剌	潛 心	潛 在	澎 澎	熱 呼 呼	
瑩 瑩	確 保	確 然	確 實	窮 極	緩 步	翩 然	衝 口	
諒 必	諸 多	調 到	調 整	論 件	質 言 之	輪 流	輪 區	
輪 番	輪 著	輪 翻	適 才	適 巧	適 足	適 足 以	適 時	
遷 往	鄭 重	靠 著	靠 邊	儘 力	儘 可 能	儘 早	儘 快	
儘 速	儘 量	儘 管	凝 神	噹 瑯	噹 噹	噹 啷	奮 力	
奮 身	奮 勇	奮 然	奮 筆	導 致	憑 以	憑 空	擅 自	
擁 有	據 了 解	據 云	據 以	據 信	據 悉	據 理	據 統 計	
據 傳	據 實	據 稱	據 聞	據 說	擇 要	整 個	整 整	
橫 加	橫 向	橫 豎	歷 久	歷 年 來	獨 力	獨 自	獨 個 兒	
獨 獨	積 極	親 口	親 手	親 耳	親 自	親 身	親 眼	
親 筆	謂 無	遲 早	遲 遲	隨 口	隨 之	隨 手	隨 地	
隨 而	隨 即	隨 步	隨 身	隨 車	隨 後	隨 時	隨 書	
隨 處	隨 著	隨 機	險 些	霎 那 間	霎 時	霎 時 間	霍 地	
霍 然	頻 於	頻 頻	頹 然	駭 然	默 默	壓 根	壓 根 兒	
彌 足	應 不 應	應 由	應 有	應 否	應 找	應 取	應 於	
應 按	應 是	應 然	應 當	應 該	應 運	應 對	應 認	
懂 得	擬 定	濠 淘	營 收	燦 然	獰 聲	環 寺	瞬 即	
磯 嗄	簌 簌	總 之	總 共	總 言 之	總 是	總 計	總 得	
總 會	總 算	總 歸	縱 令	縱 而	縱 身	縱 使	縱 或	
縱 然	聯 名	聯 合	聯 袂	膽 敢	臨 去	臨 末	臨 危	
臨 死	臨 別	臨 走	臨 陣	臨 溪	臨 睡	舉 凡	舉 目	
舉 行	舉 家	虧 得	豁 然	輾 轉	遽 然	遽 爾	還 不 如	
還 不 是	還 可 以	還 有	還 是	還 要	邁 向	邀 請	闊 步	
隱 約	隱 然	隱 隱	隱 隱 地	雖 則	雖 然	雖 說	鮮 少	
壘 得 分	擴 充	斷 然	斷 續	歸 哩	瞿 然	禮 貌 地	簡 言 之	
簡 直	藉 以	藉 由	藉 此	藉 故	藉 勢	藉 機	轉 而	
轉 為	轉 眼	轉 瞬	鎮 日	雙 雙	鵠 候	攏 嘛	礙 難	
穩 步	鏘 鏘	鏗 然	鏗 鏘	關 切	關 於	難 不 成	難 以	
難 免	難 怪	難 怪 乎	難 保	難 望	難 道	難 道 說	顛 悠	
嚶 嚶	嚴 加	嚴 重	攔 腰	競 相	繼 而	繼 續	覺 得	
飄 然	屬 於	屬 相	巍 然	攜 手	蠢 然	轟 通	轟 然	
轟 隆	轟 隆 隆	轟 轟	鐵 定	霹 哩	霹 啪	露 齒	響 響	
驀 地	驀 然	驀 然 間	黯 然	儼 然	歡 然	聽 來	聽 到	
讀 來	鑑 於	鑒 於	竊 竊	變 成	變 相	顯 出	顯 見	
顯 係	顯 然	讓 他	驟 然	躡 手	躡 步	躡 足	兀 自	
毌 須	呦 呦	怦 然	怦 怦	婕 婕	欸 乃	猝 然	喵 嗚	當 前	即 得
喵 喵	詎 料	瞅 空	噠 噠	嚓 嚓	本 創 作	本 發 明
設 有	設 在	提 供	上 述	前 述	具 有	藉 由	其 中	之 間
其 為	如 同	其 外	參 看	可 依	如 申	形 成	再 由	據 此
一 種
下 列
兩 側	兩 種
特 定	特 別
面 上	表 面 上
含 有	再 利 用

1;

