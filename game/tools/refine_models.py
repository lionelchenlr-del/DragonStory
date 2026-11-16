"""Deterministic v9 native-geometry authoring. Re-running starts from the v8 baseline."""
from pathlib import Path
import copy, json, math

P=Path(__file__).resolve().parents[1]
records=json.loads((P/'art/base-v8-recipes.json').read_text())
C=json.loads((P/'art/content-data.json').read_text())['Catalog']
def add(a,b):return [a[i]+b[i] for i in range(3)]
def sub(a,b):return [a[i]-b[i] for i in range(3)]
def mul(a,s):return [v*s for v in a]
def unit(a):return mul(a,1/max(1e-9,math.sqrt(sum(v*v for v in a))))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def tone(c,t):return ''.join(f'{min(255,max(0,round(int(c[i:i+2],16)*t))):02X}' for i in (0,2,4))
def lua(v):
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,(float,int)):return str(round(v,6))
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'

class Sculpt:
    def __init__(self,parts):self.parts=copy.deepcopy(parts);self.features=set()
    def part(self,name,pos,size,col,shape='Bevel',group=None,material=None,alpha=0,glow=False,rot=None):
        p={'Name':name,'Position':pos,'Size':size,'Color':col,'Shape':shape,'Rotation':rot or [0,0,0]}
        if group:p['Group']=group
        if material:p['Material']=material
        if alpha:p['Transparency']=alpha
        if glow:p['Neon']=True
        if material=='Metal':p['Reflectance']=.055
        self.parts.append(p);self.features.add(name);return p
    def rod(self,name,a,b,r,col,group=None,material=None):
        along=unit(sub(b,a));second=unit(cross(along,[0,0,1] if abs(along[2])<.9 else [0,1,0]));third=cross(along,second)
        p=self.part(name,mul(add(a,b),.5),[math.dist(a,b),2*r,2*r],col,'Cylinder',group,material)
        p['Basis']=[along,second,third];return p
    def path(self,name,points,r,col,group=None,material=None,taper=False):
        for i,(a,b) in enumerate(zip(points,points[1:])):
            self.rod(name,a,b,max(.008,r*(1-.88*i/max(1,len(points)-2))) if taper else r,col,group,material)
    def curve(self,name,a,b,c,r,col,group=None,material=None,n=10,taper=False):
        self.path(name,[add(add(mul(a,(1-t)**2),mul(b,2*t*(1-t))),mul(c,t*t)) for t in [i/n for i in range(n+1)]],r,col,group,material,taper)
    def blade(self,name,a,b,width,col,group=None,normal=None,material=None):
        up=unit(sub(b,a));right=unit(cross(up,normal or [0,0,1]));back=unit(cross(right,up))
        p=self.part(name,mul(add(a,b),.5),[width,math.dist(a,b),max(.018,width*.11)],col,'Crystal',group,material)
        p['Basis']=[right,up,back];return p
    def ring(self,name,center,rx,ry,r,col,group=None,material=None,n=20):
        self.path(name,[[center[0]+rx*math.cos(i*math.tau/n),center[1]+ry*math.sin(i*math.tau/n),center[2]] for i in range(n+1)],r,col,group,material)
    def jewel(self,name,pos,size,col,trim,group=None):
        self.part(name+'Bezel',pos,[size[0]*1.2,size[1]*1.12,size[2]],trim,'Crystal',group,'Metal')
        self.part(name,add(pos,[0,0,-size[2]*.32]),size,col,'Crystal',group,'Glass')
        self.part(name+'Glint',add(pos,[-size[0]*.15,size[1]*.12,-size[2]*.92]),mul(size,.18),'E8F4EC','Crystal',group)
    def feather(self,name,a,b,width,col,vein,group=None,normal=None):
        normal=normal or [0,0,1];delta=sub(b,a);tangent=unit(delta);side=unit(cross(tangent,normal))
        self.blade(name,a,b,width,col,group,normal)
        self.rod(name+'Quill',a,b,.014,vein,group)
        for i in range(1,5):
            t=i/6;mid=add(a,mul(delta,t));w=width*.44*math.sin(math.pi*t)
            for sign in [-1,1]:
                self.rod(name+'Barb',mid,add(add(mid,mul(side,sign*w)),mul(tangent,-math.dist(a,b)*.12)),.009,vein,group)
    def motif(self,theme,pos,s,trim,col,group=None):
        def p(x,y,z=0):return add(pos,[x*s,y*s,z*s])
        if theme in ['sky_guard','divine']:
            for sign in [-1,1]:
                self.curve('WingSigilScroll',p(0,-.3),p(sign*.7,0),p(sign*.58,.55),.018*s,trim,group,'Metal',7)
                for n in range(3):self.blade('WingSigilFeather',p(sign*.14,-.13+n*.12),p(sign*(.4+n*.1),.08+n*.2),.14*s,trim,group,material='Metal')
            if theme=='divine':self.ring('DivineHaloInlay',p(0,.16),.47*s,.47*s,.016*s,trim,group,'Metal',24)
        elif theme=='forest_oath':
            self.curve('VineSigil',p(0,-.45),p(-.17,0),p(.08,.5),.023*s,trim,group,'Metal',10)
            for sign in [-1,1]:
                for n in range(3):self.blade('VineSigilLeaf',p(0,-.22+n*.17),p(sign*.3,.02+n*.17),.2*s,col,group,material='Metal')
        elif theme=='flame':
            for sign in [-1,1]:self.curve('FlameSigil',p(0,-.35),p(sign*.65,-.1),p(sign*.06,.6),.025*s,trim,group,'Metal',10)
            self.blade('FlameSigilCore',p(0,-.3),p(0,.38),.25*s,col,group,material='Metal')
        elif theme=='frost':
            for n in range(6):
                a=n*math.tau/6;end=p(math.sin(a)*.48,math.cos(a)*.48)
                self.rod('SnowflakeSigil',pos,end,.018*s,trim,group,'Metal')
                for sign in [-1,1]:self.rod('SnowflakeBranch',p(math.sin(a)*.29,math.cos(a)*.29),p(math.sin(a+sign*.3)*.43,math.cos(a+sign*.3)*.43),.014*s,trim,group,'Metal')
        elif theme=='thunder':
            self.path('LightningSigil',[p(.16,.53),p(-.23,.02),p(.16,.09),p(-.18,-.5)],.03*s,trim,group,'Metal')
            for sign in [-1,1]:self.path('LightningCircuit',[p(sign*.3,.3),p(sign*.48,.15),p(sign*.3,-.17)],.013*s,col,group,'Metal')
        elif theme=='void':
            for sign in [-1,1]:self.curve('EclipseSigil',p(sign*.08,.5),p(sign*.65,0),p(sign*.08,-.5),.024*s,trim,group,'Metal',12)
            self.part('EclipseCore',pos,[.13*s,.4*s,.025*s],col,'Crystal',group,'Glass')
        else:self.path('GuildChevron',[p(-.32,.2),p(0,-.2),p(.32,.2)],.022*s,trim,group,'Metal')

