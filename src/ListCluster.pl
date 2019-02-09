#!/usr/bin/perl -s
    use strict; use vars;
    use DBI;
    use CGI qw/:standard/;
    #use CGI::Cookie;
    #%cookies = fetch CGI::Cookie;
    #$UserInfo = $cookies{'UserInfo'}->value;
# Examples of the input variables:
# <a href=ListCluster.pl?Action=1&CatID=$CatID&At=$J&UID=$UID&Odsn=$Odsn&Otable=$Otable>
    use Cluster;
    my $rDC = Cluster->new( ); # for calling Top2Lines();
    my($TreeStr, $DocList, $UID, $DBH, $Odsn, $Otable);  # Global vars.
    &main();
    exit;

sub main {
    my($Action, $UName, $Admin, $CatID, $At, $NID);
#    ($UID, $UName, $Admin) = ("2", "David", "1");
    $Action = param('Action');
    $UID = param('UID'); 
    $Odsn = param('Odsn'); 
    $Otable = param('Otable'); 
    $CatID = param('CatID');
    $At = param('At');
    $NID = param('NID');

    if ( @ARGV > 0 ) { # if run from DOS command
# perl -s ListCluster.pl 10 1 File ROC2 7544:-1
      ($UID, $Action, $Odsn, $Otable, $CatID, $At, $NID) = @ARGV;
    }
    $Odsn = 'File' if $Odsn eq '';
    $Otable = 'Src_Data' if $Otable eq '';
    $At = 0 if $At eq '';

    print "Content-type: text/html\n\n";
#print "I am here, Otalbe=$Otable, UID=$UID, Odsn=$Odsn<br>\n";
    $DBH = DBI->connect( "DBI:ODBC:$Odsn" )
#            or die "Can't make database connect: $DBI::errstr\n";
            or print "Can't make database connect: $DBI::errstr\n" || exit;
    $DBH->{LongReadLen}=1280000; # only work for SELECT, not for INSERT
    $DBH->{LongTruncOk} = 1;
    #Get Tree Info
    my $STH = $DBH->prepare("SELECT * FROM CTree WHERE CTUID = ?")
                 or die "Can't prepare SQL statement: $DBI::errstr\n";

# Fields in CTree are :
# CTID	CTName		CTDesc		CTUID	CTCTime
# 1	歸類展示樹	歸類展示樹	1	
    $STH->execute($UID);  
    my($CTID, $CTName) = $STH->fetchrow_array;
    $STH->finish;

    $TreeStr .= 'aux1 = insFld(foldersTree, gFld("'.$CTName.'", "0"));';
    #Get Tree Structure
    &GetCatalog($UID, -1, 1);
    if($Action) { #Get DocList if Action
	&DocList($CatID, $At); # show documents under some category
    }
    #Get DocID and ETC
#    &GetDoc($NID);
    &Result();
    $DBH->disconnect;
} # End of &Main()


# Set Global var. : $TreeStr
# Use Table: Catalog
# A recursive function to form a tree in JavaScript's representation
sub GetCatalog {
    my ($CUID, $CPID, $Layer) = @_;  my(@CataInfo, $I, @Tmp, $PS);
    my $Layer_add = $Layer + 1;
    my $STH = $DBH->prepare("SELECT * FROM Catalog WHERE CUID = ? AND CPID = ?")
             or die "Can't prepare SQL statement: $DBI::errstr\n";
# Fields in Catalog are:
# CID	CName	CDesc	CUID	CPID	CCTime
# 1	Test	Test	1	-1	
# 2	Test2		1	1	
# 3	Test3	Test3	2	-1
    $I = 0;
    $STH->execute($CUID, $CPID);
    while(@Tmp = $STH->fetchrow_array) {
	push(@CataInfo, @Tmp);
	$I++;
    }
#print "I=$I, CUID=$CUID, CPID=$CPID<br>\nCatalog=@CataInfo<br>\n"; exit;
    $STH->finish;
    for(my $J = 0, $PS = 0; $J < $I; $J++) {
        $TreeStr .= "aux".$Layer_add." = insFld(aux".$Layer.
	  ', gFld("'.$CataInfo[$PS+1].'", "'.
	  "$CataInfo[$PS]:$CataInfo[$PS+4]".'"));';
        &GetCatalog($CUID, $CataInfo[$PS], $Layer_add);
        $PS = $PS + 6;
    }
} # End of &GetCatalog()


