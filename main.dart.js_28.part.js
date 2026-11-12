((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var A,C,F,E,G,B={b6E:function b6E(){},
bX6(d){var x,w,v=A.c6(d,"\u066b",".")
v=A.c6(v,"\u066c","")
v=A.c6(v,"\xd7","*")
x=A.c6(v,"\xf7","/")
for(w=0;w<10;++w){v="\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669"[w]
x=A.c6(x,v,""+w)}return x},
bja:function bja(d){this.a=d
this.b=0},
bX7(){return new B.LX(null)},
LX:function LX(d){this.a=d},
aj9:function aj9(){var _=this
_.d=""
_.f=_.e=null
_.r=!1
_.c=_.a=null},
beV:function beV(d,e){this.a=d
this.b=e},
beY:function beY(d,e){this.a=d
this.b=e},
beX:function beX(d,e){this.a=d
this.b=e},
beW:function beW(d,e){this.a=d
this.b=e}},D
A=c[0]
C=c[2]
F=c[22]
E=c[19]
G=c[20]
B=a.updateHolder(c[10],B)
D=c[36]
B.b6E.prototype={
Dl(d){var x=Math.max(0,d.w-30)/4,w=x/1.4
return new E.Sz(4,w+10,x+10,w,x,A.v9(d.x))},
mz(d){return!1}}
B.bja.prototype={
a9F(){var x=this,w=x.Ya()
for(;;){x.B0()
if(x.uJ("+"))w+=x.Ya()
else if(x.uJ("-"))w-=x.Ya()
else return w}},
Ya(){var x,w=this,v=w.EG()
for(;;){w.B0()
if(w.uJ("*"))v*=w.EG()
else if(w.uJ("/")){x=w.EG()
if(x===0)throw A.c(D.acD)
v/=x}else return v}},
EG(){var x,w=this
w.B0()
if(w.uJ("+"))return w.EG()
if(w.uJ("-"))return-w.EG()
if(w.uJ("(")){x=w.a9F()
w.B0()
if(!w.uJ(")"))w.M1()
return x}return w.b_5()},
b_5(){var x,w,v,u,t,s,r,q,p=this
p.B0()
x=p.b
for(w=p.a,v=w.length,u=x,t=!1,s=!1;u<v;){r=w[u]
if(r.charCodeAt(0)>=48&&r.charCodeAt(0)<=57){++u
p.b=u
t=!0}else{if(r==="."&&!s){++u
p.b=u}else break
s=!0}}if(!t)p.M1()
q=A.Bp(C.o.ar(w,x,u))
if(q==null||!isFinite(q))p.M1()
return q},
uJ(d){var x=this.b,w=this.a
if(x>=w.length||w[x]!==d)return!1
this.b=x+1
return!0},
B0(){var x,w=this.a,v=w.length
for(;;){x=this.b
if(!(x<v&&C.o.aL(w[x]).length===0))break
this.b=x+1}},
M1(){return A.R(D.acA)}}
B.LX.prototype={
a6(){return new B.aj9()}}
B.aj9.prototype={
b23(d){this.M(new B.beV(this,d))},
aRL(d){if(d===C.n.zk(d))return C.f.j(C.n.D(d))
return C.o.fz(C.n.aAy(d,12),A.a6("\\.?0+$",!0,!1,!1,!1),"")},
I(d){return A.nj(new B.beY(this,A.y(d).ax))}}
var z=a.updateTypes([])
B.beV.prototype={
$0(){var x,w,v,u,t,s,r,q,p,o=this.a
o.f=null
v=this.b
if(v==="\u0645\u0633\u062d \u0627\u0644\u0643\u0644"){o.d=""
o.e=null
o.r=!1
return}if(v==="\u232b"){v=o.d
u=v.length
if(u!==0)o.d=C.o.ar(v,0,u-1)
o.e=null
o.r=!1
return}if(v==="="){try{t=B.bX6(C.o.aL(o.d))
v=t.length
if(v===0)A.R(D.acF)
s=new B.bja(t)
r=s.a9F()
s.B0()
if(s.b!==v)s.M1()
if(!isFinite(r))A.R(D.acx)
x=r
o.e=o.aRL(x)
o.r=!0}catch(q){v=A.a5(q)
if(y.b.b(v)){w=v
o.f=w.giQ()
o.e=null}else throw q}return}p=D.bns.n(0,v)
if(o.r){if(p){u=o.e
if(u==null)u=o.d}else u=""
o.d=u}o.r=!1
o.e=null
u=o.d
o.d=u+(v==="\u2212"?"-":v)},
$S:0}
B.beY.prototype={
$2(d,e){var x,w,v,u,t,s=this,r=null,q=e.b
if(q>600)q=520
x=s.a
w=x.d
if(w.length===0)w="0"
v=y.e
w=A.b([A.mw(A.b4(w,r,r,r,r,r,r,r,r,A.y(d).ok.e,r,C.E,r,r,r),r,C.ab,r,r,r,!0,C.bW)],v)
u=x.e
if(u!=null&&u!==x.d){t=A.y(d).ok.r
w.push(A.b4(u,r,r,r,r,r,r,r,r,t==null?r:t.cz(s.b.b),C.kw,C.E,r,r,r))}u=x.f
if(u!=null)w.push(A.a9(u,r,r,r,A.fI(r,r,s.b.fy,r,r,r,r,r,r,r,r,r,r,r,r,r,r,!0,r,r,r,r,r,r,r,r),C.av,r))
return A.cY(A.cK(A.b2(A.b([A.fm(A.jb(r,A.b2(w,C.b6,C.mu,C.P,0,C.Q),C.af,D.a4K,r,r,r,r,C.bj,r,r,1/0),r,r,D.aaK,r),A.bP(E.bJo(r,C.ab,D.a6A,new B.beX(x,s.b),20,D.aaH),1)],v),C.S,C.H,C.P,0,C.Q),r,q),r,r)},
$S:951}
B.beX.prototype={
$2(d,e){var x,w,v,u,t,s,r,q=null,p=D.b_y[e],o=D.bnf.n(0,p),n=p==="="
if(n){x=this.b
w=x.b
v=w
w=x
x=v}else{x=this.b
if(o){w=x.Q
if(w==null)w=x.y}else w=x.k2
v=w
w=x
x=v}n=n?w.c:w.k3
u=p==="\u0645\u0633\u062d \u0627\u0644\u0643\u0644"
t=u?C.dR:q
s=A.h_(16)
r=w.to
if(r==null){r=w.v
w=r==null?w.k3:r}else w=r
w=A.bBC(x,n,q,t,new A.dy(s,new A.bb(w,1,C.a5,-1)),q)
return A.bJ3(G.bJ6(A.a9(p,1,q,!1,A.fI(q,q,q,q,q,q,q,q,q,q,q,u?16:20,q,q,C.bd,q,q,!0,q,q,q,q,q,q,q,q),q,q),C.AY),new B.beW(this.a,p),w)},
$S:952}
B.beW.prototype={
$0(){return this.a.b23(this.b)},
$S:0};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.b6E,F.Sy)
x(B.bja,A.B)
x(B.LX,A.V)
x(B.aj9,A.W)
w(A.im,[B.beV,B.beW])
w(A.io,[B.beY,B.beX])})()
A.ig(b.typeUniverse,JSON.parse('{"LX":{"V":[],"h":[]},"aj9":{"W":["LX"]}}'))
var y={p:A.T("eX<d>"),b:A.T("cW"),e:A.T("w<h>")};(function constants(){var x=a.makeConstList
D.a4K=new A.ah(0,1/0,130,1/0)
D.a6A=new B.b6E()
D.aaH=new A.bk(16,0,16,16)
D.aaK=new A.bk(16,16,16,12)
D.acx=new A.cW("\u0627\u0644\u0646\u062a\u064a\u062c\u0629 \u062e\u0627\u0631\u062c \u0627\u0644\u0646\u0637\u0627\u0642.",null,null)
D.acA=new A.cW("\u0635\u064a\u063a\u0629 \u0627\u0644\u0639\u0645\u0644\u064a\u0629 \u063a\u064a\u0631 \u0635\u062d\u064a\u062d\u0629.",null,null)
D.acD=new A.cW("\u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0644\u0642\u0633\u0645\u0629 \u0639\u0644\u0649 \u0635\u0641\u0631.",null,null)
D.acF=new A.cW("\u0627\u0643\u062a\u0628 \u0639\u0645\u0644\u064a\u0629 \u062d\u0633\u0627\u0628\u064a\u0629.",null,null)
D.b_y=x(["\u0645\u0633\u062d \u0627\u0644\u0643\u0644","\u232b","\xf7","\xd7","7","8","9","\u2212","4","5","6","+","1","2","3","=","0",".","(",")"],A.T("w<d>"))
D.bha={"\u0645\u0633\u062d \u0627\u0644\u0643\u0644":0,"\u232b":1,"\xf7":2,"\xd7":3,"\u2212":4,"+":5,"=":6}
D.bnf=new A.eX(D.bha,7,y.p)
D.bhn={"+":0,"\u2212":1,"\xd7":2,"\xf7":3}
D.bns=new A.eX(D.bhn,4,y.p)})()};
(a=>{a["OYozRJn1P2/lIUJLl5wTYt4lsoE="]=a.current})($__dart_deferred_initializers__);