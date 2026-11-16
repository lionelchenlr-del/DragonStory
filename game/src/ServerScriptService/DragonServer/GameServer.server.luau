local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local root=script.Parent;local shared=RS:WaitForChild("DragonShared")
local C=require(shared.Catalog);local Settings=require(root.Settings)
require(shared.LootInfo).Validate(C,Settings)
local D=require(root.Domain).new(C,Settings)
local Guard=require(root.RequestGuard)
local Profiles=require(root.ProfileStore).new(D,Settings)
local World=require(root.World).new(C,Settings)
local Evolution=require(shared.DragonEvolution)
local Dragons=require(root.DragonService).new(World.Folder,Evolution)
local Travel=require(root.TravelService).new(World,Evolution,Profiles,D)
local WorldData=require(shared.WorldData)
local rng=Random.new()
assert(not RS:FindFirstChild("DragonRemotes"),"duplicate DragonServer")
local remotes=Instance.new("Folder");remotes.Name="DragonRemotes"
local request=Instance.new("RemoteEvent");request.Name="Request";request.Parent=remotes
local update=Instance.new("RemoteEvent");update.Name="Update";update.Parent=remotes
local flight=Instance.new("RemoteEvent");flight.Name="FlightInput";flight.Parent=remotes;remotes.Parent=RS
local sessions,loading={},{};local shuttingDown=false
local function character(player)
 local ch=player.Character;local h=ch and ch:FindFirstChildOfClass("Humanoid");local r=ch and ch:FindFirstChild("HumanoidRootPart")
 if not h or not r or h.Health<=0 then return nil end
 local p=r.Position;if p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z or p.Magnitude>18000 then return nil end
 return ch,h,r
end
local function applyStats(player,full)
 local e=Profiles.Entries[player.UserId];local ch=player.Character;local h=ch and ch:FindFirstChildOfClass("Humanoid")
 if not e or not h or h.Health<=0 then return end
 local s=D.Stats(e.Data);local hp=h.Health;h.MaxHealth=s.HP;h.Health=full and s.HP or math.min(hp,s.HP);h.WalkSpeed=s.Speed
 for _,slot in ipairs(C.Slots) do player:SetAttribute("Equipped_"..slot,e.Data.Equipment[slot]) end
end
local function state(player)
 local e=Profiles.Entries[player.UserId];if not e then return nil end
 local p=D.Normalize(e.Data);p.Stats=D.Stats(p);p.Persistent=Profiles.Persistent;p.DragonStage=select(2,Evolution.Resolve(p.Level))
 local t=Travel.Entries[player];p.CurrentIsland=t and t.Island or "grassland";p.Riding=t and t.Mounted or false;return p
end
local function push(player) if player.Parent==Players then update:FireClient(player,{Kind="State",State=state(player)}) end end
local function hint(player,text,tab) if player.Parent==Players then update:FireClient(player,{Kind="Hint",Text=text,Tab=tab}) end end
Travel.OnHint=function(p,text) hint(p,text) end
 Travel.OnIsland=function(player) push(player) end
local function changed(player)
 local e=Profiles.Entries[player.UserId];e.Data.Revision+=1;Dragons.Refresh(player,e.Data.Level);applyStats(player,false)
end
local function reply(player,id,ok,code,include,notice)
 if player.Parent==Players then update:FireClient(player,{Kind="Reply",Id=id,Ok=ok,Code=code,State=include and state(player) or nil,Notice=notice}) end
