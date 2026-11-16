local Native=require(script.Parent.Parent.NativeModel)
local C=require(script.Parent.Parent.Catalog)
local P={}
local function build(view,id)
 local world=Instance.new("WorldModel");world.Parent=view
 local rig=Native.Build(world,id,{Mesh=true})
 rig.Model:PivotTo(CFrame.Angles(0,math.rad(-25),0))
 local camera=Instance.new("Camera");camera.FieldOfView=35
 camera.Parent=view;view.CurrentCamera=camera;view.Ambient=Color3.fromRGB(170,190,215);view.LightColor=Color3.new(1,1,1);view.LightDirection=Vector3.new(-1,-1,-1)
 local direction=Vector3.new(1,.5,-1.9).Unit
 local orientation=CFrame.lookAt(Vector3.zero,-direction)
 local function fit()
  if rig.Destroyed then return end
  local cf,size=rig.Model:GetBoundingBox();local target=cf.Position
  local aspect=math.max(.1,view.AbsoluteSize.X/math.max(1,view.AbsoluteSize.Y))
  local tangent=math.tan(math.rad(camera.FieldOfView/2));local distance=0
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local offset=orientation:VectorToObjectSpace(cf:PointToWorldSpace(Vector3.new(size.X*x,size.Y*y,size.Z*z))-target)
   distance=math.max(distance,offset.Z+math.abs(offset.X)/(tangent*aspect),offset.Z+math.abs(offset.Y)/tangent)
  end end end
  camera.CFrame=CFrame.lookAt(target+direction*(distance*1.12+.15),target)
 end
 rig.FitPreview=fit;view:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit);fit()
 return rig
end
function P.Build(view,kind,color,monster,itemId)
 local id=itemId or (monster and kind) or "training_sword"
 if not Native.Record(id) then id="training_sword" end
 return build(view,id)
end
function P.Dragon(view,stage) return build(view,stage.Id) end
-- Use the actual equipped/world model in detail pages, with the original art available beside it.
function P.Inspect(parent,kind,color,monster,itemId,height)
 local U=require(script.Parent.Components)
 local Art=require(script.Parent.ApprovedArt)
 local key=itemId or (monster and kind) or 'training_sword'
 local host=U.Frame(parent,'Preview',{Size=UDim2.new(1,-4,0,height or 240)})
 U.Round(host,12);U.Stroke(host,color,.45)
 local body=U.Frame(host,'PreviewBody',{Position=UDim2.fromOffset(0,36),Size=UDim2.new(1,0,1,-36),BackgroundTransparency=1,ClipsDescendants=true})
 local current,rig,turnLeft,turnRight,modelButton,artButton
 local inspector={Host=host}
 local function rotate(angle)
  if not rig or rig.Destroyed then return end
  local box=rig.Model:GetBoundingBox();local center=box.Position
  rig.Model:PivotTo(CFrame.new(center)*CFrame.Angles(0,math.rad(angle),0)*CFrame.new(-center)*rig.Model:GetPivot())
  rig.FitPreview()
 end
 local function show(mode)
  if current==mode then return end
  if mode=='Art' and not Art.Has(key)then return end
  current=mode;rig=nil;U.Clear(body)
  host:SetAttribute('PreviewMode',mode)
  if mode=='Model'then
   local view=U.New('ViewportFrame',body,{Name='ActualModel',Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
   rig=P.Build(view,kind,color,monster,itemId)
  else Art.Mount(body,key)end
  if modelButton then modelButton.TextColor3=mode=='Model' and color or U.Colors.Text end
  if artButton then artButton.TextColor3=mode=='Art' and color or U.Colors.Text end
  if turnLeft then turnLeft.Visible=mode=='Model';turnRight.Visible=mode=='Model' end
 end
 modelButton=U.Button(host,'立體外觀',function()show('Model')end,{Name='ShowModel',Position=UDim2.fromOffset(5,3),Size=UDim2.new(.5,-8,0,28),TextSize=13})
 if Art.Has(key)then
  artButton=U.Button(host,'設計圖',function()show('Art')end,{Name='ShowArt',Position=UDim2.new(.5,3,0,3),Size=UDim2.new(.5,-8,0,28),TextSize=13})
 end
 turnLeft=U.Button(body,'<',function()rotate(-25)end,{Name='TurnLeft',Position=UDim2.new(0,8,1,-34),Size=UDim2.fromOffset(30,26),ZIndex=3,TextSize=18})
 turnRight=U.Button(body,'>',function()rotate(25)end,{Name='TurnRight',Position=UDim2.new(1,-38,1,-34),Size=UDim2.fromOffset(30,26),ZIndex=3,TextSize=18})
 -- Keep rotation controls outside the disposable render surface.
 turnLeft.Parent=host;turnRight.Parent=host
 turnLeft.Position=UDim2.new(0,8,1,-34);turnRight.Position=UDim2.new(1,-38,1,-34)
 inspector.Show=show;inspector.Rotate=rotate
 show('Model');return inspector
end
return P

