local Shared=game.ReplicatedStorage.DragonShared;local Native=require(Shared.NativeModel);local C=require(Shared.Catalog)
local art=Shared.BakedArt:Clone();local models=art.PolishedModels
Native.ShapeTemplates=art.Shapes;Native.CrystalTemplate=art.UnitCrystal
local sandbox=Instance.new('Folder');sandbox.Name='V9Bake';sandbox.Parent=workspace
local Geometry=game:GetService('GeometryService');local stats={Monsters=0,Equipment=0,Unions=0,Models=0}
local ids={};for id in pairs(C.Monsters)do table.insert(ids,id)end;for id in pairs(C.Items)do table.insert(ids,id)end;table.sort(ids)
for index,id in ipairs(ids)do
 local old=models:FindFirstChild(id);if old then old:Destroy()end
 local record=Native.Record(id);assert(record.AuthoredRevision==9,'Missing v9: '..id)
 local model=Instance.new('Model');model.Name=id
 local root=Instance.new('Part');root.Name='VisualRoot';root.Size=Vector3.one*.1;root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.Parent=model;model.PrimaryPart=root
 local groups={}
 for _,spec in ipairs(record.Parts)do
  local group=spec.Group or'Body';local alpha=spec.Transparency or 0;local reflect=spec.Reflectance or 0
  local material=spec.Neon and Enum.Material.Neon or spec.Material and Enum.Material[spec.Material]or Enum.Material.SmoothPlastic
  local key=group..'_'..spec.Color..'_'..material.Name..'_'..alpha..'_'..reflect
  local g=groups[key];if not g then g={Parts={},Group=group,Material=material,Alpha=alpha,Reflect=reflect};groups[key]=g end
  local part=Native.MakePart(spec,sandbox,1,false);table.insert(g.Parts,part)
 end
 for key,g in pairs(groups)do
  local results
  if #g.Parts==1 then results=g.Parts else
   local rest={};for n=2,#g.Parts do rest[#rest+1]=g.Parts[n]end
   local ok,value=pcall(function()return Geometry:UnionAsync(g.Parts[1],rest,{RenderFidelity=Enum.RenderFidelity.Precise,CollisionFidelity=Enum.CollisionFidelity.Box,SplitApart=false})end)
   assert(ok and value and #value>0,'V9 union failed: '..id..' '..key..' '..tostring(value));results=value;stats.Unions+=1
   for _,p in ipairs(g.Parts)do p:Destroy()end
  end
  for n,part in ipairs(results)do
   assert(not part:IsA('MeshPart'),'Transient mesh cannot enter deliverable')
   part.Name=key..'_'..n;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
   part.Material=g.Material;part.Transparency=g.Alpha;part.Reflectance=g.Reflect;part.CastShadow=g.Alpha<.4 and g.Material~=Enum.Material.Neon
   if part:IsA('PartOperation')then part.UsePartColor=false;part.SmoothingAngle=record.Kind=='Equipment'and 25 or 38 end
   part:SetAttribute('ArtGroup',g.Group);part.Parent=model
  end
 end
 model:SetAttribute('BakedVersion',9);model:SetAttribute('AuthoredRevision',9);model:SetAttribute('DetailPartCount',#record.Parts);model.Parent=models
 stats.Models+=1;if C.Monsters[id]then stats.Monsters+=1 else stats.Equipment+=1 end
 print('V9_BAKED',index,#ids,id,#model:GetChildren());task.wait()
end
assert(stats.Monsters==28 and stats.Equipment==30);sandbox:Destroy()
local raw=game:GetService('SerializationService'):SerializeInstancesAsync({art})
local again=game:GetService('SerializationService'):DeserializeInstancesAsync(raw);assert(#again[1].PolishedModels:GetChildren()==62)
print('V9_BAKE_SUMMARY',game:GetService('HttpService'):JSONEncode(stats),buffer.len(raw))
local b64=buffer.tostring(game:GetService('EncodingService'):Base64Encode(raw))
for start=1,#b64,24000 do print('V9_ART_CHUNK_'..math.floor((start-1)/24000+1)..':'..b64:sub(start,start+23999))end
print('V9_ART_COMPLETE')