end
local function near(r,anchor) return anchor and (r.Position-anchor.Position).Magnitude<=Settings.ShopRange end
local function attack(player,session,id)
 local m=World.Monsters[id];if not m or m.Dead or not m.Model.Parent then return false,"BAD_TARGET" end
 local t=Travel.Entries[player];if not t or t.Mounted then return false,"DISMOUNT_TO_FIGHT" end
 if not Travel.Verify(player) or t.Island~=m.Spec.Island or t.InCave~=(m.Spec.Space=="Cave") then return false,"BAD_TARGET" end
 local e=Profiles.Entries[player.UserId]
 if e.Data.Level<C.Islands[m.Spec.Island].MinLevel then return false,"LEVEL_LOW" end
 local ch,h,r=character(player);if not ch then return false,"NOT_ALIVE" end
 if os.clock()-session.LastAttack<Settings.AttackCooldown then return false,"COOLDOWN" end
 if (r.Position-m.Root.Position).Magnitude>Settings.AttackRange then return false,"TOO_FAR" end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={ch}
 local hit=workspace:Raycast(r.Position,m.Root.Position-r.Position,params)
 if hit and not hit.Instance:IsDescendantOf(m.Model) then return false,"BLOCKED" end
 session.LastAttack=os.clock();player:SetAttribute("AttackSerial",(player:GetAttribute("AttackSerial") or 0)+1)
 local damage=D.Stats(e.Data).Attack
 if World.Damage(m,damage) then
  local notice=D.Reward(e.Data,m.Kind,rng:NextInteger(1,10000),m.Stats.Level);notice.Damage=damage;notice.Kill=true;changed(player)
  return true,"LOOT",notice
 end
 return true,"HIT",{Damage=damage,Taken=0}
end
request.OnServerEvent:Connect(function(player,payload,...)
 local s=sessions[player];if not s or not Guard.Allow(s.Guard,os.clock()) then return end
 if select("#",...)~=0 or not Guard.Validate(payload) then return end
 if not Guard.Remember(s.Guard,payload.Id) then reply(player,payload.Id,false,"DUPLICATE",true);return end
 if shuttingDown then reply(player,payload.Id,false,"CLOSING",false);return end
 if not Profiles.Writable(player.UserId) then reply(player,payload.Id,false,"NOT_READY",false);return end
 if payload.Action=="Sync" then reply(player,payload.Id,true,"SYNC",true);return end
 local ch,h,r=character(player);if not ch then reply(player,payload.Id,false,"NOT_ALIVE",false);return end
 if not Travel.Verify(player) then reply(player,payload.Id,false,"RIDE_REQUIRED",false);return end
 local e=Profiles.Entries[player.UserId];local t=Travel.Entries[player];local ok,code,notice
 if payload.Action=="Ride" then ok,code=Travel.Toggle(player)
 elseif payload.Action=="Attack" then ok,code,notice=attack(player,s,payload.Key)
 elseif payload.Action=="Buy" then
  local offer=C.Shop[payload.Key]
  if t.Mounted or t.InCave or not offer or offer.Island~=t.Island or not near(r,World.Shops[t.Island]) then reply(player,payload.Id,false,offer and "SHOP_FAR" or "BAD_OFFER",false);return end
  ok,code=D.Purchase(e.Data,payload.Key,payload.Quantity)
 elseif payload.Action=="Sell" then
  if t.Mounted or t.InCave or not (near(r,World.Shops[t.Island]) or near(r,World.Workbenches[t.Island])) then reply(player,payload.Id,false,"SHOP_FAR",false);return end
  ok,code=D.Sell(e.Data,payload.Key,payload.Quantity)
 elseif payload.Action=="Equip" then ok,code=D.Equip(e.Data,payload.Key)
 elseif payload.Action=="Unequip" then ok,code=D.Unequip(e.Data,payload.Key)
 elseif payload.Action=="ClaimPending" then ok,code=D.ClaimPending(e.Data,payload.Key)
 elseif payload.Action=="ClaimQuest" then
  local q=C.Quests[payload.Key]
  if t.Mounted or t.InCave or not q or q.Island~=t.Island or not near(r,World.Quests[t.Island]) then reply(player,payload.Id,false,"QUEST_FAR",false);return end
  ok,code,notice=D.ClaimQuest(e.Data,payload.Key)
 end
 if ok and payload.Action~="Attack" and payload.Action~="Ride" then changed(player) end
 reply(player,payload.Id,ok,code,payload.Action~="Attack" or code=="LOOT",notice)
end)
flight.OnServerEvent:Connect(function(player,payload,...)
 if select("#",...)~=0 or not Profiles.Writable(player.UserId) then return end
 local s=sessions[player];if not s then return end
 local now=os.clock();if now-(s.FlightAt or 0)<1/24 then return end;s.FlightAt=now;Travel.Input(player,payload)
end)
World.OnInteract=function(player,kind,id,anchor)
 local e=Profiles.Entries[player.UserId];local s=sessions[player];local t=Travel.Entries[player]
 local ch,h,r=character(player)
 if not e or not s or not t or not ch or not Profiles.Writable(player.UserId) then return end
 if t.Mounted or t.Island~=id or not near(r,anchor) or not Travel.Verify(player) then return end
 local now=os.clock();if now-(s.InteractAt or 0)<.6 then return end;s.InteractAt=now
 if kind=="Shop" then hint(player,"只可購買目前島嶼的商店裝備。","Shop");return end
 if kind=="Workbench" then hint(player,"裝備工作台：可出售重複裝備、領取暫存掉落。","Inventory");return end
 if kind=="Checkpoint" then if Travel.Checkpoint(player) then changed(player);push(player);hint(player,"復活點已設為本島補給區。") end;return end
 if kind=="EnterCave" or kind=="ExitCave" then
  local ok,code=Travel.Cave(player,id,kind=="EnterCave")
  if ok then push(player);hint(player,kind=="EnterCave" and "已進入地下洞窟；怪物在第二室，第三室有遺物。" or "已返回地表。") else hint(player,code) end
  return
 end
 local ok,code,notice
 if kind=="Quest" then
  local count,coins,xp=0,0,0
  for _,qid in ipairs(C.QuestOrder) do if C.Quests[qid].Island==id then local accepted,_,n=D.ClaimQuest(e.Data,qid);if accepted then count+=1;coins+=n.Coins;xp+=n.XP end end end
  if count>0 then changed(player);push(player);hint(player,"領取 "..count.." 項委託：+"..coins.." 金幣、+"..xp.." EXP")
  else hint(player,"委託目標請看地圖頁：野外5隻、精英3隻、洞窟2隻、頭目1隻。") end
  return
 elseif kind=="Gather" then
  if t.InCave then return end;s.Gather=s.Gather or {}
  if now-(s.Gather[id] or -math.huge)<60 then hint(player,"這個採集點還在恢復，請稍後再來。");return end
  s.Gather[id]=now;ok,code,notice=D.Gather(e.Data,id)
 elseif kind=="Secret" or kind=="Relic" then
  if (kind=="Relic")~=t.InCave then return end
  ok,code,notice=D.Secret(e.Data,id,kind=="Secret" and "secret" or "relic")
 end
 if ok then changed(player);push(player);hint(player,"取得 +"..notice.Coins.." 金幣、+"..notice.XP.." EXP")
 elseif code then hint(player,code=="SECRET_CLAIMED" and "這份祕境獎勵已領取。" or code) end
