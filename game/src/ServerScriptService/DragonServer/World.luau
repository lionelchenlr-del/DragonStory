local RS=game:GetService("ReplicatedStorage")
local Shared=RS:WaitForChild("DragonShared")
local Data=require(Shared.WorldData)
local Native=require(Shared.NativeModel)
local Recipe=require(Shared.WorldRecipe)
local Combat=require(script.Parent.CombatRules)
local Motion=require(script.Parent.MonsterMotion)
local World={}
local function part(parent,name,size,pos,color,visible)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos);p.Color=Color3.fromHex(color or "D2B875")
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Transparency=visible and 0 or 1;p.Parent=parent;return p
end
local function label(parent,text,offset)
 local gui=Instance.new("BillboardGui");gui.Name="Nameplate";gui.Size=UDim2.fromOffset(270,68);gui.StudsOffset=offset or Vector3.new(0,6,0);gui.MaxDistance=180;gui.Parent=parent
 local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=text;t.TextColor3=Color3.fromHex("F5E6C2")
 t.TextStrokeTransparency=.25;t.Font=Enum.Font.GothamBold;t.TextSize=16;t.Parent=gui;return t
end
local function prompt(anchor,name,action,callback)
 local p=Instance.new("ProximityPrompt");p.Name=name;p.ActionText=action;p.ObjectText=anchor.Name;p.HoldDuration=.2;p.MaxActivationDistance=18;p.RequiresLineOfSight=false;p.Parent=anchor
 p.KeyboardKeyCode=Enum.KeyCode.R;p.GamepadKeyCode=Enum.KeyCode.ButtonY
 p.Triggered:Connect(callback)
