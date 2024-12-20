/*
	Copyright 2010 by Robin W. Spencer

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You can find a copy of the GNU General Public License
    at http://www.gnu.org/licenses/.
    
Many types of data can be represented as trees, 
and so are nicely shown as <i>dendrograms</i>.  
In particular, when the data consist of objects separated by known distances, 
many types of <i>clustering</i> will put them in tree form.  
That's what's going on here: we have city data 
(where distance has its familiar meaning), random data, and 
text data from Shakespeare where "social distance" is inversely proportional 
to the number of times that characters have consecutive speeches (and so
 are probably conversing).   
See also <a href="http://scaledinnovation.com/analytics/trees/treemaps.html">
these treemap</a> and 
<a href="http://scaledinnovation.com/analytics/trees/fractalmaps.html">
	fractal map</a> representations of the same data.

So there's a lot of classic computer science in this page's code:  data 
preparation, representation of 2D distance matrices as fast 1D hash 
tables, hierarchic clustering, recursive routines galore to turn the 
trees into pixel positions.  Plus plenty of trigonometry for the 
circular diagram.  With a modern browser (Safari, Chrome, Firefox, 
Opera), it's all fast enough.

The circular and bezier dendrograms are done in canvas and won't work in
 non-compliant browsers (i.e., IE).  The native support for quadratic 
bezier curves in canvas makes the curvy connectors easy.  The lower-left
 boxes-and-sticks dendrogram is done with positioned DIV elements and 
works across browsers.  The spectrum-sequence coloring is done by 
working in HSV color space, far more natural than RGB.

*/

function unique(a){
  //  Return an alphabetized copy of the unique items in any array
  a.sort(function(x,y){return x<y?-1:1;});
  var b=[];
  var previous="";
  for(var i=0;i<a.length;i++){
     if(a[i]!==previous){
        b.push(a[i]);
        previous=a[i];
     }
  }
  return b;
}