end
local function joined(player)
 if sessions[player] or loading[player] or shuttingDown then return end
 loading[player]=true;sessions[player]={Guard=Guard.new(os.clock()),LastAttack=-math.huge};Travel.Add(player)
 sessions[player].CharacterConnection=player.CharacterAdded:Connect(function(ch)
  local h=ch:WaitForChild("Humanoid",10)
  if h and Profiles.Entries[player.UserId] then Travel.Character(player);applyStats(player,true) end
 end)
 local e,reason=Profiles.Load(player.UserId)
 if not e then loading[player]=nil;if player.Parent==Players then player:Kick("資料載入未完成（"..tostring(reason).."），請稍後重連。") end;return end
 if player.Parent~=Players or shuttingDown then Profiles.Close(player.UserId);loading[player]=nil;return end
 loading[player]=nil;Travel.LoadProfile(player);applyStats(player,true);Travel.Character(player);Dragons.Refresh(player,e.Data.Level);push(player)
 task.delay(1,function()if player.Parent==Players then hint(player,"歡迎來到天空群島！F騎龍、M地圖標記02補給村、R互動、E攻擊。") end end)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
 Dragons.Remove(player);Travel.Remove(player)
 local s=sessions[player];if s and s.CharacterConnection then s.CharacterConnection:Disconnect() end
 sessions[player]=nil;if not loading[player] then Profiles.Close(player.UserId) end
