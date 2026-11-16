local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Data=require(script.Parent.Parent.WorldData)
local C=require(script.Parent.Parent.Catalog)
local U=require(script.Parent.Components)
local Map={Waypoint=nil}
function Map.SetWaypoint(id,number,spawnId)
 local i=Data.Islands[id];if not i or not i.Points[number] then return end
 if spawnId then
  for _,spec in ipairs(i.Spawns)do if spec.Id==spawnId and spec.Space=="Surface"then
   local monster=C.Monsters[spec.Kind];local name=monster.Name.." Lv."..spec.Level
   Map.Waypoint={Island=id,Point={Position=spec.Position,Name=name},Name=i.Name.."・"..name};return
  end end
  return
 end
 Map.Waypoint={Island=id,Point=i.Points[number],Name=i.Name.."・"..i.Points[number].Name}
end
local function row(parent,text,color,size)
 return U.Label(parent,text,{Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextSize=size or 14,TextColor3=color or U.Colors.Text})
end
function Map.DrawNative(parent,id)
 return require(script.Parent.Cartography).Draw(parent,id,Map.SetWaypoint)
end
local function legacyNavigation(parent,id)
 local plot=U.Frame(parent,"Navigation",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromHex("142E43")})
 U.Round(plot,12)
 local island=Data.Islands[id]
 if island then
  for _,pt in ipairs(island.Points) do
   local x=(pt.Position[1]-island.Center[1])/island.Size[1]+.5
   local y=(pt.Position[3]-island.Center[3])/island.Size[2]+.5
   local b=U.Button(plot,string.format("%02d",pt.Number),function()Map.SetWaypoint(id,pt.Number)end,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,y),Size=UDim2.fromOffset(36,32),TextSize=12,TextColor3=U.Colors.Gold})
   U.Label(b,pt.Name,{Position=UDim2.new(.5,-60,1,2),Size=UDim2.fromOffset(120,27),TextSize=10,TextXAlignment=Enum.TextXAlignment.Center})
  end
 else
  for _,iid in ipairs(Data.Order) do local i=Data.Islands[iid]
   local x=.1+(i.Center[1]+4400)/8800*.8;local y=.1+(i.Center[3]+4500)/8500*.8
   local b=U.Button(plot,i.Name.."\nLv."..i.MinLevel.."–"..i.MaxLevel,function()Map.SetWaypoint(iid,1)end,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(.23,.16),TextSize=11,TextColor3=Color3.fromHex(i.Color)})
  end
  U.Label(plot,"跨島需騎龍・無步行通道",{Position=UDim2.new(0,5,1,-24),Size=UDim2.new(1,-10,0,22),TextSize=11,TextXAlignment=Enum.TextXAlignment.Center,TextColor3=U.Colors.Gold})
 end
 return plot