function romeoData(){
    return [
        {"speech":0,"scene":"","name":"Chorus"},
        {"speech":1,"scene":"Act I, Scene I","name":"Sampson"},
        {"speech":2,"scene":"Act I, Scene I","name":"Gregory"},
        {"speech":3,"scene":"Act I, Scene I","name":"Sampson"},
        {"speech":4,"scene":"Act I, Scene I","name":"Gregory"},
        {"speech":5,"scene":"Act I, Scene I","name":"Sampson"},
        {"speech":6,"scene":"Act I, Scene I","name":"Gregory"},
        {"speech":7,"scene":"Act I, Scene I","name":"Sampson"},
        {"speech":8,"scene":"Act I, Scene I","name":"Gregory"},
        {"speech":9,"scene":"Act I, Scene I","name":"Sampson"},
        {"speech":10,"scene":"Act I, Scene I","name":"Gregory"},
        {"speech":20,"scene":"Act I, Scene I","name":"Gregory"},
        {"speech":840,"scene":"Act V, Scene III","name":"Prince"}
    ];
}
function socialDistances(source){
    //  Compute a simple 'social distance' value based on the sequence of speeches in a play
    switch(source){
        case "romeo":var entries=romeoData();break;
        case "dream":var entries=dreamData();break;
    }
    //  Build array of names, and associative array back to keys
    var names=[];
    for(var i=0;i<entries.length;i++){
        names.push(entries[i].name);  
    }
    names=unique(names);
    var nameToKey=[];
    for(var i=0;i<names.length;i++){  
        nameToKey[names[i]]=i;
    }
    //  Count "chats" by actors' names = adjacent speeches in the same scene
    var chats=[];
    var name="";
    var scene="";
    var prevName="zzz";
    var prevScene="zzz";
    for(var i=0;i<entries.length-1;i++){
        name=entries[i].name;
        scene=entries[i].scene;
        if(scene==prevScene){
            var n1=nameToKey[name];
            var n2=nameToKey[prevName];
            var hashCode=(Math.min(n1,n2)+"~"+Math.max(n1,n2)); // hash always has left key < right key
            if(!chats[hashCode]){chats[hashCode]=0}
            chats[hashCode]+=1;
        }
        prevName=name;
        prevScene=scene;
    }
    var maxChats=-Infinity;
    for(hash in chats){
        maxChats=Math.max(chats[hash],maxChats);
    }
    //  "Social distance" is a function of how many "chats" you have,
    //  it's 0.00 for the maximum chatting pair and 1.00 for pairs that never talk.
    var distances=[];
    for(hash in chats){
        distances[hash]=1.0-chats[hash]/maxChats;
    }
    //  Fill in "non conversations" with a high "social distance" that
    //  will not torque the clustering weighted averages too badly.
    for(var i=0;i<names.length-1;i++){
        for(var j=i+1;j<names.length;j++){
            var hash=i+"~"+j;
            if(!distances[hash]){distances[hash]=2.0}
        }
    }
    return {"names":names,"distances":distances};  
}
function cityDistances(nSubset){
    var data=[
        ['�x�_',-99.92,16.83],  // data are longitude (E of Greenwich) and latitude (N)
        ['Amsterdam',4.90,52.37],
        ['����',-57.67,-25.27],
        ['Atlanta',-84.38,33.75],
        ['Auckland',174.78,-36.85],
        ['Barbados',-59.62,13.12],
        ['Barcelona',2.18,41.38],
        ['Washington DC',-77.03,38.90],
        ['Zurich',8.55,47.37]
    ];
    var distances=[];
    var names=[];
    nSubset=nSubset || data.length;
    var n=Math.min(nSubset,data.length);
    radPerDeg=Math.PI/180;
    for(var i=0;i<n-1;i++){
        var ci=data[i];
        names[i]=ci[0];
        for(var j=i+1;j<n;j++){
            var cj=data[j];
            var hashKey=i+"~"+j;            
            //   Great Circle distance            
            var a=Math.sin(radPerDeg*ci[2])*Math.sin(radPerDeg*cj[2]);
            a+=Math.cos(radPerDeg*ci[2])*Math.cos(radPerDeg*cj[2])*Math.cos(radPerDeg*(ci[1]-cj[1]));
            distances[hashKey]=Math.round(3960*Math.acos(a));
        }
    }
    names[n-1]=data[n-1][0];
    return {"names":names,"distances":distances};
}
function randomDistances(n){
    //  For this demo we need artificial data.  This is an
    //  indirect but realistic approach: assign random inter-point
    //  distances, then do hierarchic clustering to build the tree.
    var distances=[];
    var names=[];
    for(var i=0;i<n-1;i++){
        names[i]="point "+i;
        for(var j=i+1;j<n;j++){
            var hashKey=i+"~"+j;
            distances[hashKey]=Math.random();   //  1D hash table instead of a 2D matrix, fast and sparse
        }
    }
    names[n-1]="point "+(n-1);
    return {"names":names,"distances":distances};
}
function HSVtoRGB(h,s,v,opacity){
  // inputs h=hue=0-360, s=saturation=0-1, v=value=0-1
  // algorithm from Wikipedia on HSV conversion
    var toHex=function(decimalValue,places){
        if(places == undefined || isNaN(places))  places = 2;
        var hex = new Array("0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F");
        var next = 0;
        var hexidecimal = "";
        decimalValue=Math.floor(decimalValue);
        while(decimalValue > 0){
            next = decimalValue % 16;
            decimalValue = Math.floor((decimalValue - next)/16);
            hexidecimal = hex[next] + hexidecimal;
        }
        while (hexidecimal.length<places){
            hexidecimal = "0"+hexidecimal;
        }
        return hexidecimal;
    }

    var hi=Math.floor(h/60)%6;
    var f=h/60-Math.floor(h/60);
    var p=v*(1-s);
    var q=v*(1-f*s);
    var t=v*(1-(1-f)*s);
    var r=v;  // case hi==0 below
    var g=t;
    var b=p;
    switch(hi){
        case 1:r=q;g=v;b=p;break;
        case 2:r=p;g=v;b=t;break;
        case 3:r=p;g=q;b=v;break;
        case 4:r=t;g=p;b=v;break;
        case 5:r=v;g=p;b=q;break;
    }
    //  At this point r,g,b are in 0...1 range.  Now convert into rgba or #FFFFFF notation
    if(opacity){
        return "rgba("+Math.round(255*r)+","+Math.round(255*g)+","+Math.round(255*b)+","+opacity+")";
    }else{
       return "#"+toHex(r*255)+toHex(g*255)+toHex(b*255);
    }
}
function hexToCanvasColor(hexColor,opacity){
    // Convert #AA77CC to rbga() format for Firefox
    opacity=opacity || "1.0";
    hexColor=hexColor.replace("#","");
    var r=parseInt(hexColor.substring(0,2),16);
    var g=parseInt(hexColor.substring(2,4),16);
    var b=parseInt(hexColor.substring(4,6),16);
    return "rgba("+r+","+g+","+b+","+opacity+")";
}
function treeWalk(currentNode,tree,depth,doLeafAction,doDownAction,doUpAction){
    //  General purpose recursive binary depth-first tree walk, with three possible action functions:
    //  at each leaf node, on the way down a branch, and on the way back up a branch.
    if(tree[currentNode].leftChild>-1){
        depth+=1;
        if(doDownAction){doDownAction(currentNode,tree,depth)}
        treeWalk(tree[currentNode].leftChild,tree,depth,doLeafAction,doDownAction,doUpAction);
    }
    if(tree[currentNode].rightChild==-1){ // It's a leaf node
        if(doLeafAction){doLeafAction(currentNode,tree,depth)}
    }
    if(tree[currentNode].rightChild>-1){
        treeWalk(tree[currentNode].rightChild,tree,depth,doLeafAction,doDownAction,doUpAction);
        if(doUpAction){doUpAction(currentNode,tree,depth)};
        depth-=1;
    }
}
function addClosestPair(tree,distances){
    //  Identify closest pair    
    var n=tree.length;
    var dMin=Infinity;
    for(var i=0;i<n-1;i++){
        for(var j=i+1;j<n;j++){
            var d=distances[i+"~"+j];
            if(d<dMin && tree[i].inPlay && tree[j].inPlay){
                var iMin=i;
                var jMin=j;
                dMin=d;
            }
        }    
    }    
    //  Add new node and flag old ones    
    tree.push({"parent":-1,"leftChild":iMin,"rightChild":jMin,"inPlay":true});
    tree[iMin].inPlay=false;
    tree[iMin].parent=n;  // the new one we just created
    tree[jMin].inPlay=false;
    tree[jMin].parent=n;  // the new one we just created
//alert("iMin="+iMin+", jMin="+jMin+", dMin="+dMin+", n="+n);
    //  Add distances to the new node
    for(var i=0;i<=n;i++){
        var di=distances[Math.min(i,iMin)+"~"+Math.max(i,iMin)];  // Hash code has left<right key always
        var dj=distances[Math.min(i,jMin)+"~"+Math.max(i,jMin)];
//        if(di && dj){distances[i+"~"+n]=(di+dj)/2} // Average Link
        if(di && dj){distances[i+"~"+n]=Math.max(di,dj)} // Complete Link
//        if(di && dj){distances[i+"~"+n]=Math.min(di,dj)} // Single Link
    }
}

