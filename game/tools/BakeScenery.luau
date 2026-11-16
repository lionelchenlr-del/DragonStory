-- Editor bake: every visible output is a persistent PartOperation or ordinary Part.
local RS=game:GetService('ReplicatedStorage');local Shared=RS.DragonShared
local Native=require(Shared.NativeModel);local Geometry=game:GetService('GeometryService')
local old=Shared.BakedArt
local art=Instance.new('Folder');art.Name='BakedArt'
local shapes=old.Shapes:Clone();shapes.Parent=art
local unitCrystal=old.UnitCrystal:Clone();unitCrystal.Parent=art;Native.CrystalTemplate=unitCrystal
local sandbox=Instance.new('Folder');sandbox.Name='V7Bake';sandbox.Parent=workspace
local stats={Models=0,Scenery=0,Unions=0,Fallbacks=0,LeafShapes=0}
local function block(size,cf)
 local p=Instance.new('Part');p.Size=size;p.CFrame=cf or CFrame.identity;p.Anchored=true;p.Parent=sandbox;return p
end
local function cutter(normal,d)
 normal=normal.Unit
 local ref=math.abs(normal.Z)>.9 and Vector3.xAxis or Vector3.zAxis
 local right=normal:Cross(ref).Unit;local back=right:Cross(normal).Unit
 return block(Vector3.new(12,12,12),CFrame.fromMatrix(normal*(d+6),right,normal,back))