end
function Map.Show(parent,selected,state,send,notify)
 local Art=require(script.Parent.ApprovedArt)
 local id=selected=="world" and nil or selected;local i=id and Data.Islands[id]
 row(parent,i and i.Name or "天空群島・世界地圖",U.Colors.Gold,22)
 row(parent,"最高 Lv.800  ·  跨島騎龍飛行  ·  已解鎖島嶼可回訪",U.Colors.Muted,12)
 local image=U.Frame(parent,"IslandMap",{Size=UDim2.new(1,-4,0,380),BackgroundColor3=U.Colors.Background})
 U.Round(image,10)
 Art.Mount(image,i and "map_"..id or "map_world")
 local nativeOnly=require(script.Parent.Parent.ArtConfig).UseEmbeddedMaps==false
 local navigation=false
 local switch
 switch=U.Button(parent,"切換高清標記圖",function()
  navigation=not navigation;U.Clear(image)
  if navigation then Map.DrawNative(image,id);switch.Text="查看原始設計圖" else Art.Mount(image,i and "map_"..id or "map_world");switch.Text="切換高清標記圖" end
 end,{Size=UDim2.new(1,-4,0,34),TextSize=12,TextColor3=U.Colors.Gold})
 switch.Visible=not nativeOnly
 local current=Players.LocalPlayer:GetAttribute("CurrentIsland")
 row(parent,"目前位置："..(C.Islands[current] and C.Islands[current].Name or "飛行途中"),U.Colors.Cyan,14)
 if i then
  row(parent,"建議等級 "..i.MinLevel.."–"..i.MaxLevel.."  ·  進入門檻 Lv."..i.MinLevel,U.Colors.Gold,14)
  for _,pt in ipairs(i.Points) do
   U.Button(parent,string.format("%02d  %s  ·  標記",pt.Number,pt.Name),function()Map.SetWaypoint(id,pt.Number);notify("已標記："..pt.Name)end,{Size=UDim2.new(1,-4,0,38),TextSize=13,TextColor3=Color3.fromHex(i.Color)})
  end
  row(parent,"本島委託：到補給區的委託 NPC 領取獎勵",U.Colors.Gold,15)
  for _,qid in ipairs(C.QuestOrder) do local q=C.Quests[qid]
   if q.Island==id then
    local kills=state.Kills[q.Monster] or 0;local done=state.QuestClaims[qid]
    row(parent,(done and "✓ " or "◇ ")..q.Name.."："..C.Monsters[q.Monster].Name.." "..math.min(kills,q.Count).."/"..q.Count,done and U.Colors.Muted or U.Colors.Text,13)
    if not done and kills>=q.Count then U.Button(parent,"領取 "..q.Coins.." 金幣 / "..q.XP.." EXP",function()send("ClaimQuest",qid)end,{Size=UDim2.new(1,-4,0,36),TextSize=12}) end
   end
  end
 else
  row(parent,"選擇左側島嶼查看八個地點、怪物分區與委託。",U.Colors.Text,14)
  row(parent,"WASD／搖桿控制騎龍，空白鍵升高、Q下降、Shift加速；靠近地面按F下龍。",U.Colors.Cyan,13)
 end
end
function Map.StartHUD(gui)
 local marker=Instance.new("Part");marker.Name="LocalWaypoint";marker.Size=Vector3.new(.1,.1,.1);marker.Transparency=1;marker.Anchored=true;marker.CanCollide=false;marker.CanQuery=false;marker.CanTouch=false
 local billboard=Instance.new("BillboardGui");billboard.Size=UDim2.fromOffset(220,60);billboard.StudsOffset=Vector3.new(0,12,0);billboard.AlwaysOnTop=true;billboard.MaxDistance=12000;billboard.Parent=marker
 local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.TextColor3=U.Colors.Gold;label.TextStrokeTransparency=.2;label.TextSize=17;label.Font=Enum.Font.GothamBold;label.Parent=billboard
 local caption=U.Label(gui,"",{Name="WaypointCaption",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,62),Size=UDim2.new(.8,0,0,22),TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,TextColor3=U.Colors.Gold,Visible=false})
 local elapsed=0
 local conn=RunService.RenderStepped:Connect(function(dt)
  elapsed+=dt;if elapsed<.2 then return end;elapsed=0
  local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
  local panel=gui:FindFirstChild("MainPanel")
  if Map.Waypoint and root then
   local at=Vector3.new(table.unpack(Map.Waypoint.Point.Position));local distance=math.floor((root.Position-at).Magnitude)
   marker.Position=at;marker.Parent=workspace
   label.Text="◆ "..Map.Waypoint.Point.Name.."\n"..distance.." studs"
   caption.Text="◆ "..Map.Waypoint.Name.."  "..distance.." studs";caption.Visible=not (panel and panel.Visible)
  else marker.Parent=nil;caption.Visible=false end
 end)
 return function()conn:Disconnect();marker:Destroy();caption:Destroy()end
end
return Map