/* 
function buildTree_original_function(n,source){
    switch(source){
        case "cities":{
            var dataObj=cityDistances(n);break;
        }
        case "romeo":{
            var dataObj=socialDistances("romeo");break;
        }
        default:
            var dataObj=randomDistances(n);
    }
*/ // The above lines in comment is replaced by the next 2 lines:
function buildTree(n,source){  // source: Cluster i, n: NumOfDoc in Cluster i
    var dataObj=catarDistances(n, source);
//    var dataObj=cityDistances(n);

    //  Initialize tree
    n=dataObj.names.length;  //  in case a fixed dataset doesn't have this many nodes
    var tree=[];
    for(var i=0;i<n;i++){
        tree.push({"parent":-1,"leftChild":-1,"rightChild":-1,"inPlay":true});
    }    
    while(tree.length<(2*n-1)){
        addClosestPair(tree,dataObj.distances);    //  Classic hierarchic clustering
    }
    
    //  Add the weight of each node = number of sub-nodes it has,
    //  and coloring index = sequence of visit
    var index=0;
    var root=tree.length-1;
    treeWalk(root,tree,0,function(currentNode,tree,depth){
        tree[currentNode].weight=1;
        tree[currentNode].index=index;
        index+=1;
    },null,function(currentNode,tree,depth){
        var leftWeight=tree[tree[currentNode].leftChild].weight;
        var rightWeight=tree[tree[currentNode].rightChild].weight;
        tree[currentNode].weight=leftWeight+rightWeight;
    });
    
    return {"tree":tree,"distances":dataObj.distances,"root":root,"names":dataObj.names};
}
function drawDendrogram(tree,root,names,divId,width){
    var e=document.getElementById(divId);
    e.style.position="relative";
    var dy=20; //  fixed for legibility
    e.style.width=width+"px";
    e.style.height=Math.round((0.5*tree.length+2)*dy)+"px";
    
    //  Set the positions
    var y=0;
    var maxWeight=-Infinity;
    treeWalk(root,tree,0,function(node,tree,depth){  
        y+=dy;
        tree[node].top=y;
    },
    null,
    function(node,tree,depth){  
        tree[node].top=(tree[tree[node].leftChild].top+tree[tree[node].rightChild].top)/2;
        if(tree[node].weight>maxWeight){maxWeight=tree[node].weight}
    });
    
    //  Adjust the x-coordinates to fit the given frame.  Note scale compression to show leaf details
    for(var i=0;i<tree.length;i++){
        tree[i].left=Math.round(width*Math.pow((maxWeight-tree[i].weight)/(maxWeight-1),3));
    }
    
    //   Draw the diagram  
    var t="";
    treeWalk(root,tree,0,function(node,tree,depth){
        var thisNode=tree[node];
        var hue=Math.round(250*thisNode.index/((1+tree.length)/2));
        var color=HSVtoRGB(hue,0.3,1);
        t+="<div class='leaf' style='background:"+color
         +";top:"+(thisNode.top-7)+"px;left:"+thisNode.left+"px;'><b>"
         +names[node]+"<\/b><\/div>";
    },
    null,
    function(node,tree,depth){  //  Draw the connecting lines on the way back up the traverse
        var thisNode=tree[node];
        var y1=tree[thisNode.leftChild].top;
        var y2=tree[thisNode.rightChild].top;
        var w1=tree[thisNode.leftChild].left-thisNode.left;
        var w2=tree[thisNode.rightChild].left-thisNode.left;        
        t+="<div class='cap'  style='top:"+y1+"px;left:"+thisNode.left+"px;height:"+(y2-y1)+"px;'><\/div>";
        t+="<div class='drop' style='top:"+y1+"px;left:"+thisNode.left+"px;width:"+w1+"px;'>&nbsp;<\/div>";
        t+="<div class='drop' style='top:"+y2+"px;left:"+thisNode.left+"px;width:"+w2+"px;'>&nbsp;<\/div>";
    });
    e.innerHTML=t;    
}
function drawCircularDendrogram(tree,root,names,divId,width,showLabels){
    if(showLabels){
        //  We need to assure our frame doesn't clip the labels, so we find the longest label here.
        var maxLabel=-Infinity;
        for(var i=0;i<names.length;i++){
            maxLabel=Math.max(maxLabel,names[i].length);
        }
    }
    var pxPerPtPerChar=0.507;  //  Empirical finding for bold sans in canvas
    var edge=Math.round(1+maxLabel*12*pxPerPtPerChar);

    var e=document.getElementById(divId);
    if(tree.length>50){width*=1.5}
    width=2*edge+Math.round(50*Math.sqrt(tree.length));
    e.width=width;
    e.height=width;
    var maxR=Math.round((width-2*edge)/2);
    var ctx=e.getContext('2d');
    if(!ctx){return}
    ctx.translate(width/2,width/2);
    ctx.beginPath();
    ctx.lineWidth=1;
    ctx.strokeStyle="rgba(0,0,0,0.3)";
//   ctx.arc(0,0,maxR,0.0,2*Math.PI,false);
    ctx.closePath();
    ctx.stroke();
    ctx.strokeStyle="rgba(0,0,0,0.6)";
    
    //  Set the positions
    var theta=0.0;
    var dTheta=4.0*Math.PI/(tree.length+1);
    var maxWeight=-Infinity;
    
    function weightToRadius(wt){
        var f=(maxWeight-wt)/(maxWeight-1);
        return 6+(maxR-32)*f*f;
    }
    
    treeWalk(root,tree,0,function(node,tree,depth){  
        tree[node].radius=maxR;
        tree[node].theta=theta;
        theta+=dTheta;
    },
    null,
    function(node,tree,depth){  
        tree[node].theta=(tree[tree[node].leftChild].theta+tree[tree[node].rightChild].theta)/2;;
        if(tree[node].weight>maxWeight){maxWeight=tree[node].weight}
    });
    
    for(var i=0;i<tree.length;i++){
        tree[i].radius=weightToRadius(tree[i].weight);
    }
        
    //   Draw the diagram
    ctx.fillStyle="rgba(0,0,0,1)";
    ctx.font='bold 12px sans-serif';
    var blobRadius=12;
    
    treeWalk(root,tree,0,function(node,tree,depth){
        //   Draw leaf labels
        var thisNode=tree[node];
        var hue=Math.round(250*thisNode.index/((1+tree.length)/2));
        var color=HSVtoRGB(hue,0.3,1);               
        ctx.lineWidth=1.5;
        ctx.strokeStyle="rgba(0,0,0,1)";
        
        ctx.fillStyle=hexToCanvasColor(color,0.8);
        
        if(!showLabels){
            //  Just show numbered circles
            var r=maxR-blobRadius-2;
            var px=Math.round(r*Math.cos(thisNode.theta));
            var py=Math.round(r*Math.sin(thisNode.theta));     
            ctx.save();   
            ctx.beginPath();
            ctx.arc(px,py,blobRadius,0.0,2*Math.PI,false);
            ctx.fill();
            ctx.closePath();
            ctx.fillStyle="rgba(0,0,0,0.8)";
            var w=ctx.measureText(node).width;
            ctx.fillText(node,px-w/2,py+4);
            ctx.stroke();
            ctx.restore();
        }else{
            //  Show color dots and rotated text labels
            var r=maxR-19;
            var px=Math.round(r*Math.cos(thisNode.theta));
            var py=Math.round(r*Math.sin(thisNode.theta));
            ctx.save();
            ctx.fillStyle=hexToCanvasColor(color,1);
            ctx.shadowColor="rgba(0,0,0,0.3)";
            ctx.shadowOffsetX=2;
            ctx.shadowOffsetY=2;
            ctx.shadowBlur=4;
            ctx.beginPath();
            ctx.arc(px,py,7,0.0,2*Math.PI,false);
            ctx.fill();
            ctx.fillStyle="rgba(0,0,0,0.4)";
            ctx.shadowColor="rgba(0,0,0,0)"; // nix the shadow
            ctx.rotate(thisNode.theta);
            var w=ctx.measureText(names[node]).width;
            if(thisNode.theta<1.57 || thisNode.theta>4.71){ // right of center, so text OK
                ctx.fillText(names[node],r+12,4);   
            }else{                                          // left of center, so flip the text
                ctx.save();
                ctx.rotate(Math.PI);
                ctx.fillText(names[node],-r-w-12,4);
                ctx.restore();
            }
            ctx.stroke();
            ctx.restore();
        }
    },
    null,
    function(node,tree,depth){  //  Draw the connecting lines on the way back up the traverse
        var thisNode=tree[node];
        var th1=tree[thisNode.leftChild].theta;
        var th2=tree[thisNode.rightChild].theta;
        var w1=tree[thisNode.leftChild].left-thisNode.left;
        var w2=tree[thisNode.rightChild].left-thisNode.left;

        var r1=weightToRadius(tree[thisNode.leftChild].weight);
        var r2=weightToRadius(tree[thisNode.rightChild].weight);
        var px=Math.round(r1*Math.cos(th1));
        var py=Math.round(r1*Math.sin(th1));
        //  Emphasize local clusters with darker connectors
        ctx.strokeStyle="rgba(0,0,0,"+Math.pow(0.5*(r1+r2)/maxR,2)+")";
        ctx.lineWidth=1.5; // Math.max(0.75,2*r/maxR);

        ctx.beginPath();
        ctx.moveTo(px,py);
        ctx.arc(0,0,thisNode.radius,th1,th2,false);
        
        px=Math.round(r2*Math.cos(th2));
        py=Math.round(r2*Math.sin(th2));        
        ctx.lineTo(px,py);
        ctx.stroke();        
    });
}
function drawBezierDendrogram(tree,root,names,divId,useBeziers,flushRight){
    var e=document.getElementById(divId);
    var dy=20; //  fixed for legibility
    //  Scale for legibility
    var width=Math.round(50*Math.sqrt(tree.length));
    e.width=width;
    e.height=Math.round(dy*(1+tree.length)/2);
    var ctx=e.getContext('2d');
    if(!ctx){return}

    //  Set the positions
    var y=0;
    var maxLabelWidth=100;
    var maxWeight=-Infinity;
    treeWalk(root,tree,0,function(node,tree,depth){  
        tree[node].top=y;
        y+=dy;
    },
    null,
    function(node,tree,depth){  
        tree[node].top=Math.round((tree[tree[node].leftChild].top+tree[tree[node].rightChild].top)/2);
        if(tree[node].weight>maxWeight){maxWeight=tree[node].weight}
    });
    
    //  Adjust the x-coordinates to fit the given frame.  Note scale compression to show leaf details
    var maxLinks=-Infinity;
    for(var i=0;i<tree.length;i++){
        var linksToRoot=0;
        var node=i;
        while(node!=root){
            var parent=tree[node].parent;
            linksToRoot+=1;
            node=parent;
        }
        tree[i].linksToRoot=linksToRoot;
        maxLinks=Math.max(maxLinks,linksToRoot); 
    }    
    for(var i=0;i<tree.length;i++){
        if(flushRight){
            tree[i].left=2+Math.round((width-maxLabelWidth-3)*Math.pow((maxWeight-tree[i].weight)/(maxWeight-1),2));
        }else{
            tree[i].left=2+Math.round((width-maxLabelWidth-3)*Math.pow(tree[i].linksToRoot/maxLinks,1));
        }
    }
        
    //   Draw the diagram
    ctx.save();
    ctx.fillStyle="rgba(0,0,0,1)";
    ctx.font='bold 11px sans-serif';
    
    treeWalk(root,tree,0,function(node,tree,depth){
        //   Draw leaf labels        
        var thisNode=tree[node];
        var hue=Math.round(250*thisNode.index/((1+tree.length)/2));
        var color=HSVtoRGB(hue,0.3,1);               
        ctx.lineWidth=1;
        ctx.strokeStyle="rgba(0,0,0,0.7)";
        ctx.fillStyle=hexToCanvasColor(color,1);
        var w=ctx.measureText(names[node]).width;
        ctx.shadowColor="rgba(0,0,0,0.7)";
        ctx.shadowOffsetX=1;
        ctx.shadowOffsetY=1;
        ctx.shadowBlur=4;
        ctx.fillRect(thisNode.left,thisNode.top,maxLabelWidth,14);
        ctx.shadowOffsetX=0;
        ctx.shadowOffsetY=0;
        ctx.shadowBlur=0;
    //    ctx.strokeRect(thisNode.left,thisNode.top,maxLabelWidth,14);
        ctx.fillStyle="rgba(0,0,0,0.7)";
        ctx.fillText(names[node],thisNode.left+4,thisNode.top+11);
    },
    null,
    function(node,tree,depth){  //  Draw the connecting lines on the way back up the traverse
        var thisNode=tree[node];
        var y1=Math.round(tree[thisNode.leftChild].top+dy/2-2);
        var y2=Math.round(tree[thisNode.rightChild].top+dy/2-2);
        var w1=Math.round(tree[thisNode.leftChild].left-thisNode.left);
        var w2=Math.round(tree[thisNode.rightChild].left-thisNode.left); 

        ctx.beginPath();
        ctx.strokeStyle="rgba(0,0,0,0.8)";
        ctx.lineWidth=1.5;
        
        if(useBeziers){
            ctx.moveTo(thisNode.left+w1,y1);
            ctx.bezierCurveTo(thisNode.left+w1/2,y1,thisNode.left+w2/2,(y1+y2)/2,thisNode.left,(y1+y2)/2);
            ctx.moveTo(thisNode.left+w2,y2);
            ctx.bezierCurveTo(thisNode.left+w2/2,y2,thisNode.left+w2/2,(y1+y2)/2,thisNode.left,(y1+y2)/2);  
        }else{
            ctx.moveTo(thisNode.left+w1,y1);
            ctx.lineTo(thisNode.left,y1);
            ctx.lineTo(thisNode.left,y2);
            ctx.lineTo(thisNode.left+w2,y2);
        }
        ctx.stroke();        
    });
    ctx.restore();
}