# Use global : $DBH
# Get Class Name by Class ID
sub CID2CName {
    my($UID, $CID) = @_;
    my $STH = $DBH->prepare("SELECT CName FROM Catalog WHERE CUID = ? and CID = ?")
                 or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($UID, $CID);
    my ($CName) = $STH->fetchrow_array;
    $STH->finish;
    return $CName;
}

# Given a CID, return all the CIDs who are the descendants of the given CID
sub ExpandCID {
    my($UID, $CID) = @_; my($STH, $sql, @CIDs, $cid, @SubCIDs);
#   return (); # if we don't want to expand
    $sql = "SELECT CID FROM Catalog WHERE CUID = ? AND CPID = ? order by CID";
    $STH = $DBH->prepare($sql)
        or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($UID, $CID);
    while($cid = $STH->fetchrow_array) {
        push(@CIDs, $cid); # push document IDs into @NIDS
    }
    $STH->finish;
    foreach $cid (@CIDs) { 
    	push @SubCIDs, &ExpandCID($UID, $cid); 
    }
    return @CIDs, @SubCIDs;
}

# Use global : $UID, $Otable
sub DocList {
    my($CatID, $At) = @_;

    my ($NID, @NIDS, $CName, $CID, $PID, $STH, $sql, @CIDs, $cid);
    ($CID, $PID) = split(/:/, $CatID);
    $CName = &CID2CName($UID, $CID); # Get Class Name
    @CIDs = ($CID, sort {$a <=> $b} &ExpandCID($UID, $CID));
#print "CIDs=@CIDs<p>\n";

# Given $CID and $UID, Set @NIDS : list of record IDs
    foreach $cid (@CIDs) {
    	$sql = "SELECT NID FROM Classify WHERE CTID = ? AND CID = ? order by NID";
	$STH = $DBH->prepare($sql)
	    or die "Can't prepare SQL statement: $DBI::errstr\n";
	$STH->execute($UID, $cid);
	while($NID = $STH->fetchrow_array) {
	    push(@NIDS, $NID); # push document IDs into @NIDS
	}
	$STH->finish;
    }


# Split 15 record to 1 page
    my($Counts, $Pages, $Pag, $Limit, $RecPerPage, $Pos, $Rows);
    $Counts = @NIDS = sort @NIDS; # important to sort the did
    $RecPerPage = 15;
    $Pages  = int($Counts/$RecPerPage)+1;
    $Limit = ($At+10 > $Pages) ? $Pages : $At+10; # why 10?

    $DocList .=<<END_OF_HTML;
         <div id="divnone" style="display=''">
  <table border="1" width="650" style="border-collapse: collapse" bordercolor="#000000" cellpadding="0" cellspacing="0" bgcolor="#cccccc">
    <tr>
    <TD colspan="4">&nbsp;<font color="blue">$CName</font>&nbsp;&nbsp;<strong>完成歸類文件列表</strong>
    &nbsp;&nbsp;共有 $Counts 筆資料
    </td></tr>
END_OF_HTML

    $Pag .= "<table width='100%'><tr><td width='20%' align='Center'><b>共有$Counts筆資料</b></td><td align='Center'>";
    for(my $J = $At; $J < $Limit; $J++) {
	$Pag .= "<a href=ListCluster.pl?Action=1&CatID=$CatID&At=$J&UID=$UID&Odsn=$Odsn&Otable=$Otable>"
	     . ($J+1) ."</a>&nbsp;";
    }
    $Pag .= "</td></tr></table>";
    
    if(!$Counts) {
	$Pag =<<END_OF_HTML;
	<script language="JavaScript">
	        alert("本類別現無任何資料");
	</script>
END_OF_HTML
    }

    my(@D, $body);
    $Pos = $At * $RecPerPage;
    $Rows = ( $Pos+$RecPerPage > $Counts) ? $Counts : $Pos + $RecPerPage;
# Fetch each Record's Content
    $STH = $DBH->prepare("SELECT ID, Desc, FName, DName, SNo FROM $Otable WHERE ID = ?")
              or die "Can't prepare SQL statement: $DBI::errstr\n";
    for(my $I = $Pos; $I < $Rows; $I++) {
	$STH->execute($NIDS[$I]);
	@D = $STH->fetchrow_array; $body = $D[1]; 
	$body = $rDC->Top2Lines($body, 320); # maximum 120 characters.
	$DocList .=<<END_OF_HTML;
	   <TR bgColor=#e3f4fb>
	   <TD align=left width="7%"><STRONG>$D[2]</STRONG></TD>
	   <TD align=left width="27%"><STRONG>$D[3]</STRONG></TD>
	   <TD align=left width="7%"><STRONG>$D[4]</STRONG></TD>
	   <TD align=left width="59%"><STRONG>$body</STRONG></TD>
	   </TD></TR>
END_OF_HTML
#<!--<A href="../ShowDoc.pl?NID=$NIDS[$I]" Target="_blank">$body</A>-->
    }
    $DocList .=<<END_OF_HTML;
         </table>
         <div align="center">$Pag</div>
         </div>
END_OF_HTML
} # End of &DocList

