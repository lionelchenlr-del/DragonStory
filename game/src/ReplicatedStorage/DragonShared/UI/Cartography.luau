-- Resolution-independent cartography drawn with native UI curves, lines and text.
local Players=game:GetService("Players")
local Data=require(script.Parent.Parent.WorldData)
local U=require(script.Parent.Components)
local C=require(script.Parent.Parent.Catalog)
local Map={}
local gold=Color3.fromHex("DFC891");local ink=Color3.fromHex("152E42")
function Map.Draw(parent,id,mark)
 local plot=U.Frame(parent,"CartographyMap",{Size=UDim2.fromScale(1,1),BackgroundColor3=ink,ClipsDescendants=true})
 U.Round(plot,14);U.Gradient(plot,Color3.fromHex("254B5A"),Color3.fromHex("101D35"),55);U.Stroke(plot,gold,.45)
 local function draw()
  if plot.AbsoluteSize.X<30 or plot.AbsoluteSize.Y<30 then return end
  U.Clear(plot)
  local w,h=plot.AbsoluteSize.X,plot.AbsoluteSize.Y
  local function dot(name,x,y,size,color,alpha)
   local p=U.Frame(plot,name,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),BackgroundColor3=color,BackgroundTransparency=alpha or 0})
   U.Round(p,size/2);return p
  end
  local function line(a,b,color,dashed)
   local delta=b-a;local length=delta.Magnitude
   if dashed then
    for n=0,math.floor(length/13) do local t=length>0 and math.min(1,n*13/length) or 0;local p=a+delta*t;dot("FlightRoute",p.X,p.Y,2.5,color,.3) end
   else
    local p=U.Frame(plot,"IslandPath",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2),Size=UDim2.fromOffset(length,2.4),Rotation=math.deg(math.atan2(delta.Y,delta.X)),BackgroundColor3=color,BackgroundTransparency=.2})
    U.Round(p,2)
   end
  end
  for n=1,35 do dot("AtlasStar",((n*97)%997)/997*w,((n*173)%991)/991*h,n%4==0 and 2.2 or 1,gold,.83) end
  local island=Data.Islands[id]
  local current=Players.LocalPlayer:GetAttribute("CurrentIsland")
  if island then
   local function at(pt)return Vector2.new(w*(.12+(pt.Position[1]-island.Center[1])/island.Size[1]*.76+.38),h*(.16+(pt.Position[3]-island.Center[3])/island.Size[2]*.68+.34)) end
   for layer=3,1,-1 do
    local p=U.Frame(plot,"IslandContour",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.82+layer*.025,.73+layer*.023),BackgroundColor3=Color3.fromHex(island.Color),BackgroundTransparency=.76+layer*.045})
    U.Round(p,math.min(w,h)*.38);U.Stroke(p,gold,.75)
   end
   for _,route in ipairs(island.Routes) do for n=1,#route-1 do line(at(island.Points[route[n]]),at(island.Points[route[n+1]]),gold,false) end end
   local legend=U.Label(plot,"青：野外  金：精英  紅：頭目  紫：洞窟",{Position=UDim2.fromOffset(12,10),Size=UDim2.new(1,-66,0,20),TextSize=9,TextColor3=gold})
   for _,spec in ipairs(island.Spawns)do if spec.Space=="Surface"then
    local spawn=spec;local def=C.Monsters[spawn.Kind];local p=at(spawn)
    local color=def.Role=="Boss"and Color3.fromHex("E29391")or def.Role=="Elite"and Color3.fromHex("D8BE77")or Color3.fromHex("87D2C6")
    local b=U.Button(plot,def.Boss and "◆"or "",function()mark(id,spawn.Zone,spawn.Id)end,{Name="Spawn_"..spawn.Id,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(p.X,p.Y),Size=UDim2.fromOffset(def.Boss and 15 or 9,def.Boss and 15 or 9),TextSize=9,TextColor3=ink,BackgroundColor3=color})
    U.Round(b,8);b:SetAttribute("MonsterKind",spawn.Kind)
    b.MouseEnter:Connect(function()legend.Text=def.Name.." Lv."..spawn.Level.."・點擊標記生成點"end)
    b.MouseLeave:Connect(function()legend.Text="青：野外  金：精英  紅：頭目  紫：洞窟"end)
   end end
   for _,pt in ipairs(island.Points) do
    local p=at(pt);local accent=(pt.Number==6 and Color3.fromHex("FFAD9D")) or pt.Number==5 and Color3.fromHex("C9B8F1") or gold
    dot("LocationHalo",p.X,p.Y,34,accent,.85)
    local number=pt.Number
    local b=U.Button(plot,string.format("%02d",number),function()mark(id,number)end,{Name="Point_"..number,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(p.X,p.Y),Size=UDim2.fromOffset(26,26),TextSize=11,TextColor3=accent,BackgroundColor3=Color3.fromHex("1B3548")})
    U.Round(b,13)
    U.Label(plot,pt.Name,{Position=UDim2.fromOffset(p.X-58,p.Y+16),Size=UDim2.fromOffset(116,25),TextSize=10,TextColor3=Color3.fromHex("ECE1C3"),TextXAlignment=Enum.TextXAlignment.Center})
   end
  else
   local positions={}
   for _,iid in ipairs(Data.Order) do local i=Data.Islands[iid];positions[iid]=Vector2.new(w*(.13+(i.Center[1]+3400)/6800*.74),h*(.15+(i.Center[3]+3500)/6700*.69)) end
   for n=1,#Data.Order-1 do line(positions[Data.Order[n]],positions[Data.Order[n+1]],Color3.fromHex("78BCC9"),true) end
   for _,iid in ipairs(Data.Order) do
    local i=Data.Islands[iid];local p=positions[iid];local color=Color3.fromHex(i.Color)
    local b=U.Button(plot,"",function()mark(iid,1)end,{Name="Island_"..iid,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(p.X,p.Y),Size=UDim2.fromOffset(math.clamp(w*.205,72,148),math.clamp(h*.12,32,54)),BackgroundColor3=ink:Lerp(color,.38)})
    U.Round(b,26);local stroke=b:FindFirstChildOfClass("UIStroke");stroke.Color=current==iid and gold or color;stroke.Transparency=current==iid and .05 or .35;stroke.Thickness=current==iid and 2 or 1
    U.Label(b,(current==iid and "◆ " or "")..i.Name,{Position=UDim2.fromScale(0,0),Size=UDim2.new(1,0,.58,0),TextSize=w<400 and 10 or 12,TextColor3=Color3.fromHex("F3E6C6"),TextXAlignment=Enum.TextXAlignment.Center})
    U.Label(b,"Lv."..i.MinLevel.."–"..i.MaxLevel,{Position=UDim2.fromScale(0,.56),Size=UDim2.new(1,0,.44,0),TextSize=9,TextColor3=color:Lerp(Color3.new(1,1,1),.45),TextXAlignment=Enum.TextXAlignment.Center})
   end
  end
  U.Label(plot,"N ↑",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,9),Size=UDim2.fromOffset(40,24),TextSize=13,TextColor3=gold,TextXAlignment=Enum.TextXAlignment.Center})
  U.Label(plot,island and "亮點：14個地表怪物生成點・洞內三室另有4處" or "虛線為騎龍航線・島間沒有橋",{Position=UDim2.new(0,12,1,-28),Size=UDim2.new(1,-24,0,20),TextSize=10,TextColor3=gold,TextXAlignment=Enum.TextXAlignment.Center})
 end
 plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw);draw();return plot
end
return Map
