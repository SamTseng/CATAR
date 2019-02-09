#!/usr/bin/perl -s
use CGI qw/:standard/;
$uid = int rand()*10000;



print "Content-type: text/html\n\n";
print <<HTMLEND;
<html>
<head>
<title>文件、詞彙自動歸類展示
</title>
</head>
<body bgcolor=white>
<center>
<h2>文件、詞彙自動歸類展示</h2>
<form method=get action="ClusterDB.pl" target="mainFrame">
<input type=hidden name="Ouid" value=$uid>
<table border=1>
<tr>
<td align=center>
索引群組：<input type=text name="Ogrp" value="NanoPat" size=7>
門檻值：<input type=text name="threshold" value="0.1" size=3>
<td align=center>輸出類別數：
<input type=text name="MaxCluster" value="12" size=3>
<td align=center>標題詞彙數：
<input type=text name="NumCatTitleTerms" value="3" size=3>
<td align=center>標題詞門檻：
<input type=text name="Oct_low_tf" value="1" size=3>
<td align=center>標題詞排序：
<select name="Otfc" width=3>
    <option selected value="Chi">Chi
    <option value="TFC">TFC
    <option value="ChixTFC">ChixTFC
</select>
<input type=submit value="執行">

<tr>
<td width=25%>門檻值介於 0 到 1 之間，越接近 1，歸類在一起的文件越相似。<br>
建議值：0.90 - 0.98 之間可做複本偵測或同案追蹤。<br>
	0.6 - 0.9 之間可做類似公文偵測。
<td width=15%>建議值 5-20 之間，視使用者端電腦速度，此值越大速度越慢。
<td width=15%>建議值 2 - 4 之間。
<td width=15%>建議值 0 - 2 之間。
<td width=25%>建議值 Chi 或 ChixTFC
</table>
</form>
</center>
</body>
</html>
HTMLEND
