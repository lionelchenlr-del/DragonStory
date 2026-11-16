local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Native=require(RS.DragonShared.NativeModel)
local Catalog=require(RS.DragonShared.Catalog)
local Presentation=require(script.Parent.RidePresentation)
local R={}
function R.Start()
 local player=Players.LocalPlayer
 local world=workspace:WaitForChild("DragonWorld");local monsters=world:WaitForChild("Monsters")
 local folder=Instance.new("Folder");folder.Name="CreatureCosmetics";folder.Parent=workspace
 local entries={};local equipped={};local elapsed=0;local effects={}
 local function slash(hrp,color)
  local parts={};local origin=hrp.CFrame
  for index=1,9 do
   local a=math.rad(-82+(index-1)*18);local b=math.rad(-82+index*18)
   local first=origin:PointToWorldSpace(Vector3.new(math.sin(a)*6,1-math.sin(a)*.8,-math.cos(a)*6))
   local last=origin:PointToWorldSpace(Vector3.new(math.sin(b)*6,1-math.sin(b)*.8,-math.cos(b)*6))
   local p=Instance.new("Part");p.Name="ValidatedSlash";p.Size=Vector3.new(.12,.35,(last-first).Magnitude+.12)
   p.CFrame=CFrame.lookAt((first+last)/2,last);p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
   p.Material=Enum.Material.Neon;p.Color=color;p.Parent=folder;table.insert(parts,p)
  end
  table.insert(effects,{At=os.clock(),Parts=parts})
 end
 local function add(model)
  if not model:IsA("Model") or entries[model] then return end
  local e={HP=model:GetAttribute("HP")};entries[model]=e
  e.Telegraph=model:GetAttributeChangedSignal("Telegraph"):Connect(function()e.Flash=os.clock()+.55 end)
  e.Hit=model:GetAttributeChangedSignal("HP"):Connect(function()
   local hp=model:GetAttribute("HP")
   if e.HP and hp and hp<e.HP then e.HitFlash=os.clock()+.14 end
   e.HP=hp
  end)
 end
 local added=monsters.ChildAdded:Connect(add)
 local removed=monsters.ChildRemoved:Connect(function(model)
  local e=entries[model];if e then if e.Rig then e.Rig.Model:Destroy() end;e.Telegraph:Disconnect();e.Hit:Disconnect();entries[model]=nil end
 end)
 for _,model in ipairs(monsters:GetChildren()) do add(model) end
 local function clearPlayer(p)
  local e=equipped[p];if not e then return end
  for _,rig in pairs(e.Rigs) do rig.Model:Destroy() end
  equipped[p]=nil
 end
 local leave=Players.PlayerRemoving:Connect(clearPlayer)
 local function syncEquipment(p)
  local ch=p.Character;local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
  if not hrp then clearPlayer(p);return end
  local e=equipped[p]
  if not e or e.Character~=ch then clearPlayer(p);e={Character=ch,Rigs={},Keys={},AttackSerial=p:GetAttribute("AttackSerial")};equipped[p]=e end
  for _,slot in ipairs({"Weapon","Helmet","Armor","Boots"}) do
   local id=p:GetAttribute("Equipped_"..slot)
   if e.Keys[slot]~=id then
    if e.Rigs[slot] then e.Rigs[slot].Model:Destroy();e.Rigs[slot]=nil end
    if slot=="Boots" then for _,key in ipairs({"BootLeft","BootRight"}) do if e.Rigs[key] then e.Rigs[key].Model:Destroy();e.Rigs[key]=nil end end end
    e.Keys[slot]=id
    if type(id)=="string" and Native.Record(id) then
     if slot=="Boots" then
      for _,side in ipairs({-1,1}) do
       local rig=Native.Build(folder,id,{Scale=.43})
       for _,part in ipairs(rig.Model:GetChildren()) do if part:IsA("BasePart") and part~=rig.Root and part:GetAttribute("ArtGroup")~=(side==-1 and "BootLeft" or "BootRight") then part:Destroy() end end
       local box,size=rig.Model:GetBoundingBox();rig.MinY=box.Position.Y-size.Y/2
       e.Rigs[side==-1 and "BootLeft" or "BootRight"]=rig
      end
     else
      local head=ch:FindFirstChild("Head")
      local helmetScale=head and math.clamp(head.Size.X/1.8,.75,1.25)or 1
      e.Rigs[slot]=Native.Build(folder,id,{Scale=slot=="Weapon" and .62 or slot=="Helmet" and helmetScale or .88})
     end
    end
   end
  end
 end
 RunService:BindToRenderStep("DragonWorldCosmetics",Enum.RenderPriority.Camera.Value+1,function(dt)
  local ch=player.Character;local root=ch and ch:FindFirstChild("HumanoidRootPart");local time=os.clock()
  elapsed+=dt
  if elapsed>.4 then
   elapsed=0
   local nearest={}
   if root then for model,e in pairs(entries) do
    local part=model.PrimaryPart
    if part and model.Parent and (player:GetAttribute("InCave")==true)==(model:GetAttribute("Space")=="Cave") then local distance=(part.Position-root.Position).Magnitude;if distance<650 then table.insert(nearest,{Model=model,Entry=e,Distance=distance}) end end
   end end
   table.sort(nearest,function(a,b)return a.Distance<b.Distance end)
   local keep={}
   for index,entry in ipairs(nearest) do if index<=22 then
    keep[entry.Model]=true
    if not entry.Entry.Rig then
     local kind=entry.Model:GetAttribute("Kind")
     if Native.Record(kind) then
      local rig=Native.Build(folder,kind,{Mesh=true});entry.Entry.Rig=rig
      local glow=Instance.new("Highlight");glow.FillColor=Color3.fromRGB(255,80,90);glow.FillTransparency=.7;glow.OutlineTransparency=.2;glow.Enabled=false;glow.Parent=rig.Model;entry.Entry.Highlight=glow
     end
    end
   end end
   for model,e in pairs(entries) do if not keep[model] and e.Rig then e.Rig.Model:Destroy();e.Rig=nil;e.Position=nil end end
   for _,p in ipairs(Players:GetPlayers()) do
    local pr=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if root and pr and (root.Position-pr.Position).Magnitude<350 then syncEquipment(p) else clearPlayer(p) end
   end
  end
  for model,e in pairs(entries) do if e.Rig and model.PrimaryPart then
   local target=model.PrimaryPart.CFrame*CFrame.new(0,-(model:GetAttribute("HalfHeight") or 4),0)
   local cf=e.Position
   if not cf or (cf.Position-target.Position).Magnitude>70 then cf=target else cf=cf:Lerp(target,1-math.exp(-14*dt)) end
   e.Position=cf;Native.Pose(e.Rig,cf,time,true)
   local hit=(e.HitFlash or 0)>time
   e.Highlight.FillColor=hit and Color3.new(1,1,1) or Color3.fromRGB(255,80,90)
   e.Highlight.Enabled=hit or (e.Flash or 0)>time
  end end
  for p,e in pairs(equipped) do
   local c=e.Character;local hrp=c:FindFirstChild("HumanoidRootPart");local head=c:FindFirstChild("Head")
   if hrp and head then
    local serial=p:GetAttribute("AttackSerial")
    if serial~=e.AttackSerial then
     e.AttackSerial=serial;e.AttackAt=time
     local item=Catalog.Items[e.Keys.Weapon];local color=item and Color3.fromHex(Catalog.Rarities[item.Rarity].Color) or Color3.fromHex("CFFAFF")
     slash(hrp,color)
    end
    local rider=Presentation.Get(p)
    local offset=rider and rider*hrp.CFrame:Inverse() or CFrame.identity
    local torso=c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    if e.Rigs.Helmet then Native.Pose(e.Rigs.Helmet,offset*head.CFrame*CFrame.new(0,.28,0),time,false) end
    if e.Rigs.Armor and torso then Native.Pose(e.Rigs.Armor,offset*torso.CFrame*CFrame.new(0,-.28,0),time,false) end
    if e.Rigs.Weapon then
     local hand=c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
     local progress=e.AttackAt and math.clamp((time-e.AttackAt)/.32,0,1) or 1
     local swing=progress<1 and math.sin(progress*math.pi)*1.4 or 0
     if hand then Native.Pose(e.Rigs.Weapon,offset*hand.CFrame*CFrame.new(0,1.05,-.2)*CFrame.Angles(-swing,0,math.rad(-12)-swing*.65),time,false) end
    end
    for _,pair in ipairs({{"BootLeft","LeftFoot","Left Leg",-1},{"BootRight","RightFoot","Right Leg",1}}) do
     local rig=e.Rigs[pair[1]];local foot=c:FindFirstChild(pair[2]) or c:FindFirstChild(pair[3])
     if rig and foot then Native.Pose(rig,offset*foot.CFrame*CFrame.new(-pair[4]*.85*.43,-foot.Size.Y/2-(rig.MinY or -.62),0),time,false) end
    end
   end
  end
  for index=#effects,1,-1 do
   local effect=effects[index];local age=time-effect.At
   if age>.25 then for _,part in ipairs(effect.Parts) do part:Destroy() end;table.remove(effects,index)
   else for _,part in ipairs(effect.Parts) do part.Transparency=.15+age/.25*.85 end end
  end
 end)
 return function()
  RunService:UnbindFromRenderStep("DragonWorldCosmetics");added:Disconnect();removed:Disconnect();leave:Disconnect()
  for _,e in pairs(entries) do e.Telegraph:Disconnect();e.Hit:Disconnect();if e.Rig then e.Rig.Model:Destroy() end end
  for p in pairs(equipped) do clearPlayer(p) end;folder:Destroy()
 end
end
return R