end
function World.new(C,Settings)
 local W={Monsters={},Shops={},Quests={},Workbenches={},Spawns={},Interactions={}}
 local map=workspace:FindFirstChild("SkyIslands")
 local art=Shared:FindFirstChild("BakedArt");local rocks=art and art:FindFirstChild("PolishedWorld")
 local sculptedNames={SmoothIslandRock=true,ContinuousCliffRim=true,RoundedCliffOutcrop=true,SuspendedStone=true}
 if not map then
  map=Instance.new("Folder");map.Name="SkyIslands";map.Parent=workspace
  for _,id in ipairs(Data.Order) do
   local folder=Instance.new("Folder");folder.Name=id;folder.Parent=map
   for _,name in ipairs(Recipe[id]) do
    for _,spec in ipairs(require(Shared.WorldChunks:FindFirstChild(name))) do
     if not (rocks and rocks:FindFirstChild(id) and sculptedNames[spec.Name]) then Native.MakePart(spec,folder,1,true) end
    end
   end
   if rocks and rocks:FindFirstChild(id) then for _,p in ipairs(rocks[id]:GetChildren()) do p:Clone().Parent=folder end end
  end
 end
 W.Map=map
 local previous=workspace:FindFirstChild("DragonWorld");assert(not previous,"duplicate DragonServer installation")
 local folder=Instance.new("Folder");folder.Name="DragonWorld";folder.Parent=workspace;W.Folder=folder
 local monsterFolder=Instance.new("Folder");monsterFolder.Name="Monsters";monsterFolder.Parent=folder
 local actors=Instance.new("Folder");actors.Name="Services";actors.Parent=folder
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={map}
 function W.Ground(position,height)
  return workspace:Raycast(position+Vector3.new(0,height or 180,0),Vector3.new(0,-(height or 180)-400,0),params)
 end
 function W.CastMove(from,to)
  local delta=to-from;if delta.Magnitude<.001 then return nil end
  return workspace:Blockcast(CFrame.new(from),Vector3.new(3,5,3),delta,params)
 end
 function W.IsSafe(id,pos)
  local i=Data.Islands[id];if not i then return false end
  for _,n in ipairs({1,2}) do
   local p=Vector3.new(table.unpack(i.Points[n].Position))
   if Vector3.new(pos.X-p.X,0,pos.Z-p.Z).Magnitude<(n==1 and 110 or 135) then return true end
  end
  return false
 end
 local function interact(player,kind,id,anchor)
  if W.OnInteract then W.OnInteract(player,kind,id,anchor) end
 end
 local function npc(anchor,color,name)
  local at=anchor.Position
  local library=Shared:FindFirstChild("BakedArt")
  local prefabs=library and library:FindFirstChild("Scenery")
  local template=prefabs and prefabs:FindFirstChild(name=="金幣商人" and "npc_merchant" or "npc_ranger")
  if template then
   local actor=template:Clone();actor.Name=name;actor:PivotTo(CFrame.new(at-Vector3.new(0,3,0)));actor.Parent=actors
  end
  label(anchor,name.."\n◆ 互動",Vector3.new(0,7,0))
 end
 for _,id in ipairs(Data.Order) do
  local i=Data.Islands[id]
  local function anchor(name,point,offset)
   return part(actors,name,Vector3.new(1,1,1),Vector3.new(table.unpack(point))+Vector3.new(table.unpack(offset or {0,4,0})))
  end
  local city=i.Points[2].Position
  W.Shops[id]=anchor("金幣商人_"..id,city,{24,4,-18});npc(W.Shops[id],i.Color,"金幣商人")
  W.Quests[id]=anchor("委託NPC_"..id,city,{-24,4,-18});npc(W.Quests[id],i.Color,"龍騎委託")
  prompt(W.Shops[id],"Shop","選購裝備",function(p) interact(p,"Shop",id,W.Shops[id]) end)
  prompt(W.Quests[id],"Quest","領取已完成委託",function(p) interact(p,"Quest",id,W.Quests[id]) end)
  local workbench=anchor("裝備工作台_"..id,city,{-24,4,18})
  W.Workbenches[id]=workbench
  label(workbench,"裝備工作台\n回收／待領裝備")
  prompt(workbench,"Workbench","整理裝備",function(p) interact(p,"Workbench",id,workbench) end)
  local rest=anchor("復活祭壇_"..id,city,{24,4,18});label(rest,"復活祭壇\n補給區緩慢恢復生命")
  prompt(rest,"Checkpoint","設定復活點",function(p) interact(p,"Checkpoint",id,rest) end)
  local cave=anchor("洞窟入口_"..id,i.Points[5].Position,{0,7,4})
  label(cave,i.Points[5].Name.."\n進入地下探索")
  prompt(cave,"EnterCave","進入洞窟",function(p) interact(p,"EnterCave",id,cave) end)
  local cp=Data.Cave(i)
  local exit=anchor("洞窟出口_"..id,cp,{0,5,24});label(exit,"返回地表")
  prompt(exit,"ExitCave","離開洞窟",function(p) interact(p,"ExitCave",id,exit) end)
  local resource=anchor("採集_"..id,i.Points[7].Position,{0,6,0});label(resource,"龍晶採集點\n每人 60 秒")
  prompt(resource,"Gather","採集龍晶",function(p) interact(p,"Gather",id,resource) end)
  local secret=anchor("祕境寶箱_"..id,i.Points[8].Position,{0,7,0})
  label(secret,"祕境寶箱\n每名玩家首次獎勵")
  prompt(secret,"Secret","開啟寶箱",function(p) interact(p,"Secret",id,secret) end)
  local relic=anchor("洞內遺物_"..id,cp,{0,7,-235})
  prompt(relic,"Relic","調查遺物",function(p) interact(p,"Relic",id,relic) end)
  local landing=anchor("Landing_"..id,i.Points[1].Position,{0,5,0});label(landing,i.Name.."\nLv."..i.MinLevel.."–"..i.MaxLevel.."  騎龍降落場",Vector3.new(0,18,0))
  for _,spec in ipairs(i.Spawns) do table.insert(W.Spawns,spec) end
 end
 local start=Data.Islands.grassland.Points[1].Position
 local spawn=workspace:FindFirstChild("DragonSpawn") or Instance.new("SpawnLocation")
 spawn.Name="DragonSpawn";spawn.Size=Vector3.new(8,1,8);spawn.CFrame=CFrame.new(Vector3.new(table.unpack(start))+Vector3.new(0,5,0))
 spawn.Anchored=true;spawn.Transparency=1;spawn.CanCollide=false;spawn.Neutral=true;spawn.Duration=0;spawn.Parent=workspace
 function W.Spawn(spec)
  local def=C.Monsters[spec.Kind];local stats=C.MonsterStats(spec.Kind,spec.Level)
  local model=Instance.new("Model");model.Name=spec.Id
  local half=def.Boss and 8 or 4
  local pos=Vector3.new(table.unpack(spec.Position))
  if spec.Space~="Cave" then
   local hit=W.Ground(pos)
   if hit and math.abs(hit.Position.Y-pos.Y)<30 then pos=Vector3.new(pos.X,hit.Position.Y,pos.Z) end
  end
  local core=part(model,"Core",Vector3.new(def.Boss and 20 or 9,half*2,def.Boss and 20 or 9),pos+Vector3.new(0,half,0))
  core.CanQuery=true;model.PrimaryPart=core
  for key,value in pairs({MonsterId=spec.Id,Kind=spec.Kind,HP=stats.HP,MaxHP=stats.HP,Level=stats.Level,HalfHeight=half,Island=spec.Island,Space=spec.Space,AggroRange=spec.AggroRange,LeashRadius=spec.LeashRadius,SpawnX=spec.Position[1],SpawnZ=spec.Position[3]}) do model:SetAttribute(key,value) end
  local title=label(core,def.Name.."  Lv."..stats.Level.."\n"..stats.HP.." / "..stats.HP,Vector3.new(0,half+3,0))
  model.Parent=monsterFolder
  local m={Id=spec.Id,Kind=spec.Kind,Spec=spec,Model=model,Root=core,HP=stats.HP,MaxHP=stats.HP,Stats=stats,Dead=false,Home=core.Position,HalfHeight=half,Label=title,NextStrike=0,Clock=0,Phase=math.random()*6.28,Separation=def.Boss and 26 or (spec.Space=="Cave" and 14 or 13)}
  W.Monsters[spec.Id]=m;return m
 end
 function W.Damage(m,damage)
  local accepted,killed=Combat.Apply(m,damage);if not accepted then return false end
  m.Model:SetAttribute("HP",m.HP)
  m.Label.Text=C.Monsters[m.Kind].Name.."  Lv."..m.Stats.Level.."\n"..m.HP.." / "..m.MaxHP
  if not killed then return false end
  m.Model:Destroy()
  task.delay(C.Monsters[m.Kind].Respawn,function() if folder.Parent then W.Spawn(m.Spec) end end)
  return true
 end
 local sight=RaycastParams.new();sight.FilterType=Enum.RaycastFilterType.Include;sight.FilterDescendantsInstances={map}
 function W.Step(dt,players)
  local now=os.clock()
  local groups={};local claims={}
  for _,spec in ipairs(W.Spawns)do
   local m=W.Monsters[spec.Id]
   if m and not m.Dead and m.Model.Parent then
    local key=m.Spec.Island.."_"..m.Spec.Space;groups[key]=groups[key] or {};table.insert(groups[key],m)
   end
  end
  for _,spec in ipairs(W.Spawns) do
   local m=W.Monsters[spec.Id]
   if m and not m.Dead and m.Model.Parent then
    local definition=C.Monsters[m.Kind]
    local aggro=m.Spec.AggroRange or 52;local leash=m.Spec.LeashRadius or 38
    local nearest,best=nil,aggro
    for _,p in ipairs(players) do
     if p.Island==m.Spec.Island and p.CanFight and p.Humanoid.Health>0 then
      local sameSpace=(m.Spec.Space=="Cave")==p.InCave
      local distance=Motion.Distance(p.Root.Position,m.Root.Position)
      local nearHome=Motion.Distance(p.Root.Position,m.Home)<=leash+18
      local available=definition.Boss or (claims[p.Player] or 0)<2
      if sameSpace and nearHome and available and distance<best and not W.IsSafe(p.Island,p.Root.Position) then nearest,best=p,distance end
     end
    end
    if nearest and not definition.Boss then claims[nearest.Player]=(claims[nearest.Player] or 0)+1 end
    local aggroState=nearest~=nil
    if m.Aggro~=aggroState then m.Aggro=aggroState;m.Model:SetAttribute("Aggro",aggroState) end
    m.Clock+=dt
    local target=nearest and nearest.Root.Position or Motion.Patrol(m.Home,m.Clock,m.Phase,m.Spec.IdleRadius or 10)
    target=Motion.ClampHome(target,m.Home,leash)
    local speed=definition.Boss and 9 or 12
    -- Stop before the target, then apply short-range avoidance to every movement.
    local distance=Motion.Distance(target,m.Root.Position)
    local candidate=m.Root.Position
    if distance>(nearest and 12 or 1)then candidate=Motion.Advance(candidate,target,speed,dt)end
    candidate=Motion.Separate(candidate,m.Id,groups[m.Spec.Island.."_"..m.Spec.Space],m.Separation,speed*math.min(dt,.25))
    candidate=Motion.ClampHome(candidate,m.Home,leash)
    local floor=m.Home.Y-m.HalfHeight
    if m.Spec.Space~="Cave" then
     local hit=W.Ground(Vector3.new(candidate.X,floor,candidate.Z),45)
     if hit and math.abs(hit.Position.Y-floor)<6 then floor=hit.Position.Y else candidate=m.Root.Position end
    elseif not Data.InCave(Data.Islands[m.Spec.Island],candidate.X,candidate.Y,candidate.Z)then candidate=m.Root.Position end
    candidate=Vector3.new(candidate.X,floor+m.HalfHeight,candidate.Z)
    local move=candidate-m.Root.Position
    if move.Magnitude>.001 and workspace:Blockcast(CFrame.new(m.Root.Position),Vector3.new(4,6,4),move,params)then candidate=m.Root.Position end
    local look=Vector3.new(target.X,candidate.Y,target.Z)
    if (look-candidate).Magnitude>.05 then m.Root.CFrame=CFrame.lookAt(candidate,look)else m.Root.CFrame=CFrame.new(candidate)*m.Root.CFrame.Rotation end
    if nearest and best<18 and now>=m.NextStrike then
     m.NextStrike=now+(C.Monsters[m.Kind].Boss and 2.2 or 1.8)
     local blocked=workspace:Raycast(m.Root.Position,nearest.Root.Position-m.Root.Position,sight)
     if not blocked then
      m.Model:SetAttribute("Telegraph",now+.55)
      local targetPlayer=nearest
      task.delay(.55,function()
       if not m.Dead and m.Model.Parent and targetPlayer.Humanoid.Parent and targetPlayer.Humanoid.Health>0
        and (targetPlayer.Root.Position-m.Root.Position).Magnitude<19 and targetPlayer.Player:GetAttribute("IsRiding")~=true then
        local obstruction=workspace:Raycast(m.Root.Position,targetPlayer.Root.Position-m.Root.Position,sight)
        if not obstruction then targetPlayer.Humanoid:TakeDamage(math.max(1,m.Stats.Attack-targetPlayer.Stats.Defense)) end
       end
      end)
     end
    end
   end
  end
 end
 for _,spec in ipairs(W.Spawns) do W.Spawn(spec) end
 return W
end
return World

