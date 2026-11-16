-- Executes the actual TravelService with lightweight engine doubles.
-- run_checks.py inserts the unmodified service source at TRAVEL_SOURCE below.
local Data=require("../src/ReplicatedStorage/DragonShared/WorldData")
local Rules=require("../src/ServerScriptService/DragonServer/TravelRules")
local Evolution=require("../src/ReplicatedStorage/DragonShared/DragonEvolution")
local Catalog=require("../src/ReplicatedStorage/DragonShared/Catalog")
local Settings=require("../src/ServerScriptService/DragonServer/Settings")
local Domain=require("../src/ServerScriptService/DragonServer/Domain").new(Catalog,Settings)
local now=10
local Vector3={};local V={}
V.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
 return V[k]
end
function Vector3.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V)end
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__mul=function(a,b)if type(a)=="number" then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
V.__div=function(a,b)return a*(1/b)end
function V:Lerp(b,t)return self+(b-self)*t end
Vector3.zero=Vector3.new()
local CFrame={};local CF={}
CF.__index=function(v,k)if k=="Rotation" then return CFrame.new() end;return CF[k]end
function CFrame.new(x,y,z)
 local pos=type(x)=="table" and x or Vector3.new(x,y,z)
 return setmetatable({Position=pos,LookVector=Vector3.new(0,0,-1)},CF)
end
function CFrame.lookAt(p,q)local c=CFrame.new(p);c.LookVector=(q-p).Unit;return c end
CF.__add=function(a,b)local c=CFrame.new(a.Position+b);c.LookVector=a.LookVector;return c end
CF.__mul=function(a,b)local c=CFrame.new(a.Position+b.Position);c.LookVector=a.LookVector;return c end
local root=setmetatable({_cf=CFrame.new(),Anchored=false},{
 __index=function(t,k)if k=="CFrame" then return t._cf elseif k=="Position" then return t._cf.Position end end,
 __newindex=function(t,k,v)if k=="CFrame" then rawset(t,"_cf",v) else rawset(t,k,v) end end,
})
local humanoid={Health=120,WalkSpeed=16}
local ch={FindFirstChildOfClass=function(_,k)return k=="Humanoid" and humanoid end,FindFirstChild=function(_,k)return k=="HumanoidRootPart" and root end}
local player={UserId=123,Character=ch,Attrs={}}
function player:SetAttribute(k,v)self.Attrs[k]=v end
function player:GetAttribute(k)return self.Attrs[k]end
local task={defer=function(fn)fn()end}
local script={Parent={TravelRules="rules"}}
local game={GetService=function()return {DragonShared={WorldData="data"}}end}
local serviceRequire=function(id)if id=="rules" then return Rules elseif id=="data" then return Data else error("unexpected service require")end end
local Service=(function(require,game,script,Vector3,CFrame,task,os)
-- TRAVEL_SOURCE
end)(serviceRequire,game,script,Vector3,CFrame,task,{clock=function()return now end})
local profile={Data=Domain.Fresh()}
local profiles={Entries={[123]=profile}}
local collision=false
local World={
 Ground=function(p)
  local i=Data.At(p.X,p.Z)
  return i and {Position=Vector3.new(p.X,i.Center[2],p.Z)} or nil
 end,
 CastMove=function()return collision and {} or nil end,
}
local T=Service.new(World,Evolution,profiles,Domain)
local count=0
local function check(ok,msg)count+=1;assert(ok,msg)end
local function close(a,b,msg)check(math.abs(a-b)<.001,msg)end
local function input(x,y,z,seq)
 now+=.11;T.Input(player,{Seq=seq,X=x,Y=y,Z=z,Boost=false})
