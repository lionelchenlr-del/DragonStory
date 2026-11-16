local C=require("../src/ReplicatedStorage/DragonShared/Catalog")
local Settings=require("../src/ServerScriptService/DragonServer/Settings")
local D=require("../src/ServerScriptService/DragonServer/Domain").new(C,Settings)
local Guard=require("../src/ServerScriptService/DragonServer/RequestGuard")
local Travel=require("../src/ServerScriptService/DragonServer/TravelRules")
local ProfileStore=require("../src/ServerScriptService/DragonServer/ProfileStore")
local Combat=require("../src/ServerScriptService/DragonServer/CombatRules")
local Data=require("../src/ReplicatedStorage/DragonShared/WorldData")
local Evolution=require("../src/ReplicatedStorage/DragonShared/DragonEvolution")
local Loot=require("../src/ReplicatedStorage/DragonShared/LootInfo")
local Art=require("../src/ReplicatedStorage/DragonShared/ArtManifest")
local VisualIndex=require("../src/ReplicatedStorage/DragonShared/VisualRecipes")
local SpecMesh=require("../src/ReplicatedStorage/DragonShared/SpecMesh")
local Geometry=require("../src/ReplicatedStorage/DragonShared/Geometry")
local total=0
local function check(ok,msg) total+=1;assert(ok,"FAIL #"..total..": "..msg) end
local function equal(a,b,msg) check(a==b,msg..": "..tostring(a).." ~= "..tostring(b)) end
local function copy(t) if type(t)~="table" then return t end;local r={};for k,v in pairs(t) do r[k]=copy(v) end;return r end
local Intent=require("../src/ReplicatedStorage/DragonShared/FlightIntent")
equal(Intent.Resolve({Up=true},true).Y,1,"visible ascend button intent")
equal(Intent.Resolve({Down=true},true).Y,-1,"visible descend button intent")
equal(Intent.Resolve({Up=true,Down=true},true).Y,0,"opposed vertical keys hover")
local off=Intent.Resolve({Up=true,Forward=true,Boost=true},false)
check(off.X==0 and off.Y==0 and off.Z==0 and not off.Boost,"menu and focus loss suppress flight")
local diagonal=Intent.Resolve({Forward=true,Right=true,Up=true},true)
check(diagonal.X*diagonal.X+diagonal.Z*diagonal.Z<=1.000001 and diagonal.Y==1,"direction plus ascent stays bounded")

