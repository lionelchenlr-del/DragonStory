local RS=game:GetService("ReplicatedStorage")
local Data=require(RS.DragonShared.WorldData)
local Rules=require(script.Parent.TravelRules)
local Service={}
local function vector(v) return Vector3.new(table.unpack(v)) end
function Service.new(World,Evolution,profiles,D)
 local T={Entries={}}
 local function getCharacter(player)
  local ch=player.Character;local h=ch and ch:FindFirstChildOfClass("Humanoid");local root=ch and ch:FindFirstChild("HumanoidRootPart")
  if not h or not root or h.Health<=0 then return nil end
  return ch,h,root
 end
 function T.Add(player)
  local i=Data.Islands.grassland
  T.Entries[player]={Island="grassland",Mounted=false,InCave=false,LastSafe=CFrame.new(vector(i.Points[1].Position)+Vector3.new(0,5,0)),Input={X=0,Y=0,Z=0,Boost=false},InputAt=0,Seq=-1,LastInput=0,LastCheck=os.clock(),LastPosition=nil,NoticeAt=0}
  player:SetAttribute("CurrentIsland","grassland");player:SetAttribute("IsRiding",false);player:SetAttribute("InCave",false)
 end
 function T.Stop(player)
  local e=T.Entries[player];if not e then return end
  e.Mounted=false;player:SetAttribute("IsRiding",false)
  local _,h,r=getCharacter(player)
  if r then r.Anchored=false;h.PlatformStand=false;h.Sit=false;h.AutoRotate=true end
 end
 function T.Remove(player) T.Stop(player);T.Entries[player]=nil end
 function T.LoadProfile(player)
  local e=T.Entries[player];local profile=profiles.Entries[player.UserId]
  if not e or not profile then return end
  e.Island=profile.Data.HomeIsland or "grassland";player:SetAttribute("CurrentIsland",e.Island)
 end
 function T.Checkpoint(player)
  local e=T.Entries[player];local profile=profiles.Entries[player.UserId]
  if not e or not profile or e.Mounted or e.InCave then return false end
  profile.Data.HomeIsland=e.Island;profile.Data.CheckpointSlot=2;return true
 end
 function T.Notify(player,text)
  local e=T.Entries[player]
  if e and os.clock()-e.NoticeAt>1.5 then e.NoticeAt=os.clock();if T.OnHint then T.OnHint(player,text) end end
 end
 function T.Restore(player,e,root)
  if not root then return end
  root.CFrame=e.LastSafe;root.AssemblyLinearVelocity=Vector3.zero
  e.LastPosition=root.Position;e.LastCheck=os.clock()
 end
 function T.Character(player)
  local e=T.Entries[player];if not e then return end
  local profile=profiles.Entries[player.UserId]
  local checkpoint=profile and profile.Data.CheckpointSlot==2 and 2 or 1
  e.LastSafe=CFrame.new(vector(Data.Islands[e.Island].Points[checkpoint].Position)+(checkpoint==2 and Vector3.new(24,5,18) or Vector3.new(0,5,0)))
  T.Stop(player);e.InCave=false;player:SetAttribute("InCave",false)
  task.defer(function()
   local _,h,r=getCharacter(player)
   if r and T.Entries[player]==e then T.Restore(player,e,r);h.PlatformStand=false end
  end)
 end
 function T.Input(player,payload)
  local e=T.Entries[player]
  if not e or not e.Mounted or not Rules.ValidateInput(payload) then return end
  local now=os.clock()
  if now-e.LastInput<1/22 or payload.Seq<=e.Seq then return end
  e.LastInput=now;e.Seq=payload.Seq;e.Input=payload;e.InputAt=now
 end
 function T.Verify(player)
  local e=T.Entries[player];local _,h,r=getCharacter(player);local profile=profiles.Entries[player.UserId]
  if not e or not h or not profile then return false end
  local pos=r.Position
  if pos.X~=pos.X or pos.Y~=pos.Y or pos.Z~=pos.Z or pos.Magnitude>18000 then T.Restore(player,e,r);return false end
  if e.Mounted then return true end
  local i=Data.Islands[e.Island]
  if e.InCave then
   if not Data.InCave(i,pos.X,pos.Y,pos.Z) then T.Restore(player,e,r);return false end
   return true
  end
  local at=Data.At(pos.X,pos.Z)
  if at and at.Id~=e.Island then
   T.Restore(player,e,r);T.Notify(player,"跨島必須騎龍，已返回安全落點。");return false
  end
  if at and pos.Y<i.Center[2]-70 then T.Restore(player,e,r);return false end
  return at and at.Id==e.Island
 end
 function T.Toggle(player)
  local e=T.Entries[player];local ch,h,r=getCharacter(player);local p=profiles.Entries[player.UserId]
  if not e or not ch or not p then return false,"NOT_ALIVE" end
  if not T.Verify(player) then return false,"RIDE_REQUIRED" end
  if e.InCave then return false,"CAVE_NO_FLIGHT" end
  local stage=Evolution.Resolve(p.Data.Level)
  local clearance=3.6*stage.Scale+3
  if e.Mounted then
   local hit=World.Ground(r.Position,2)
   if not hit or r.Position.Y-hit.Position.Y>clearance+8 then return false,"LAND_FIRST" end
   local at=Data.At(hit.Position.X,hit.Position.Z)
   if not at or at.Id~=e.Island then return false,"LAND_FIRST" end
   T.Stop(player)
   r.CFrame=CFrame.new(hit.Position+Vector3.new(0,4,0))*r.CFrame.Rotation
   e.LastSafe=r.CFrame;e.LastPosition=r.Position;e.LastCheck=os.clock()
   return true,"DISMOUNTED"
  end
  local ground=World.Ground(r.Position,2)
  if not ground or r.Position.Y-ground.Position.Y>12 then return false,"LAND_FIRST" end
  r.Anchored=true;h.PlatformStand=true;h.AutoRotate=false;h.Sit=true
  e.Mounted=true;e.InCave=false;e.Seq=-1;e.InputAt=0;e.Input={X=0,Y=0,Z=0,Boost=false}
  r.CFrame+=Vector3.new(0,clearance,0)
  e.FlightPosition=r.Position;e.Facing=r.CFrame.LookVector
  player:SetAttribute("IsRiding",true)
  return true,"MOUNTED"
 end
 function T.Cave(player,id,enter)
  local e=T.Entries[player];local _,h,r=getCharacter(player)
  if not e or not h or e.Mounted or e.Island~=id then return false,"RIDE_REQUIRED" end
  if enter==e.InCave then return false,"COOLDOWN" end
  local i=Data.Islands[id]
  e.InCave=enter;player:SetAttribute("InCave",enter)
  local pos=enter and vector(Data.Cave(i))+Vector3.new(0,4,18) or vector(i.Points[5].Position)+Vector3.new(0,5,30)
  r.CFrame=CFrame.new(pos);r.AssemblyLinearVelocity=Vector3.zero;e.LastSafe=r.CFrame;e.LastPosition=r.Position;e.LastCheck=os.clock()
  return true,"TRAVELLED"
 end
 function T.Step(dt)
  local now=os.clock()
  for player,e in pairs(T.Entries) do
   local ch,h,r=getCharacter(player);local profile=profiles.Entries[player.UserId]
   if ch and profile then
    local i=Data.Islands[e.Island]
    if e.Mounted then
     local stage=Evolution.Resolve(profile.Data.Level);local clearance=3.6*stage.Scale+3
     local input=now-e.InputAt<.45 and e.Input or {X=0,Y=0,Z=0,Boost=false}
     local speed=({80,105,135,170})[select(2,Evolution.Resolve(profile.Data.Level))]*(input.Boost and 1.45 or 1)
     local v=Rules.Step({e.FlightPosition.X,e.FlightPosition.Y,e.FlightPosition.Z},input,speed,dt)
     local candidate=vector(v)
     if math.abs(candidate.X)>5900 or math.abs(candidate.Z)>6000 then candidate=e.FlightPosition end
     local at=Data.At(candidate.X,candidate.Z)
     if at and at.Id~=e.Island then
      local ok=Rules.CanCross(e.Island,at.Id,true,profile.Data.Level,Data.Islands)
      if not ok then candidate=e.FlightPosition;T.Notify(player,at.Name.." 需要 Lv."..at.MinLevel)
      end
     end
     if at then
      local hit=World.Ground(candidate,80)
      if hit and candidate.Y<hit.Position.Y+clearance then candidate=Vector3.new(candidate.X,hit.Position.Y+clearance,candidate.Z) end
     end
     if World.CastMove(e.FlightPosition,candidate) then candidate=e.FlightPosition end
     -- Commit the destination only after collision checks accept the movement.
     local arrived=Data.At(candidate.X,candidate.Z)
     if arrived and arrived.Id~=e.Island and Rules.CanCross(e.Island,arrived.Id,true,profile.Data.Level,Data.Islands) then
      e.Island=arrived.Id;i=arrived;profile.Data.HomeIsland=arrived.Id;profile.Data.CheckpointSlot=1;profile.Data.Revision+=1
      e.LastSafe=CFrame.new(vector(arrived.Points[1].Position)+Vector3.new(0,5,0))
      player:SetAttribute("CurrentIsland",arrived.Id);T.Notify(player,"抵達 "..arrived.Name)
      if T.OnIsland then T.OnIsland(player,arrived.Id) end
     end
     local motion=Vector3.new(input.X,0,input.Z)
     if motion.Magnitude>.05 then
      local x,z=Rules.Turn(e.Facing.X,e.Facing.Z,motion.X,motion.Z,dt)
      e.Facing=Vector3.new(x,0,z)
     end
     e.FlightPosition=candidate
     r.Anchored=true;r.CFrame=CFrame.lookAt(candidate,candidate+Vector3.new(e.Facing.X,0,e.Facing.Z));r.AssemblyLinearVelocity=Vector3.zero
    else
     T.Verify(player)
     if r.Position.Y<-460 or (not e.InCave and r.Position.Y<i.Center[2]-100) then T.Restore(player,e,r) end
     if now-e.LastCheck>=.25 then
      if not Rules.GroundStepOK(e.LastPosition and {e.LastPosition.X,e.LastPosition.Y,e.LastPosition.Z},{r.Position.X,r.Position.Y,r.Position.Z},D.Stats(profile.Data).Speed,now-e.LastCheck) then T.Restore(player,e,r) end
      e.LastPosition=r.Position;e.LastCheck=now
      local at=Data.At(r.Position.X,r.Position.Z)
      if not e.InCave and at and at.Id==e.Island and r.Position.Y>i.Center[2]-20 then
       local hit=World.Ground(r.Position,2)
       if hit and math.abs(r.Position.Y-hit.Position.Y)<9 then e.LastSafe=r.CFrame end
      elseif e.InCave then e.LastSafe=r.CFrame end
     end
    end
   elseif e.Mounted then e.Mounted=false;player:SetAttribute("IsRiding",false) end
  end
 end
 return T
end
return Service

