-- A complete native-part renderer remains visible if optional mesh APIs are unavailable.
local Shared=script.Parent
local Index=require(Shared.VisualRecipes)
local Meshes=require(Shared.DragonMeshes)
local SpecMesh=require(Shared.SpecMesh)
local Model={}
local records={}
function Model.Record(id)
 if not Index[id] then return nil end
 if not records[id] then records[id]=require(Shared.VisualChunks:FindFirstChild(Index[id])) end
 return records[id]
end
function Model.MakePart(p,parent,scale,gameplay)
 scale=scale or 1
 local art=Shared:FindFirstChild("BakedArt")
 if p.Prefab then
  local template=assert(art and art:FindFirstChild("Scenery") and art.Scenery:FindFirstChild(p.Prefab),"Missing scenery: "..p.Prefab)
  local model=template:Clone();model.Name=p.Name;model:ScaleTo((p.Scale or 1)*scale)
  local r=p.Rotation or {0,0,0}
  model:PivotTo(CFrame.new(table.unpack(p.Position))*CFrame.Angles(math.rad(r[1]),math.rad(r[2]),math.rad(r[3])))
  model.Parent=parent;return model
 end
 local crystal=Model.CrystalTemplate or (art and art:FindFirstChild("UnitCrystal"))
 local shapes=Model.ShapeTemplates or (art and art:FindFirstChild("Shapes"))
 local shapeKey=p.Shape=="Rock" and "Rock_"..tostring(p.Seed or 0) or p.Shape
 local template=shapes and shapes:FindFirstChild(shapeKey)
 local part=template and template:Clone() or p.Shape=="Crystal" and crystal and crystal:Clone() or Instance.new(p.Shape=="Wedge" and "WedgePart" or "Part")
 part.Name=p.Name
 if p.Shape=="Ball" then part.Shape=Enum.PartType.Ball elseif p.Shape=="Cylinder" then part.Shape=Enum.PartType.Cylinder end
 part.Size=Vector3.new(math.max(.01,p.Size[1]*scale),math.max(.01,p.Size[2]*scale),math.max(.01,p.Size[3]*scale))
 local pos=Vector3.new(p.Position[1]*scale,p.Position[2]*scale,p.Position[3]*scale)
 if p.Basis then part.CFrame=CFrame.fromMatrix(pos,Vector3.new(table.unpack(p.Basis[1])),Vector3.new(table.unpack(p.Basis[2])),Vector3.new(table.unpack(p.Basis[3])))
 else local r=p.Rotation or {0,0,0};part.CFrame=CFrame.new(pos)*CFrame.Angles(math.rad(r[1]),math.rad(r[2]),math.rad(r[3])) end
 part.Color=Color3.fromHex(p.Color)
 part.Material=p.Neon and Enum.Material.Neon or (p.Material and Enum.Material[p.Material] or Enum.Material.SmoothPlastic)
 part.Transparency=p.Transparency or 0
 part.Reflectance=p.Reflectance or 0
 if part:IsA("PartOperation") then part.UsePartColor=true end
 part.Anchored=true
 part.CanCollide=gameplay and p.Collide~=false or false
 part.CanQuery=part.CanCollide
 part.CanTouch=false
 part.CastShadow=not p.Neon
 part.Parent=parent
 return part
end
function Model.Build(parent,id,options)
 options=options or {};local record=assert(Model.Record(id),"unknown visual: "..tostring(id));local scale=options.Scale or 1
 local art=Shared:FindFirstChild("BakedArt");local prefabs=art and art:FindFirstChild("PolishedModels")
 local prefab=prefabs and prefabs:FindFirstChild(id)
 if prefab then
  local model=prefab:Clone();model:ScaleTo(scale);model.Parent=parent
  local rig={Model=model,Root=model.PrimaryPart,Wings={},Destroyed=false,Scale=scale,Record=record}
  local stageScale=record.Stage and record.Stage.Scale or 1
  for _,part in ipairs(model:GetChildren()) do
   local group=part:GetAttribute("ArtGroup")
   if part:IsA("BasePart") and (group=="WingLeft" or group=="WingRight") then
    local side=group=="WingLeft" and -1 or 1
    local hinge=record.WingHinge or {.8,3.2,.15}
    table.insert(rig.Wings,{Part=part,Base=part.CFrame,Hinge=CFrame.new(side*hinge[1]*stageScale*scale,hinge[2]*stageScale*scale,hinge[3]*stageScale*scale),Side=side})
   end
  end
  model:SetAttribute("VisualId",id);model:SetAttribute("ArtRenderer","BakedSculpture")
  model.Destroying:Connect(function()rig.Destroyed=true end)
  return rig
 end
 local model=Instance.new("Model");model.Name=id
 local root=Instance.new("Part");root.Name="VisualRoot";root.Size=Vector3.new(.1,.1,.1);root.Transparency=1
 root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.Parent=model;model.PrimaryPart=root
 local rig={Model=model,Root=root,Wings={},Destroyed=false,Scale=scale,Record=record}
 local stageScale=record.Stage and record.Stage.Scale or 1
 local function wing(part,base,group)
  if group~="WingLeft" and group~="WingRight" then return end
  local side=group=="WingLeft" and -1 or 1
  table.insert(rig.Wings,{Part=part,Base=base,Hinge=CFrame.new(side*.95*stageScale*scale,2.95*stageScale*scale,.15*scale),Side=side})
 end
 for _,p in ipairs(record.Parts) do local part=Model.MakePart(p,model,scale,false);wing(part,part.CFrame,p.Group) end
 model.Parent=parent;model:SetAttribute("VisualId",id);model:SetAttribute("ArtRenderer","NativeSculpture")
 model.Destroying:Connect(function() rig.Destroyed=true;if rig.MeshKey then Meshes.Release(rig.MeshKey) end end)
 if options.Mesh then task.spawn(function()
  local key="native_"..id.."_"..tostring(scale)
  local parts=Meshes.Get({Id=key},function() return SpecMesh.Build(record,scale) end)
  if not parts or rig.Destroyed then return end
  Meshes.Retain(key);rig.MeshKey=key
  local cf=model:GetPivot()
  for _,p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p~=root then p:Destroy() end end
  rig.Wings={}
  for _,data in ipairs(parts) do local p=data.Template:Clone();p.CFrame=cf*data.Center;p.Parent=model;wing(p,data.Center,data.Group) end
  model:SetAttribute("ArtRenderer","SculptedMesh")
 end) end
 return rig
end
function Model.Pose(rig,cf,time,animate)
 if rig.Destroyed then return end
 rig.Model:PivotTo(cf)
 if animate~=false then
  for _,w in ipairs(rig.Wings) do
   if w.Part.Parent then w.Part.CFrame=cf*w.Hinge*CFrame.Angles(0,0,w.Side*math.sin(time*3.4)*.12)*w.Hinge:Inverse()*w.Base end
  end
 end
end
return Model