# Currently not used
sub GetDoc {
    my($NID) = @_;
    my $STH = $DBH->prepare("SELECT * FROM $Otable WHERE ID = ?")
              or die "Can't prepare SQL statement: $DBI::errstr\n";
    $STH->execute($NID);
    my @DocInfo = $STH->fetchrow_array;
    $STH->finish;

    my $SinDoc =<<END_OF_HTML;
    <tr>
    <td width="11%"><strong><font color="#000000">目前文件 : &nbsp;</font></strong></td>
    <td width="20%" align="middle"><strong><font color="#993300">$DocInfo[2]</font></strong></td>
    <td><strong>$DocInfo[1]</strong></td>
    </tr>
END_OF_HTML

    my $NIDStr =<<END_OF_HTML;
    <input type="hidden" name="NID" value="$DocInfo[0]">
END_OF_HTML
} # End of &GetDoc()


sub Result {
    print <<END_OF_HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD><TITLE>歡迎使用威知自動歸類系統</TITLE>
<META http-equiv=Content-Type content="text/html; charset=BIG5">
<META http-equiv=Content-Style-Type content=text/css>
<LINK href="./Master.css" type=text/css rel=stylesheet>
<LINK href="./images.css" type=text/css rel=stylesheet>

<SCRIPT src="ua.js"></SCRIPT>
<SCRIPT src="ftiens4.js"></SCRIPT>
<SCRIPT langyage="JavaScript">
function modifydoccat(obj){
        var formstr = eval("document." + obj );
        if(formstr.action.value==0){
                if(confirm("確定要將文件從此類別移除?")) {
                        formstr.submit();
                }
        }else{
                if(document.ft.ID.value.length <=0){
                        alert("請在左方分類樹列表選取目的類別");
                        return false;
                }else if(document.ft.ID.value == formstr.OCATID.value){
                        alert("不可移動至相同類別\\n請選擇其他類別!");
                        return false;
                }else{
                        formstr.NCATID.value = document.ft.ID.value;
                        if(confirm("是否要將文件移出原有類別?\\n(\\"確定\\" - YES ; \\"取消\\" - NO)")) {
                                           formstr.action.value = "2";
                                           formstr.submit();
                        }else {
                                        formstr.submit();
                        }
                }

        }
}
function modifydoccat1(obj){
        var formstr = eval("document." + obj );
        if(confirm("確定要將文件從此類別移除?")) {
                        formstr.submit();
        }
}
</SCRIPT>
<SCRIPT language=JavaScript>

USETEXTLINKS  = 1;            //replace 0 with 1 for hyperlinks

STARTALLOPEN  = 1;            //replace 0 with 1 to show the whole tree

ICONPATH      = './Img/';    //change if the gif's folder is a subfolder, for example: 'images/'

HIGHLIGHT     = 0;
PERSERVESTATE = 1;
USEICONS      = 1;
BUILDALL      = 1;

function generateCheckBox(parentfolderObject, itemLabel, checkBoxDOMId) {
        var newObj;
        newObj = insDoc(parentfolderObject, gLnk("R", itemLabel, "javascript:parent.op()"));
        newObj.prependHTML = "<input type=checkbox id="+checkBoxDOMId+">";
}
function generateRadioB(parentfolderObject, itemLabel, checkBoxDOMId) {
        var newObj;

        newObj = insDoc(parentfolderObject, gLnk("R", itemLabel, "javascript:parent.op()"));

        newObj.prependHTML = "<td valign=middle><input type=radio name=hourPick id="+checkBoxDOMId+"></td>";
}

foldersTree = gFld("知識樹結構", "0");
foldersTree.treeID = "checkboxTree";

$TreeStr

function linkFolderHTML(isTextLink)
{
  var docW = "";

  if (this.hreference)
  {
//    docW = docW + "<span id=i" +this.hreference +" style=\\"color=blue\\">";

    if(this.hreference == "0")                docW = docW + "<!--";
        docW = docW + "<input type='radio' name='mcid' id=\\""+this.hreference+"\\" ";
    if (browserVersion > 0)
      docW = docW + " onClick='javascript:clickOnOption(\\""+this.hreference+"\\",this);'";

    docW = docW + ">";

    docW = docW  + "<a href=\\"ListCluster.pl?Odsn=$Odsn&Otable=$Otable&UID=$UID&Action=1&CatID="+this.hreference+"\\">";

    if(this.hreference == "0")                docW = docW + "-->";

  }
  else
    docW = docW + "<a>";

  return docW;
}
function clickOnOption(tmpID,oj) {
    document.ft.ID.value = tmpID;

//        document.getElementById("i"+tmpID).style.color="#000000";
}
</SCRIPT>
</HEAD>

<body background="./Img/leftline3.jpg" topMargin=0 marginheight="0">
<TABLE width="100%" border=0>
  <TBODY>
  <TR>
    <TD vAlign=top colSpan=2 height=27>
      <DIV style="LEFT: 25px; POSITION: absolute; TOP: 10px">
      <TABLE height=27 cellSpacing=0 cellPadding=0 width="100%" border=0>
        <TBODY>
        <TR>
          <TD class=Darkbg width="30%" bgColor=#911114><FONT
            class=27>文件瀏覽</FONT></TD>
          <TD class=Darkbg align=left width="70%">
          </TD>
        </TR>
        </TBODY>
      </TABLE>
      </DIV>
    </TD>
  </TR>
  <TR>
    <TD vAlign=top width="35%">
     <DIV style="LEFT: 25px; POSITION: absolute; TOP: 20px">
      <TABLE style="BORDER-COLLAPSE: collapse" borderColor=#000000 cellSpacing=0 cellPadding=0 border=0>
        <TBODY>
        <TR>
          <TD><A href="http://www.treemenu.net/" target=_blank></A></TD>
        </TR>
        </TBODY>
      </TABLE>
      <FORM name=ft action=DocChange.pl>
      <!-- Build the browser's objects and display default view of the tree. -->
      <SCRIPT>initializeDocument()</SCRIPT>
      <BR><BR>
      <INPUT type=hidden name=ID>
      </FORM></TD>
      <TD valign="top" align="center">
      $DocList
      </TD>
      </TR>
      </FORM>
      </DIV>
</table>
</BODY>
</HTML>
END_OF_HTML
} # End of &Result()