themes={
 'sky_guard':('E0EAE8','C4AE76','73CFC8','406D7B'),
 'forest_oath':('537565','C7AF78','94DBA9','2F4A3C'),
 'flame':('51434B','BF8E58','F3A15C','282934'),
 'frost':('D2E4EC','B4B9A4','83D6E7','587A91'),
 'thunder':('596C85','CFB56C','91CDE8','303D57'),
 'void':('494054','BAA178','B798E5','252333'),
 'divine':('E4DFCE','D2B879','B9D7D3','6B7291'),
 'training':('9EAEB7','B99D6E','9BBCC4','3B4557'),
 'traveler':('668596','B5A16C','88BECE','354956')}
coverage=[]
for id,item in C['Items'].items():
    record=records[id];theme=record['Theme'];base,trim,gem,dark=themes[theme];slot=item['Slot'];b=Sculpt(record['Parts'])
    # Replace the large diamond-shaped armour slabs with fitted, low-profile panels.
    discard={'OverlappingCuirassPlate','OverlappingCuirassPlateRim','SegmentedPauldron','SegmentedPauldronRim','CuirassMotif','ArticulatedShinPlate','ArticulatedShinPlateRim','SweptGreaveWing','SweptBrowRim','LayeredWingCrest','EtchedCrownFin','ForeheadPlate','CrownCutGem','BreastplateInlay','ShinInset'}
    b.parts=[p for p in b.parts if p['Name'] not in discard]
    for p in b.parts:
        if p.get('Neon'):
            p.pop('Neon',None);p['Material']='Glass'
        if p['Name']=='TailoredCuirass':p['Size']=[2.45,2.55,1.45]
    if slot=='Weapon':
        # Tiny cylinder-based wire work, polished facets, and a genuinely curved guard.
        for sign in [-1,1]:
            b.curve('SculptedQuillon',[sign*.26,-.6,-.08],[sign*1.25,-.48,-.08],[sign*1.25,.2,-.08],.048,trim,material='Metal',n=12,taper=True)
            b.curve('QuillonInlay',[sign*.35,-.5,-.23],[sign*.95,-.42,-.23],[sign*1.1,-.03,-.23],.018,gem,material='Metal',n=10)
        for y in [-2.05,-1.83,-.78]:
            # Hilt collars encircle the Y-axis, using short smooth cylinders.
            b.path('EngravedHiltCollar',[[math.cos(n*math.tau/16)*.17,y,math.sin(n*math.tau/16)*.17]for n in range(17)],.024,trim,material='Metal')
        for y in [.25,.95,1.65,2.35]:
            b.path('BladeEtchedKnot',[[-.12,y+.11,-.155],[0,y-.04,-.155],[.12,y+.11,-.155]],.013,trim,material='Metal')
        b.jewel('SetGuardGem',[0,-.5,-.3],[.28,.38,.12],gem,trim)
        for sign in [-1,1]:b.curve('GuardFiligree',[sign*.08,-.67,-.26],[sign*.45,-.86,-.26],[sign*.59,-.57,-.26],.014,trim,material='Metal',n=8)
        b.motif(theme,[0,-1.5,-.18],.23,trim,gem)
    elif slot=='Helmet':
        for sign in [-1,1]:
            b.curve('FittedBrowDiadem',[0,.63,-.91],[sign*.72,.63,-.9],[sign*.99,.1,-.7],.045,trim,material='Metal',n=14)
            b.curve('CheekEngraving',[sign*.88,.14,-.86],[sign*.83,-.22,-.9],[sign*.67,-.52,-.81],.018,trim,material='Metal',n=10)
            if theme in ['sky_guard','divine']:
                for n in range(5):
                    b.feather('DiademFeather',[sign*(.68+n*.08),.38+n*.09,.2+n*.09],[sign*(1.0+n*.11),1.05+n*.13,.7+n*.08],.22,base,trim)
            elif theme=='forest_oath':
                b.curve('AntlerCrown',[sign*.7,.5,.05],[sign*1.35,1.3,.35],[sign*.91,1.66,.4],.075,trim,material='Metal',n=10,taper=True)
                for n in range(3):b.feather('CrownLeaf',[sign*.8,.65+n*.18,.05],[sign*1.38,.92+n*.22,.05],.26,base,trim)
            elif theme in ['flame','void']:
                b.curve('RecurvedCrownHorn',[sign*.71,.5,.1],[sign*1.65,.9,.6],[sign*1.1,1.77,.5],.11,base,material='Metal',n=12,taper=True)
            elif theme=='frost':
                for n in range(4):b.blade('IceCrownShard',[sign*(.62+n*.1),.5,.1+n*.12],[sign*(.88+n*.13),1.34+n*.12,.27+n*.13],.23,base,material='Glass')
            elif theme=='thunder':
                b.path('BoltCrownProng',[[sign*.67,.5,.1],[sign*1.05,.95,.1],[sign*.84,1.05,.1],[sign*1.23,1.59,.1]],.065,trim,material='Metal')
        b.part('FittedForeheadPlate',[0,.62,-.73],[.68,.61,.18],base,material='Metal')
        b.jewel('DiademGem',[0,.64,-.91],[.28,.44,.12],gem,trim)
        b.motif(theme,[0,.3,-.92],.4,trim,gem)
    elif slot=='Armor':
        for sign in [-1,1]:
            b.part('SculptedBreastplate',[sign*.58,.57,-.89],[1.28,1.24,.32],base,material='Metal',rot=[0,-sign*8,-sign*5])
            b.curve('BreastplateInlay',[sign*.08,1.05,-1.08],[sign*.75,.94,-1.13],[sign*1.12,.3,-.98],.022,trim,material='Metal',n=14)
        for row in range(3):
            y=-.22-row*.36
            for col in range(3):
                x=(col-1)*.74;z=-.84-.1*(1-abs(x))-.025*row
                b.part('FittedAbdominalLamella',[x,y,z],[.82,.46,.2],base,material='Metal',rot=[0,-x*12,0])
            b.curve('CuirassRolledSeam',[-1.12,y-.13,-.87-.025*row],[0,y-.24,-1.09-.025*row],[1.12,y-.13,-.87-.025*row],.019,trim,material='Metal',n=12)
        for sign in [-1,1]:
            b.curve('SculptedCollar',[sign*.12,1.25,-.55],[sign*.98,1.65,-.52],[sign*1.2,.72,-.69],.038,trim,material='Metal',n=14)
            for n in range(4):
                x=sign*(1.25+n*.18);y=1.12-n*.11
                b.part('FittedShoulderLamella',[x,y,-.04],[.55,.39,1.56],base,material='Metal',rot=[0,0,sign*(13+n*8)])
                b.curve('PauldronRolledEdge',[x-sign*.22,y+.1,-.83],[x,y-.14,-.91],[x+sign*.23,y-.2,-.78],.024,trim,material='Metal',n=7)
                if theme in ['sky_guard','divine','forest_oath']:
                    b.feather('PauldronFeather' if theme!='forest_oath' else 'PauldronLeaf',[x,y,-.86],[x+sign*.22,y-.42,-.87],.21,base,trim)
            b.curve('RaisedWaistFiligree',[sign*.06,-.91,-.98],[sign*.7,-.71,-1.07],[sign*1.05,-1.06,-.85],.021,trim,material='Metal',n=10)
            for n in range(4):b.part('TailoredTassetSeam',[sign*.68,-1.15-n*.12,-.52],[.65,.025,.06],trim,material='Metal')
        b.motif(theme,[0,.1,-1.1],1.18,trim,gem)
        b.jewel('HeartGem',[0,.73,-1.11],[.3,.44,.13],gem,trim)
        # Back detail is visible during ordinary third-person play.
        b.curve('BackCollarEngraving',[-.9,.9,.97],[0,1.32,1.01],[.9,.9,.97],.026,trim,material='Metal',n=16)
        for sign in [-1,1]:
            b.curve('BackSpineFiligree',[sign*.12,.8,1.0],[sign*.67,.05,1.0],[sign*.19,-.75,1.0],.024,trim,material='Metal',n=14)
        b.part('BackSetGem',[0,.35,1.01],[.29,.53,.09],gem,'Crystal',material='Glass')
    elif slot=='Boots':
        for sign in [-1,1]:
            x=sign*.85;group='BootLeft' if sign<0 else 'BootRight'
            for n in range(5):
                y=1.13-n*.4
                b.part('FittedGreaveLamella',[x,y,-.69],[1.02,.47,.18],base,group=group,material='Metal')
                b.curve('GreaveRolledSeam',[x-.48,y-.16,-.72],[x,y-.26,-.87],[x+.48,y-.16,-.72],.022,trim,group,'Metal',n=10)
            b.curve('PolishedToeRim',[x-.52,-.98,-1.23],[x,-1.19,-1.52],[x+.52,-.98,-1.23],.034,trim,group,'Metal',n=14)
            for n in range(4):b.part('ArticulatedToeSeam',[x,-.69+n*.025,-1.18+n*.19],[1.02,.024,.03],dark,group=group)
            b.motif(theme,[x,.39,-.83],.55,trim,gem,group)
            b.jewel('GreaveGem',[x,1.05,-.84],[.22,.35,.11],gem,trim,group)
            for n in range(3):
                if theme in ['sky_guard','divine','forest_oath']:
                    b.feather('GreaveFeather',[x+sign*.46,.2+n*.15,.12],[x+sign*(.79+n*.1),.65+n*.25,.28],.2,base,trim,group)
                else:b.blade('GreaveElementFin',[x+sign*.48,.13+n*.16,.17],[x+sign*.82,.55+n*.24,.25],.22,base,group,material='Metal')
    before=len(record['Parts']);record['Parts']=b.parts;record['DesignRevision']=9;record['AuthoredRevision']=9
    coverage.append({'Id':id,'Type':'Equipment','Slot':slot,'Theme':theme,'Before':before,'After':len(b.parts),'Features':sorted(b.features)})