end)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(joined,p) end
local aiTime,healTime=0,0
RunService.Heartbeat:Connect(function(dt)
 if shuttingDown then return end
 Travel.Step(math.min(dt,.1));aiTime+=dt;healTime+=dt
 if aiTime>=.12 then
  local list={}
  for p in pairs(sessions) do
   local ch,h,r=character(p);local e=Profiles.Entries[p.UserId];local t=Travel.Entries[p]
   if ch and e and t and Profiles.Writable(p.UserId) then
    table.insert(list,{Player=p,Root=r,Humanoid=h,Stats=D.Stats(e.Data),Island=t.Island,InCave=t.InCave,CanFight=not t.Mounted and not World.IsSafe(t.Island,r.Position)})
    if healTime>=1 and not t.Mounted and not t.InCave and World.IsSafe(t.Island,r.Position) then h.Health=math.min(h.MaxHealth,h.Health+h.MaxHealth*.035) end
   end
  end
  World.Step(math.min(aiTime,.2),list);aiTime=0;if healTime>=1 then healTime=0 end
 end
end)
if RunService:IsStudio() then
 local test=Instance.new("BindableFunction");test.Name="StudioTest";test.Parent=root
 test.OnInvoke=function(userId,command,value)
  local p=Players:GetPlayerByUserId(userId);if not p or not Profiles.Writable(userId) then return false end
  local e=Profiles.Entries[userId]
  if type(command)=="number" then value=command;command="Level" end
  if command=="Level" then
   if type(value)~="number" or value%1~=0 or value<1 or value>C.MaxLevel then return false end
   e.Data.Level=value;e.Data.XP=0;e.Data=D.Normalize(e.Data);Travel.LoadProfile(p);Travel.Character(p);changed(p);push(p);return true
  elseif command=="Gear" then
   for id,item in pairs(C.Items) do if e.Data.Level>=item.Level then e.Data.Inventory[id]=1;e.Data.Discovered[id]=true end end
   changed(p);push(p);return true
  elseif command=="Merchant" or command=="Target" then
   local t=Travel.Entries[p];local _,h,r=character(p)
   if not t or not h then return false end
   local destination
   if command=="Merchant" then t.InCave=false;p:SetAttribute("InCave",false);destination=World.Shops[t.Island] and World.Shops[t.Island].CFrame*CFrame.new(0,0,-7)
   else
    local m=World.Monsters[value]
    if not m or m.Dead or e.Data.Level<C.Islands[m.Spec.Island].MinLevel then return false end
    t.Island=m.Spec.Island;t.InCave=m.Spec.Space=="Cave";p:SetAttribute("CurrentIsland",t.Island);p:SetAttribute("InCave",t.InCave)
    destination=m.Root.CFrame*CFrame.new(0,0,-10)
   end
   if not destination then return false end
   Travel.Stop(p);r.CFrame=destination;r.AssemblyLinearVelocity=Vector3.zero;t.LastSafe=destination;t.LastPosition=r.Position;t.LastCheck=os.clock();push(p);return true
  elseif command=="Teleport" then
   local i=WorldData.Islands[value];local t=Travel.Entries[p];local _,h,r=character(p)
   if not i or not h or e.Data.Level<i.MinLevel then return false end
   Travel.Stop(p);t.Island=value;t.InCave=false;p:SetAttribute("CurrentIsland",value);p:SetAttribute("InCave",false)
   e.Data.HomeIsland=value;e.Data.CheckpointSlot=1;e.Data.Revision+=1
   t.LastSafe=CFrame.new(Vector3.new(table.unpack(i.Points[1].Position))+Vector3.new(0,6,0));r.CFrame=t.LastSafe;t.LastPosition=r.Position;push(p);return true
  end
  return false
 end
end
task.spawn(function()
 while not shuttingDown do task.wait(Settings.SaveEvery)
  for id,e in pairs(Profiles.Entries) do if not e.Closing then task.spawn(Profiles.Save,id,false) end end
 end
end)
task.spawn(function()
 while not shuttingDown do task.wait(3)
  for id,e in pairs(Profiles.Entries) do if not e.Closing and (e.Lost or os.time()>=e.Expires-15) then local p=Players:GetPlayerByUserId(id);if p then p:Kick("存檔連線中斷，已暫停交易。請稍後重連。") end end end
 end
end)
game:BindToClose(function()
 shuttingDown=true;for id in pairs(Profiles.Entries) do task.spawn(Profiles.Close,id) end
 local deadline=os.clock()+25;while (next(Profiles.Entries) or next(loading)) and os.clock()<deadline do task.wait(.1) end
end)
print("[Dragon v9] Refined creatures, equipment and scattered encounters / seven islands / 28 monsters / 126 lives / level cap 800 / authoritative 3D flight.")