end
local function shape(name,planes,smooth)
 local p=block(Vector3.one);local cuts={}
 for _,plane in ipairs(planes)do table.insert(cuts,cutter(plane[1],plane[2]))end
 local r=Geometry:SubtractAsync(p,cuts,{SplitApart=false,RenderFidelity=Enum.RenderFidelity.Precise,CollisionFidelity=Enum.CollisionFidelity.Box})
 assert(#r==1 and r[1]:IsA('PartOperation'),'Shape bake must persist as CSG: '..name)
 local out=r[1];out.Name=name;out.UsePartColor=true;out.SmoothingAngle=smooth or 0
 out.Anchored=true;out.CanCollide=false;out.CanQuery=false;out.CanTouch=false;out.CFrame=CFrame.identity;out.Parent=shapes
 p:Destroy();for _,c in ipairs(cuts)do c:Destroy()end
end
local planes={}
for _,side in ipairs({-1,1})do for _,axis in ipairs({'X','Z'})do
 local n=axis=='X' and Vector3.new(side,.07,0) or Vector3.new(0,.07,side)
 table.insert(planes,{n,.465/n.Magnitude})
end end
shape('GentleTaper',planes,28)
Native.ShapeTemplates=shapes
local models=old.PolishedModels:Clone();models.Parent=art
local scenery=Instance.new('Folder');scenery.Name='Scenery';scenery.Parent=art
local world=old.PolishedWorld:Clone();world.Parent=art
stats.Models=#models:GetChildren()
local function combine(parts,parent,name,group,material,smooth)
 local results
 if #parts==1 then results=parts else
  local rest={};for n=2,#parts do rest[#rest+1]=parts[n]end
  local ok,value=pcall(function()return Geometry:UnionAsync(parts[1],rest,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false})end)
  assert(ok and value and #value>0,'V7 bake failed: '..name..' '..tostring(value))
  results=value;stats.Unions+=1
  for _,p in ipairs(parts)do p:Destroy()end
 end
 for n,p in ipairs(results)do
  assert(not p:IsA('MeshPart'),'Runtime-only meshes must not enter persistent artwork')
  p.Name=name..'_'..n;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
  p.Material=material;p.CastShadow=material~=Enum.Material.Neon
  if p:IsA('PartOperation')then p.UsePartColor=false;p.SmoothingAngle=smooth end
  p:SetAttribute('ArtGroup',group);p.Parent=parent
 end
end
local function bake(id,record,destination)
 local model=Instance.new('Model');model.Name=id
 local root=block(Vector3.one*.1);root.Name='VisualRoot';root.Transparency=1;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.Parent=model;model.PrimaryPart=root
 local groups={}
 for _,spec in ipairs(record.Parts)do
  local group=spec.Group or 'Body'
  local material=spec.Neon and Enum.Material.Neon or spec.Material and Enum.Material[spec.Material] or (group=='Bark' and Enum.Material.Wood or Enum.Material.SmoothPlastic)
  local key=group..'_'..spec.Color..'_'..material.Name
  if not groups[key]then groups[key]={Parts={},Group=group,Material=material}end
  local p=Native.MakePart(spec,sandbox,1,false);table.insert(groups[key].Parts,p)
  if spec.Name=='LanceolateLeaf'then stats.LeafShapes+=1 end
 end
 for key,g in pairs(groups)do
  -- Keep foliage faces crisp, cloth/armor edges controlled, organic surfaces smooth.
  combine(g.Parts,model,key,g.Group,g.Material,g.Group=='Leaves' and 0 or g.Group=='Bark' and 20 or 32)
 end
 model:SetAttribute('BakedVersion',7);model:SetAttribute('AuthoredRevision',7)
 model:SetAttribute('LeafCount',record.LeafCount or 0);model.Parent=destination
end
for n,id in ipairs(require(Shared.SceneryIndex))do
 bake(id,require(Shared.SceneryChunks[id]),scenery);stats.Scenery+=1;print('V7_SCENERY',n,id);task.wait()
end
old:Destroy();art.Parent=Shared
-- Build the actual edit-mode map from the same recipes that fallback runtime uses.
local previous=workspace:FindFirstChild('SkyIslands');if previous then previous:Destroy()end
local map=Instance.new('Folder');map.Name='SkyIslands';map.Parent=workspace
local recipe=require(Shared.WorldRecipe);local data=require(Shared.WorldData)
local partCount=0
for _,id in ipairs(data.Order)do
 local island=Instance.new('Folder');island.Name=id;island.Parent=map
 for _,chunk in ipairs(recipe[id])do for _,spec in ipairs(require(Shared.WorldChunks[chunk]))do
  Native.MakePart(spec,island,1,true);partCount+=1
 end end
 print('V7_ISLAND',id,#island:GetChildren());task.wait()
end
local spawn=workspace:FindFirstChild('DragonSpawn')or Instance.new('SpawnLocation');spawn.Name='DragonSpawn';spawn.Size=Vector3.new(8,1,8);spawn.Anchored=true;spawn.CanCollide=false;spawn.Transparency=1;spawn.Neutral=true;spawn.Duration=0;spawn.Position=Vector3.new(table.unpack(data.Islands.grassland.Points[1].Position))+Vector3.new(0,5,0);spawn.Parent=workspace
local camera=workspace.CurrentCamera or Instance.new('Camera');camera.CFrame=CFrame.lookAt(spawn.Position+Vector3.new(180,95,170),spawn.Position+Vector3.new(0,18,-100));camera.Parent=workspace;workspace.CurrentCamera=camera
workspace:SetAttribute('ArtVersion','7.0-LeafAndFacet');game.Lighting.ClockTime=14.6;game.Lighting.Brightness=2.2
sandbox:Destroy()
local function emit(tag,instances)
 local raw=game:GetService('SerializationService'):SerializeInstancesAsync(instances)
 local b64=buffer.tostring(game:GetService('EncodingService'):Base64Encode(raw))
 print(tag..'_SIZE',buffer.len(raw))
 for start=1,#b64,24000 do print(tag..'_CHUNK_'..math.floor((start-1)/24000+1)..':'..b64:sub(start,start+23999))end
 print(tag..'_COMPLETE')
end
print('V7_ART_SUMMARY',game:GetService('HttpService'):JSONEncode(stats),partCount)
emit('V7_ART',{art});emit('V7_MAP',{map});emit('V7_SPAWN',{spawn});emit('V7_CAMERA',{camera})
print('V7_ALL_COMPLETE')