for id,monster in C['Monsters'].items():
    record=records[id];b=Sculpt(record['Parts']);names={p['Name'] for p in b.parts}
    def first(name):return next((p for p in b.parts if p['Name']==name),None)
    def palette():
        main=first('Ribcage') or first('Torso') or first('Head') or b.parts[0]
        return main['Color'],monster['Color'],tone(main['Color'],.67)
    base,accent,dark=palette()
    # Recessed eyes in the old quadruped face were obscured by its skull bevel.
    if 'Ribcage' in names:
        for p in b.parts:
            if p['Name'] in ['EyeSocket','Iris','Pupil','SculptedUpperEyelid']:
                p['Position'][2]-=.22
    # Every visible eye gains a separate rim, iris plane and restrained catchlight.
    for eye in list(b.parts):
        if eye['Name'] not in ['Iris','NarrowEye']:continue
        p=eye['Position'];sz=eye['Size']
        if eye['Name']=='NarrowEye':
            sign=-1 if p[0]<0 else 1
            b.part('CornealCatchlight',add(p,[sign*sz[0]*.6,sz[1]*.16,-sz[2]*.13]),[sz[0]*.2,sz[1]*.18,sz[2]*.13],'E5F1DF','Ball')
        else:
            b.part('CornealCatchlight',add(p,[-sz[0]*.14,sz[1]*.17,-sz[2]*.57]),[sz[0]*.17,sz[1]*.2,sz[2]*.13],'E5F1DF','Ball')
            b.curve('LowerOrbitalRim',add(p,[-sz[0]*.65,-sz[1]*.18,-sz[2]*.6]),add(p,[0,-sz[1]*.8,-sz[2]*.62]),add(p,[sz[0]*.65,-sz[1]*.18,-sz[2]*.6]),max(.016,sz[1]*.06),dark,n=8)
    if record['Kind']=='Dragon':
        s=record['Stage']['Scale'];base=record['Stage']['Color'];trim=record['Stage'].get('Gold','C8AE7B');accent=record['Stage']['Glow']
        def q(v):return mul(v,s)
        for sign in [-1,1]:
            for row in range(5):
                for n in range(4):
                    # Facial scales follow the cheek instead of floating around the torso.
                    p=q([sign*(.76+.03*row),6.1+row*.17,-4.08+n*.25])
                    b.blade('SculptedFacialScale',p,add(p,q([sign*.03,.05,.25])),.17*s,base)
            b.part('SculptedNostril',q([sign*.34,6.24,-5.48]),q([.17,.1,.06]),dark,'Ball')
            b.curve('NostrilRidge',q([sign*.18,6.29,-5.44]),q([sign*.38,6.42,-5.45]),q([sign*.49,6.27,-5.38]),.025*s,trim,n=7)
            b.curve('GumLine',q([sign*.5,5.83,-5.25]),q([sign*.64,5.89,-4.8]),q([sign*.56,5.9,-4.1]),.026*s,dark,n=10)
            for n in range(8):
                y=3.7+n*.38;z=-1.9-n*.2
                b.blade('NeckScaleChevron',q([sign*.22,y,z-.51]),q([sign*.61,y-.16,z-.39]),.2*s,trim)
            for row in range(4):
                for n in range(5):
                    p=q([sign*(1.37-row*.07),1.1+n*.38,-1.6+row*.2])
                    b.blade('ForelegScute',p,add(p,q([0,-.22,.1])),.2*s,base)
            # The large wings read as membranes with branching veins at close range.
            group='WingLeft' if sign<0 else 'WingRight'
            for n in range(4):
                b.curve('WingMembraneVein',q([sign*1.2,3.8,.35]),q([sign*(2.3+n*.35),3.85,.8+n*.6]),q([sign*(3.6+n*.45),3.3,1.5+n*.65]),.013*s,trim,group,n=8)
        for n in range(10):
            z=-.6+n*.4;b.part('DorsalInsetScale',q([0,4.54-.04*n,z]),q([.35,.1,.37]),trim,'Bevel')
    elif 'Ribcage' in names:
        # Less bulky silhouette; preserve feet and sockets while refining fur direction.
        for p in b.parts:
            if p['Name'] in ['PowerChest','Ribcage']:p['Size'][0]*=.92
            if p['Name'] in ['LayeredManeTuft','ShoulderMane']:p['Size'][0]*=.75;p['Size'][2]*=.88
        b.parts=[p for p in b.parts if p['Name'] not in ['CheekPlate','LayeredManeTuft','LayeredContourFur','ShoulderMane','PointedEar']]
        for sign in [-1,1]:
            b.blade('SculptedPointedEar',[sign*.58,4.04,-2.1],[sign*.79,5.02,-1.88],.5,base)
            b.blade('RecessedEarPlane',[sign*.6,4.2,-2.16],[sign*.76,4.84,-1.96],.27,dark)
            for row in range(5):
                for n in range(7):
                    p=[sign*(.94+.12*math.sin(row*.6)),3.63-row*.23,-1.63+n*.43]
                    b.blade('DirectionalManeFur',p,add(p,[sign*.18,-.14,.55]),.19,base if row%2 else tone(base,.93))
            b.curve('ExpressivePredatorBrow',[sign*.28,4.0,-3.39],[sign*.57,4.15,-3.42],[sign*.84,3.95,-3.18],.053,base,n=10)
            b.part('NostrilInset',[sign*.21,3.42,-4.115],[.14,.09,.035],dark,'Ball')
            b.curve('MuzzleLip',[sign*.19,3.16,-3.99],[sign*.62,3.12,-3.83],[sign*.65,3.1,-3.3],.023,dark,n=10)
            b.blade('InnerEar', [sign*.62,4.15,-2.18],[sign*.64,4.91,-1.96],.25,dark)
            # Finer cheek strands and tapering, gently curved horns.
            for n in range(7):
                a=[sign*(.67+n*.035),3.77-n*.085,-2.85+n*.1]
                b.feather('SculptedCheekFur',a,add(a,[sign*.24,-.2,.58]),.14,base,tone(base,.83))
            for z in [-1.35,1.5]:
                for n in range(3):b.curve('PawToeSeam',[sign*.9+(n-1)*.19,.51,z-.42],[sign*.9+(n-1)*.19,.54,z-.75],[sign*.9+(n-1)*.19,.36,z-.99],.015,dark,n=5)
            if id not in ['wind_griffin','star_wing_lion']:
                b.parts=[p for p in b.parts if p['Name']!='SweptHorn']
                b.curve('SweptOrganicHorn',[sign*.52,4.1,-2.06],[sign*1.13,5.4,-1.05],[sign*.76,5.45,.15],.12,accent,n=16,taper=True)
            else:
                for n in range(12):
                    a=n*math.tau/12
                    b.feather('RadialFaceMane',[sign*.68,3.7,-2.55],[sign*(.9+abs(math.cos(a))*.6),3.65+math.sin(a)*1.0,-1.65],.17,base,tone(base,.83))
        if id=='wind_griffin':
            # Eagle-shaped profile, remove the canine muzzle and oversized fangs.
            b.parts=[p for p in b.parts if p['Name'] not in ['LongMuzzle','Nose','SaberFang','JawCanine','NostrilInset']]
            b.part('HookedBeakBase',[0,3.36,-3.17],[.83,.75,1.04],'C7AC6C',shape='Bevel')
            b.blade('HookedBeakTip',[0,3.43,-3.55],[0,2.93,-3.92],.55,'C7AC6C',normal=[1,0,0])
        if 'FlightFeather' in names:
            for sign in [-1,1]:
                group='WingLeft' if sign<0 else 'WingRight'
                for n in range(7):
                    a=[sign*(1.55+n*.39),3.65-n*.09,.5+n*.16]
                    b.feather('EngravedFlightPlume',a,add(a,[sign*.6,-.1,1.45]),.27,base,tone(base,.83),group,[0,1,0])
    elif 'Torso' in names:
        trim=next((p['Color'] for p in b.parts if p['Name']=='Shoulder'),'AAA28A')
        b.motif('forest_oath' if id=='root_guardian' else 'thunder' if id=='lightning_sentinel' else 'void' if id=='obsidian_knight' else 'frost' if id=='frost_colossus' else 'divine' if 'star_' in id or 'sanctuary_' in id else 'flame',[0,3.55,-1.3],1.05,trim,accent)
        for sign in [-1,1]:
            for n in range(4):
                b.part('SculptedFingerPlate',[sign*2.35+(n-1.5)*.28,1.82,-1.2],[.23,.63,.18],base)
                b.part('KnuckleInset',[sign*2.35+(n-1.5)*.28,2.12,-1.25],[.12,.12,.06],trim)
            for n in range(4):
                b.curve('PauldronEngraving',[sign*(1.35+n*.15),4.62,-.98],[sign*(1.6+n*.15),4.27,-1.13],[sign*(1.85+n*.15),4.05,-.98],.02,trim,n=7)
            for n in range(3):b.part('FootArmorSeam',[sign*.9,.6,-.75+n*.3],[1.02,.045,.035],dark)
        if id=='root_guardian':
            for n in range(9):
                x=-1.0+n*.25;b.curve('NaturalBarkRidge',[x,2.25,-.98],[x+.12,3.4,-1.02],[x-.08,4.5,-.98],.026,dark,n=10)
            for sign in [-1,1]:b.curve('BranchingAntler',[sign*.67,6.1,.15],[sign*1.5,7.15,.2],[sign*.94,7.75,.7],.08,base,n=14,taper=True)
        else:
            for sign in [-1,1]:
                b.curve('SculptedVisorBrow',[sign*.12,5.88,-.97],[sign*.55,6.1,-.98],[sign*.87,5.7,-.87],.048,trim,n=12)
                for n in range(3):b.part('InsetVisorVent',[sign*(.2+n*.18),5.3,-.93],[.055,.25,.035],dark)
    elif id=='thunder_hawk':
        for sign in [-1,1]:
            for n in range(9):
                a=[sign*(.8+n*.04),3.9-n*.1,-1.1]
                b.feather('LayeredAvianCheek',a,add(a,[sign*.19,-.36,.5]),.14,base,tone(base,.83))
            for n in range(8):
                a=[sign*(1.4+n*.4),3.7-n*.08,.5+n*.15]
                b.feather('HawkPrimaryPlume',a,add(a,[sign*.65,-.16,1.5]),.27,base,tone(base,.83),'WingLeft' if sign<0 else 'WingRight',[0,1,0])
            b.part('AvianNostril',[sign*.2,3.9,-2.4],[.08,.06,.035],dark,'Ball')
    elif id=='crystal_tortoise':
        for p in list(b.parts):
            if p['Name']=='InterlockingShellScute':
                x,y,z=p['Position'];b.curve('ShellScuteGroove',[x-.29,y+.14,z-.22],[x,y+.19,z-.3],[x+.29,y+.14,z-.22],.024,dark,n=6)
        for sign in [-1,1]:
            for n in range(6):b.part('TortoiseNeckScale',[sign*.57,1.5+(n%2)*.2,-2.5-(n//2)*.28],[.24,.2,.17],base,'Bevel')
            b.curve('TortoiseJawSeam',[sign*.1,1.32,-3.42],[sign*.52,1.25,-3.3],[sign*.72,1.37,-2.9],.025,dark,n=10)
        for p in list(b.parts):
            if p['Name']=='CrystalFace':
                x,y,z=p['Position'];b.blade('CrystalRefractionEdge',[x-.1,y-.3,z-.28],[x+.02,y+.7,z-.2],.04,'C8EBDF')
    elif id=='magma_scorpion':
        for p in list(b.parts):
            if p['Name']=='TailSegment':
                x,y,z=p['Position'];b.part('TailArticulationBand',[x,y+.24,z],[.85,.13,.83],dark)
            if p['Name']=='Pincer':
                x,y,z=p['Position']
                for n in range(3):b.part('PincerChitinRidge',[x,y+.42,z-.5+n*.36],[.53,.06,.055],accent)
        for sign in [-1,1]:
            b.curve('ScorpionMandible',[sign*.4,1.23,-2.64],[sign*.7,1.0,-3.0],[sign*.22,1.06,-3.14],.1,base,n=12,taper=True)
            for n in range(5):b.part('CarapaceRivet',[sign*1.15,2.34,-1.3+n*.65],[.13,.09,.13],accent,'Ball')
    elif id=='glow_sprout':
        for n in range(16):
            a=n*math.tau/16
            b.curve('CapRadialVein',[math.cos(a)*.3,4.31,math.sin(a)*.3],[math.cos(a)*1.14,4.21,math.sin(a)*1.14],[math.cos(a)*1.8,3.83,math.sin(a)*1.67],.018,'B5D4AB',n=7)
        for sign in [-1,1]:
            for n in range(3):b.feather('VeinedSproutLeaf',[sign*.44,1.6+n*.25,-.15],[sign*1.6,2.0+n*.25,-.15],.4,'75AD6B','B5D4AB')
            b.curve('RootToe',[sign*.35,.3,-.3],[sign*.92,.15,-.65],[sign*.8,.14,-1.0],.04,base,n=8,taper=True)
    elif id=='slime':
        # Surface highlights and suspended motes use the gel's existing palette.
        for sign in [-1,1]:b.curve('GelSurfaceHighlight',[sign*1.12,2.7,-1.4],[sign*1.9,2.3,-1.5],[sign*1.85,1.65,-1.45],.035,'DBF5DA',n=14)
        for n in range(12):
            a=n*2.399;rad=.35+(n%3)*.35
            b.part('SuspendedGelMote',[math.cos(a)*rad,.85+(n%4)*.27,math.sin(a)*rad],[.07,.07,.07],'B2E4D5','Ball')
        b.curve('ExpressiveGelMouth',[-.42,.86,-1.87],[0,.66,-1.95],[.42,.86,-1.87],.025,'248C8C',n=12)
    elif id=='abyss_beholder':
        b.ring('IrisInnerLimbus',[0,3.4,-1.48],.87,.87,.025,accent,n=40)
        for n in range(40):
            a=n*math.tau/40
            b.curve('IrisFilament',[math.cos(a)*.43,3.4+math.sin(a)*.43,-1.51],[math.cos(a+.07)*.8,3.4+math.sin(a+.07)*.8,-1.52],[math.cos(a)*1.21,3.4+math.sin(a)*1.21,-1.49],.011,'A184CC',n=5)
        for n in range(12):
            a=n*math.tau/12
            b.blade('OrbitalCarapace',[math.cos(a)*1.57,3.4+math.sin(a)*1.57,-.92],[math.cos(a)*2.05,3.4+math.sin(a)*2.05,-.7],.23,base)
    before=len(record['Parts']);record['Parts']=b.parts;record['AuthoredRevision']=9;record['DesignRevision']=9
    coverage.append({'Id':id,'Type':'Monster','Role':monster['Role'],'Before':before,'After':len(b.parts),'Features':sorted(b.features)})

ids=set(C['Items'])|set(C['Monsters'])
assert {r['Id'] for r in coverage}==ids and len(coverage)==58
for id,record in records.items():(P/'src/ReplicatedStorage/DragonShared/VisualChunks'/f'{id}.luau').write_text('return '+lua(record)+'\n')
(P/'art/visual-recipes.json').write_text(json.dumps(records,ensure_ascii=False))
(P/'art/refinement-coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'models':len(coverage),'monsterCount':len(C['Monsters']),'equipmentCount':len(C['Items']),
                  'maxRecipe':max((len(v['Parts']),k) for k,v in records.items()),'totalPrimitives':sum(len(records[k]['Parts']) for k in ids)},ensure_ascii=False))
