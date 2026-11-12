((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var B,C,A={vj:function vj(d,e){this.a=d
this.b=e},
avS(d,e,f,g,h,i,j,k){var x,w,v=null
if(g==null)x=v
else x=g
if(k!=null||j!=null){w=e==null?v:e.D0(j,k)
if(w==null)w=B.hB(j,k)}else w=e
return new A.Lh(d,x,i,w,f,h,v,v)},
z3:function z3(d,e){this.a=d
this.b=e},
AG:function AG(d,e){this.a=d
this.b=e},
Lh:function Lh(d,e,f,g,h,i,j,k){var _=this
_.r=d
_.y=e
_.z=f
_.Q=g
_.c=h
_.d=i
_.e=j
_.a=k},
aij:function aij(d,e){var _=this
_.fx=_.fr=_.dy=_.dx=_.db=_.cy=_.cx=_.CW=null
_.e=_.d=$
_.fX$=d
_.d6$=e
_.c=_.a=null},
bcU:function bcU(){},
bcV:function bcV(){},
bcW:function bcW(){},
bcX:function bcX(){},
bcY:function bcY(){},
bcZ:function bcZ(){},
bd_:function bd_(){},
bd0:function bd0(){},
bLN(){var x=new Float64Array(4)
x[3]=1
return new A.u5(x)},
u5:function u5(d){this.a=d}}
B=c[0]
C=c[2]
A=a.updateHolder(c[24],A)
A.vj.prototype={
iP(d){return B.Ld(this.a,this.b,d)}}
A.z3.prototype={
iP(d){var x=B.lV(this.a,this.b,d)
x.toString
return x}}
A.AG.prototype={
iP(a8){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2=new B.hR(new Float64Array(3)),a3=new B.hR(new Float64Array(3)),a4=A.bLN(),a5=A.bLN(),a6=new B.hR(new Float64Array(3)),a7=new B.hR(new Float64Array(3))
this.a.al3(a2,a4,a6)
this.b.al3(a3,a5,a7)
x=1-a8
w=a2.rM(x).a4(0,a3.rM(a8))
v=a4.rM(x).a4(0,a5.rM(a8))
u=new Float64Array(4)
t=new A.u5(u)
t.eR(v)
t.I9()
s=a6.rM(x).a4(0,a7.rM(a8))
x=new Float64Array(16)
v=new B.cy(x)
r=u[0]
q=u[1]
p=u[2]
o=u[3]
n=r+r
m=q+q
l=p+p
k=r*n
j=r*m
i=r*l
h=q*m
g=q*l
f=p*l
e=o*n
d=o*m
a0=o*l
a1=w.a
x[0]=1-(h+f)
x[1]=j+a0
x[2]=i-d
x[3]=0
x[4]=j-a0
x[5]=1-(k+f)
x[6]=g+e
x[7]=0
x[8]=i+d
x[9]=g-e
x[10]=1-(k+h)
x[11]=0
x[12]=a1[0]
x[13]=a1[1]
x[14]=a1[2]
x[15]=1
x=s.a
v.uu(x[0],x[1],x[2],1)
return v}}
A.Lh.prototype={
a6(){return new A.aij(null,null)}}
A.aij.prototype={
r5(d){var x,w,v=this,u=null,t=v.CW
v.a.toString
x=y.b
v.CW=x.a(d.$3(t,u,new A.bcU()))
t=v.cx
v.a.toString
w=y.f
v.cx=w.a(d.$3(t,u,new A.bcV()))
t=y.d
v.cy=t.a(d.$3(v.cy,v.a.y,new A.bcW()))
v.db=t.a(d.$3(v.db,v.a.z,new A.bcX()))
v.dx=y.e.a(d.$3(v.dx,v.a.Q,new A.bcY()))
t=v.dy
v.a.toString
v.dy=w.a(d.$3(t,u,new A.bcZ()))
t=v.fr
v.a.toString
v.fr=y.w.a(d.$3(t,u,new A.bd_()))
t=v.fx
v.a.toString
v.fx=x.a(d.$3(t,u,new A.bd0()))},
I(d){var x,w,v,u,t,s,r,q=this,p=null,o=q.giW(),n=q.CW
n=n==null?p:n.aw(o.gp())
x=q.cx
x=x==null?p:x.aw(o.gp())
w=q.cy
w=w==null?p:w.aw(o.gp())
v=q.db
v=v==null?p:v.aw(o.gp())
u=q.dx
u=u==null?p:u.aw(o.gp())
t=q.dy
t=t==null?p:t.aw(o.gp())
s=q.fr
s=s==null?p:s.aw(o.gp())
r=q.fx
r=r==null?p:r.aw(o.gp())
return B.jb(n,q.a.r,C.af,u,w,v,p,t,x,s,r,p)}}
A.u5.prototype={
eR(d){var x=d.a,w=this.a,v=x[0]
w.$flags&2&&B.f(w)
w[0]=v
w[1]=x[1]
w[2]=x[2]
w[3]=x[3]},
aDo(d){var x,w,v,u,t,s=d.a,r=s[0],q=s[4],p=s[8],o=0+r+q+p
if(o>0){x=Math.sqrt(o+1)
r=this.a
r.$flags&2&&B.f(r)
r[3]=x*0.5
x=0.5/x
r[0]=(s[5]-s[7])*x
r[1]=(s[6]-s[2])*x
r[2]=(s[1]-s[3])*x}else{if(r<q)w=q<p?2:1
else w=r<p?2:0
v=(w+1)%3
u=(w+2)%3
r=w*3
q=v*3
p=u*3
x=Math.sqrt(s[r+w]-s[q+v]-s[p+u]+1)
t=this.a
t.$flags&2&&B.f(t)
t[w]=x*0.5
x=0.5/x
t[3]=(s[q+u]-s[p+v])*x
t[v]=(s[r+v]+s[q+w])*x
t[u]=(s[r+u]+s[p+w])*x}},
I9(){var x,w,v,u=Math.sqrt(this.gHT())
if(u===0)return 0
x=1/u
w=this.a
v=w[0]
w.$flags&2&&B.f(w)
w[0]=v*x
w[1]=w[1]*x
w[2]=w[2]*x
w[3]=w[3]*x
return u},
gHT(){var x=this.a,w=x[0],v=x[1],u=x[2],t=x[3]
return w*w+v*v+u*u+t*t},
gq(d){var x=this.a,w=x[0],v=x[1],u=x[2],t=x[3]
return Math.sqrt(w*w+v*v+u*u+t*t)},
rM(d){var x=new Float64Array(4),w=new A.u5(x)
w.eR(this)
x[3]=x[3]*d
x[2]=x[2]*d
x[1]=x[1]*d
x[0]=x[0]*d
return w},
aA(a5,a6){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h=this.a,g=h[3],f=h[2],e=h[1],d=h[0],a0=a6.gbpA(),a1=a0[3],a2=a0[2],a3=a0[1],a4=a0[0]
h=C.n.aA(g,a4)
x=C.n.aA(d,a1)
w=C.n.aA(e,a2)
v=C.n.aA(f,a3)
u=C.n.aA(g,a3)
t=C.n.aA(e,a1)
s=C.n.aA(f,a4)
r=C.n.aA(d,a2)
q=C.n.aA(g,a2)
p=C.n.aA(f,a1)
o=C.n.aA(d,a3)
n=C.n.aA(e,a4)
m=C.n.aA(g,a1)
l=C.n.aA(d,a4)
k=C.n.aA(e,a3)
j=C.n.aA(f,a2)
i=new Float64Array(4)
i[0]=h+x+w-v
i[1]=u+t+s-r
i[2]=q+p+o-n
i[3]=m-l-k-j
return new A.u5(i)},
l(d,e){var x,w,v
if(e==null)return!1
if(e instanceof A.u5){x=this.a
w=x[3]
v=e.a
x=w===v[3]&&x[2]===v[2]&&x[1]===v[1]&&x[0]===v[0]}else x=!1
return x},
gA(d){return B.ao(this.a)},
a4(d,e){var x,w=new Float64Array(4),v=new A.u5(w)
v.eR(this)
x=e.a
w[0]=w[0]+x[0]
w[1]=w[1]+x[1]
w[2]=w[2]+x[2]
w[3]=w[3]+x[3]
return v},
an(d,e){var x,w=new Float64Array(4),v=new A.u5(w)
v.eR(this)
x=e.a
w[0]=w[0]-x[0]
w[1]=w[1]-x[1]
w[2]=w[2]-x[2]
w[3]=w[3]-x[3]
return v},
h(d,e){return this.a[e]},
k(d,e,f){var x=this.a
x.$flags&2&&B.f(x)
x[e]=f},
j(d){var x=this.a
return B.m(x[0])+", "+B.m(x[1])+", "+B.m(x[2])+" @ "+B.m(x[3])}}
var z=a.updateTypes(["vj(@)","z3(@)","AG(@)"])
A.bcU.prototype={
$1(d){return new A.vj(y.k.a(d),null)},
$S:z+0}
A.bcV.prototype={
$1(d){return new B.q9(y.m.a(d),null)},
$S:170}
A.bcW.prototype={
$1(d){return new B.t0(y.r.a(d),null)},
$S:318}
A.bcX.prototype={
$1(d){return new B.t0(y.r.a(d),null)},
$S:318}
A.bcY.prototype={
$1(d){return new A.z3(y.a.a(d),null)},
$S:z+1}
A.bcZ.prototype={
$1(d){return new B.q9(y.m.a(d),null)},
$S:170}
A.bd_.prototype={
$1(d){return new A.AG(y.E.a(d),null)},
$S:z+2}
A.bd0.prototype={
$1(d){return new A.vj(y.k.a(d),null)},
$S:z+0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(B.aZ,[A.vj,A.z3,A.AG])
w(A.Lh,B.Or)
w(A.aij,B.vk)
x(B.fL,[A.bcU,A.bcV,A.bcW,A.bcX,A.bcY,A.bcZ,A.bd_,A.bd0])
w(A.u5,B.B)})()
B.ig(b.typeUniverse,JSON.parse('{"vj":{"aZ":["km?"],"aO":["km?"],"aO.T":"km?","aZ.T":"km?"},"z3":{"aZ":["ah"],"aO":["ah"],"aO.T":"ah","aZ.T":"ah"},"AG":{"aZ":["cy"],"aO":["cy"],"aO.T":"cy","aZ.T":"cy"},"Lh":{"V":[],"h":[]},"aij":{"W":["Lh"]}}'))
var y=(function rtii(){var x=B.T
return{k:x("km"),a:x("ah"),r:x("l9"),m:x("eC"),E:x("cy"),b:x("vj?"),e:x("z3?"),d:x("t0?"),f:x("q9?"),w:x("AG?")}})()};
(a=>{a["mxrPKcPMEE4Xc9UDIXonA+MLWHg="]=a.current})($__dart_deferred_initializers__);