end
T.Add(player);T.LoadProfile(player);T.Character(player)
local e=T.Entries[player]
check(e.Island=="grassland" and not e.Mounted,"starter island")
close(root.Position.X,-3400,"spawn X")
check(T.Toggle(player),"mount near landing")
check(root.Anchored and humanoid.PlatformStand and e.Mounted,"server owns mounted root")
local before=e.FlightPosition
input(1,0,0,1);T.Step(.1)
close(root.Position.X-before.X,8,"first-stage server speed")
T.Input(player,{Seq=2,X=0/0,Y=0,Z=0,Boost=false})
check(e.Seq==1,"NaN flight input rejected")
T.Input(player,{Seq=2,X=0,Y=0,Z=0,Boost=false,Position=Vector3.new(0,0,0)})
check(e.Seq==1,"client destination rejected")
now+=1;before=e.FlightPosition;T.Step(.1)
close((e.FlightPosition-before).Magnitude,0,"stale input stops flight")
before=e.FlightPosition
input(0,1,0,2);T.Step(.1)
close(e.FlightPosition.Y-before.Y,8,"UP intent really increases server altitude")
local above=e.FlightPosition
input(0,-1,0,3);T.Step(.1)
close(above.Y-e.FlightPosition.Y,8,"DOWN intent really decreases server altitude")
input(0,-1,0,4)
for _=1,12 do T.Step(.1) end
check(e.FlightPosition.Y>=7.5,"descent cannot enter the ground")
local forest=Data.Islands.elven_forest
local edge=Vector3.new(forest.Center[1]-forest.Size[1]/2*math.sqrt(.96)-1,1000,forest.Center[3])
e.FlightPosition=edge;root.CFrame=CFrame.new(edge)
input(1,0,0,20);T.Step(.1)
check(e.Island=="grassland","level-one island gate")
close(e.FlightPosition.X,edge.X,"locked boundary blocks position")
profile.Data.Level=51;collision=true
input(1,0,0,21);T.Step(.1)
check(e.Island=="grassland","collision cannot commit a destination")
check(profile.Data.HomeIsland=="grassland","blocked crossing cannot change saved home")
collision=false;input(1,0,0,22);T.Step(.1)
check(e.Island=="elven_forest" and profile.Data.HomeIsland=="elven_forest","unlocked crossing accepted")
check(player.Attrs.CurrentIsland=="elven_forest","replicated island matches server")
check(not T.Toggle(player),"cannot dismount high above island")
e.FlightPosition=Vector3.new(forest.Center[1],forest.Center[2]+8,forest.Center[3]);root.CFrame=CFrame.new(e.FlightPosition)
check(T.Toggle(player),"dismount near ground")
check(not root.Anchored and not humanoid.PlatformStand and not e.Mounted,"dismount restores control")
local safe=root.CFrame
root.CFrame=CFrame.new(Vector3.new(table.unpack(Data.Islands.volcano.Points[1].Position)))
check(not T.Verify(player),"walking teleport to another island rejected")
close((root.Position-safe.Position).Magnitude,0,"on-foot crossing restored")
check(T.Cave(player,"elven_forest",true),"enter real cave")
check(e.InCave and player.Attrs.InCave,"cave state replicated")
check(T.Verify(player),"cave destination within approved rooms")
check(not T.Toggle(player),"no dragon flight underground")
check(not T.Checkpoint(player),"cannot set cave checkpoint")
check(T.Cave(player,"elven_forest",false),"exit cave")
check(not e.InCave and T.Verify(player),"exit returns to surface")
check(T.Checkpoint(player),"village checkpoint accepted")
T.Character(player)
local city=forest.Points[2].Position
close(root.Position.X,city[1]+24,"respawn uses saved village X")
close(root.Position.Z,city[3]+18,"respawn uses saved village Z")
check(not e.InCave and not e.Mounted,"respawn clears transient travel state")
root.CFrame=CFrame.new(root.Position+Vector3.new(0,100,0))
check(not T.Toggle(player),"cannot remount in midair")
local fx,fz=0,-1
for _=1,60 do
 local x,z=Rules.Turn(fx,fz,0,1,1/60)
 check(math.abs(x*x+z*z-1)<.00001,"reverse facing stays unit length")
 check(fx*x+fz*z>math.cos(.31),"reverse facing cannot snap")
 fx,fz=x,z
end
check(fz>.99,"reverse turn reaches the opposite heading")
print("PASS: "..count.." actual TravelService integration checks (engine doubles)")