equal(C.MaxLevel,800,"cap");equal(#C.MonsterOrder,28,"monster count");equal(#C.SetOrder,7,"sets");equal(#C.ShopOrder,20,"market offers")
check(Loot.Validate(C,Settings),"public probabilities agree with private server")
for _,mid in ipairs(C.MonsterOrder) do
 local pool=Settings.DropTables[mid];local counts={};local none=0
 for roll=1,10000 do local id=D.SelectDrop(mid,roll);if id then counts[id]=(counts[id] or 0)+1 else none+=1 end end
 for k,id in ipairs(pool.Items) do equal(counts[id],pool.Weights[k],mid.." exact categorical outcome");check(C.Items[id]~=nil,"known drop") end
 equal(none,pool.None,mid.." exact no-item outcome")
 check(not pcall(D.SelectDrop,mid,0),"reject invalid random draw")
 check(Art.Regions[mid]~=nil,"monster illustration mapped")
 local def=C.Monsters[mid];check(C.Islands[def.Island]~=nil and def.MapPoint>=3 and def.MapPoint<=6,"monster map linked")
end
for _,set in ipairs(C.SetOrder) do
 equal(#C.Sets[set].Items,4,"four-piece set")
 for _,id in ipairs(C.Sets[set].Items) do
  local sources=Loot.ForItem(id,C.MonsterOrder);equal(#sources,4,"four actual sources per equipment")
  check(Art.Regions[id]~=nil,"equipment illustration mapped")
  for _,source in ipairs(sources) do check(source.Chance>0 and source.Chance<=1,"valid item probability") end
 end
end
check(#Loot.ForItem("training_sword",C.MonsterOrder)==0,"starter gift is not random loot")
equal(Loot.Percent(.02),"2%","percentage formatting")
local mismatch=copy(Settings);mismatch.DropTables.slime.Weights[1]+=1
check(not pcall(Loot.Validate,C,mismatch),"startup rejects misleading UI weights")

local p=D.Fresh()
equal(p.Version,2,"profile version");equal(D.Stats(p).Attack,20,"starter attack");equal(D.Stats(p).HP,120,"starter health")
check(D.Purchase(p,"sky_guard_sword_offer",1),"valid first-island purchase")
equal(p.Coins,360,"correct server price");equal(p.Inventory.sky_guard_sword,1,"purchase inventory")
check(D.Equip(p,"sky_guard_sword"),"owned gear equip")
local hpBefore=D.Stats(p).HP
for _,q in ipairs({-1,0,1.5,11,0/0,math.huge,-math.huge,"1",{}}) do
 local coins=p.Coins;check(not D.Purchase(p,"sky_guard_sword_offer",q),"bad quantities denied");equal(p.Coins,coins,"no partial debit")
end
check(not D.Purchase(p,"flame_sword_offer",1),"high tier cannot be purchased early")
check(not D.Equip(p,"void_sword"),"unowned cannot equip")
p.Inventory.void_sword=1;check(not D.Equip(p,"void_sword"),"high level gear cannot equip")
check(not D.Unequip(p,"Coins"),"unknown slot denied")
for _,id in ipairs(C.Sets.sky_guard.Items) do p.Inventory[id]=1;check(D.Equip(p,id),"wear full first set") end
equal(D.Stats(p).Sets.sky_guard,4,"four worn slots")
check(D.Stats(p).HP>hpBefore,"set/armor raises max HP")
local count=p.Inventory.sky_guard_sword
check(not D.Sell(p,"sky_guard_sword",count),"last equipped copy cannot be sold")
equal(p.Inventory.sky_guard_sword,count,"failed sell atomic")
D.Unequip(p,"Weapon");check(D.Sell(p,"sky_guard_sword",1),"sell verified owned item")
check(not D.Sell(p,"sky_guard_sword",1),"cannot sell nonexistent item")
p=D.Fresh();p.Inventory.sky_guard_sword=99
local n=D.Reward(p,"slime",1,1);check(n.Pending and n.Item=="sky_guard_sword","full stack retained in pending")
equal(p.PendingItems.sky_guard_sword,1,"pending increments")
check(not D.ClaimPending(p,"sky_guard_sword"),"cannot exceed cap claiming pending")
check(D.Sell(p,"sky_guard_sword",1),"make room")
check(D.ClaimPending(p,"sky_guard_sword"),"claim saved pending")
equal(p.Inventory.sky_guard_sword,99,"pending moved once");check(p.PendingItems.sky_guard_sword==nil,"pending cleared")
check(not D.ClaimPending(p,"sky_guard_sword"),"cannot replay pending claim")
p=D.Fresh();local before=p.Coins
check(not D.ClaimQuest(p,"grassland_field"),"unfinished quest denied")
p.Kills.slime=5;check(D.ClaimQuest(p,"grassland_field"),"server kill count completes quest")
local claimed=p.Coins;check(claimed>before,"quest awards coins")
check(not D.ClaimQuest(p,"grassland_field"),"quest idempotent");equal(p.Coins,claimed,"quest replay gives nothing")
check(D.Secret(p,"grassland","secret"),"first secret")
local secretCoins=p.Coins;check(not D.Secret(p,"grassland","secret"),"secret cannot be farmed by replay")
equal(p.Coins,secretCoins,"secret replay atomic")
check(not D.Secret(p,"dragon_sanctuary","secret"),"locked island reward denied")
check(not D.Secret(p,"grassland","whatever"),"invalid secret suffix denied")
D.AddXP(p,1e10);equal(p.Level,800,"bulk XP caps");equal(p.XP,0,"max XP reset")
p.Coins=Settings.MaxCoins;D.Reward(p,"ancient_divine_dragon",10000,800);equal(p.Coins,Settings.MaxCoins,"coin cap")
local raw=D.Fresh();raw.Version=1;raw.Level=2;raw.Inventory.flame_sword=5;raw.Equipment.Weapon="flame_sword";raw.Coins=0/0;raw.XP=math.huge;raw.Inventory.fake=999
local clean=D.Normalize(raw);equal(clean.Version,2,"v1 migration");equal(clean.Inventory.flame_sword,5,"legacy ownership retained")
check(clean.Equipment.Weapon==nil,"legacy equip revalidated against new level");check(clean.Inventory.fake==nil,"unknown inventory stripped")
equal(clean.Coins,0,"NaN sanitized");equal(clean.XP,0,"infinite XP sanitized")
raw=D.Fresh();raw.HomeIsland="dragon_sanctuary";raw.CheckpointSlot=999
clean=D.Normalize(raw);equal(clean.HomeIsland,"grassland","invalid future checkpoint rejected");equal(clean.CheckpointSlot,2,"checkpoint bounded")
check(D.Normalize({Version=99})==nil,"future schema fails closed")

local good={Id="valid-1",Action="Buy",Key="sky_guard_sword_offer",Quantity=1}
check(Guard.Validate(good),"valid envelope")
for _,field in ipairs({"Coins","Price","Damage","Chance","Monster","Level","Position"}) do
 local r=copy(good);r[field]=1;check(not Guard.Validate(r),"unknown client field rejected "..field)
end
for _,action in ipairs({"Reward","SetLevel","Evolve","Teleport","GiveItem"}) do check(not Guard.Validate({Id="bad",Action=action,Key="astral"}),"privileged remote absent") end
check(Guard.Validate({Id="ride",Action="Ride"}),"ride requires no destination")
check(not Guard.Validate({Id="ride",Action="Ride",Key="dragon_sanctuary"}),"cannot request flight destination")
local g=Guard.new(0);for i=1,16 do check(Guard.Allow(g,0),"bucket allows budget") end
check(not Guard.Allow(g,0),"flood limited");check(Guard.Allow(g,1),"bucket refills")
check(Guard.Remember(g,"same"),"fresh id");check(not Guard.Remember(g,"same"),"replay denied")
local input={Seq=1,X=1,Y=0,Z=1,Boost=false}
check(Travel.ValidateInput(input),"bounded input")
for _,field in ipairs({"Position","CFrame","Speed","Stage","Island","Mounted"}) do local r=copy(input);r[field]=1;check(not Travel.ValidateInput(r),"flight rejects authority field "..field) end
for _,value in ipairs({math.huge,0/0,2,-2,"1",{}}) do local r=copy(input);r.X=value;check(not Travel.ValidateInput(r),"bad direction rejected") end
local v=Travel.Step({0,0,0},input,100,.1)
check(math.abs(math.sqrt(v[1]^2+v[3]^2)-10)<1e-6,"diagonal normalized, no speed bonus")
for _,id in ipairs(C.IslandOrder) do
 local i=Data.Islands[id]
 check(Travel.CanCross(id,id,false,i.MinLevel,Data.Islands),"own island walking")
 check(not Travel.CanCross("grassland",id,false,800,Data.Islands) or id=="grassland","no foot crossing even at max level")
 if id~="grassland" then check(not Travel.CanCross("grassland",id,true,i.MinLevel-1,Data.Islands),"flight level gate") end
 check(Travel.CanCross("grassland",id,true,i.MinLevel,Data.Islands),"legitimate mounted arrival")
 check(Art.Regions["map_"..id]~=nil,"island map embedded")
 for _,point in ipairs(i.Points) do check(Data.Contains(i,point.Position[1],point.Position[3]),"POI within island") end
 equal(#i.Spawns,18,"18 configured living enemies per island")
 for _,spec in ipairs(i.Spawns) do
  check(C.Monsters[spec.Kind]~=nil,"spawn registry known")
  local def=C.Monsters[spec.Kind];check(spec.Level>=def.Level and spec.Level<=def.MaxLevel,"spawn level bounded")
  if spec.Space=="Cave" then check(Data.InCave(i,table.unpack(spec.Position)),"cave enemies spawn indoors, not entrance")
  else check(Data.Contains(i,spec.Position[1],spec.Position[3]),"surface enemy is on own island") end
 end
end
for k,aId in ipairs(Data.Order) do for j=k+1,#Data.Order do
 local a,b=Data.Islands[aId],Data.Islands[Data.Order[j]]
 local dx=math.max(0,math.abs(a.Center[1]-b.Center[1])-(a.Size[1]+b.Size[1])/2)
 local dz=math.max(0,math.abs(a.Center[3]-b.Center[3])-(a.Size[2]+b.Size[2])/2)
 check(math.sqrt(dx*dx+dz*dz)>=1400,"all pairwise island construction gaps")
end end
for level=1,799 do check(C.RequiredXP(level)>0 and C.RequiredXP(level+1)>C.RequiredXP(level),"monotonic XP curve") end
for _,case in ipairs({{1,1},{150,1},{151,2},{350,2},{351,3},{650,3},{651,4},{800,4},{0/0,1},{math.huge,1}}) do equal(select(2,Evolution.Resolve(case[1])),case[2],"evolution threshold") end
equal(Evolution.Progress(650).Remaining,1,"last stage progress")
local live={HP=10,Dead=false}
local accepted,killed=Combat.Apply(live,10);check(accepted and killed,"lethal hit")
check(not Combat.Apply(live,10),"second lethal hit cannot reward")
for id,name in pairs(VisualIndex) do
 local record=require("../src/ReplicatedStorage/DragonShared/VisualChunks/"..name)
 check(#record.Parts>0 and #record.Parts<=1100,"bounded authoring model "..id)
 for _,part in ipairs(record.Parts) do
  check(#part.Size==3 and part.Size[1]>0 and part.Size[2]>0 and part.Size[3]>0,"positive native primitive")
  for _,number in ipairs(part.Position) do check(number==number and math.abs(number)<200,"finite local model coordinate") end
 end
 local meshes=SpecMesh.Build(record,1);check(#meshes>0,"mesh fallback recipe exists")
 for _,m in ipairs(meshes) do
  for _,f in ipairs(m.Faces) do check(m.Vertices[f[1]] and m.Vertices[f[2]] and m.Vertices[f[3]],"valid face indices") end
  local count=0
  for _,chunk in ipairs(Geometry.Split(m,8000)) do check(#chunk.Faces<=8000,"mesh chunk budget");count+=#chunk.Faces end
  equal(count,#m.Faces,"mesh partition retains all faces")
 end
end


-- Exercise actual ProfileStore logic with a deterministic in-memory UpdateAsync.
local records, fakeTime, guid = {}, 1000, 0
local failNetwork = false
local store = {}
function store:UpdateAsync(key, transform)
	if failNetwork then error("injected network outage") end
	local old = records[key] and copy(records[key]) or nil
	transform(old) -- Simulate a retried transform; no result should leak across calls.
	local result = transform(old)
	if result then records[key] = copy(result) end
	return result and copy(result) or nil
end
local services = {
	DataStoreService = { GetDataStore = function() return store end },
	HttpService = { GenerateGUID = function() guid += 1; return "session-" .. guid end },
	RunService = { IsStudio = function() return false end },
	Time = function() return fakeTime end,
	Wait = function() end,
	Warn = function() end,
}
local A = ProfileStore.new(D, Settings, services)
local B = ProfileStore.new(D, Settings, services)
local first = A.Load(42)
check(first ~= nil and A.Writable(42), "first session acquires profile")
local blocked, reason = B.Load(42)
check(blocked == nil and reason == "SESSION_LOCKED", "second session cannot enter")
D.Purchase(first.Data, "sky_guard_sword_offer", 1)
check(A.Save(42, false), "autosave commits")
equal(records.u_42.Data.Coins, 360, "debit and grant persist together")
equal(records.u_42.Data.Inventory.sky_guard_sword, 1, "same snapshot saves inventory")
A.Close(42)
check(records.u_42.Lock == nil and A.Entries[42] == nil, "close releases lock")
local second = B.Load(42)
equal(second.Data.Coins, 360, "rejoin preserves coins")
fakeTime += Settings.LeaseSeconds
check(not B.Writable(42), "expired session stops mutations")
local third = A.Load(42)
check(third ~= nil, "expired lock can be reclaimed")
second.Data.Coins = 999999
check(not B.Save(42, false) and second.Lost, "stale owner cannot overwrite new owner")
equal(records.u_42.Data.Coins, 360, "stale session failed closed")
records.u_99 = { Schema = 1, Data = { Version = 99 } }
local unsupported = A.Load(99)
check(unsupported == nil, "future profile version refused")
equal(records.u_99.Data.Version, 99, "unsupported profile not overwritten")
failNetwork = true
local failed, failedReason = A.Load(101)
check(failed == nil and failedReason == "LOAD_FAILED", "load outage fails closed")
check(records.u_101 == nil, "load outage never creates default profile")
third.Data.Coins = 123
check(not A.Save(42, false), "save outage reports failure")
equal(records.u_42.Data.Coins, 360, "save outage preserves stored data")
failNetwork = false
check(A.Save(42, false), "save recovers after outage")
equal(records.u_42.Data.Coins, 123, "recovered save commits current state")
local volatileServices = copy(services)
volatileServices.RunService.IsStudio = function() return true end
local V = ProfileStore.new(D, Settings, volatileServices)
check(not V.Persistent and V.Load(100) ~= nil, "Studio defaults to memory-only")

print("PASS: "..total.." assertions: exact loot outcomes, economy, persistence, migration, travel, level 800, 62 models and geometry.")
