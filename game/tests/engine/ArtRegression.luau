return function()
 local shared=game.ReplicatedStorage.DragonShared;local art=shared.BakedArt
 assert(#art.PolishedModels:GetChildren()==62,'Creature/equipment library lost')
 assert(#art.Scenery:GetChildren()==37,'Scenery library incomplete')
 assert(art.Shapes:FindFirstChild('GentleTaper'),'Continuous trunk taper missing')
 local native=require(shared.NativeModel);local index=require(shared.VisualRecipes)
 local sandbox=Instance.new('Folder');sandbox.Parent=workspace
 local report={Models=0,Trees=0,AuthoredLeaves=0,PlacedTrees=0,LeafyCanopies=0,WorldParts=0}
 for id in pairs(index)do
  local r=native.Build(sandbox,id,{Scale=.8})
  assert((r.Model:GetAttribute('BakedVersion')==7 or r.Model:GetAttribute('BakedVersion')==8 or r.Model:GetAttribute('BakedVersion')==9),'Legacy model: '..id)
  assert(r.Model:GetAttribute('ArtRenderer')=='BakedSculpture','Missing baked model: '..id)
  local _,size=r.Model:GetBoundingBox();assert(size.Magnitude>.5 and size.Magnitude<200,'Invalid model bounds')
  assert(#r.Model:GetChildren()<70,'Unbounded moving visual')
  for _,p in ipairs(r.Model:GetDescendants())do if p:IsA('BasePart')then assert(p.Anchored and not p.CanQuery and not p.CanCollide,'Cosmetic is physical')end end
  report.Models+=1;r.Model:Destroy()
 end
 for _,m in ipairs(art.Scenery:GetChildren())do
  if m.Name:sub(1,5)=='tree_' and m:GetAttribute('LeafCount')>0 then
   report.Trees+=1;report.AuthoredLeaves+=m:GetAttribute('LeafCount')
   assert(m:GetAttribute('LeafCount')>=280,'Canopy too sparse')
   local copy=native.MakePart({Name='TreeProbe',Prefab=m.Name,Scale=1.8,Position={0,0,0},Rotation={0,33,0}},sandbox,1,true)
   assert(copy.PrimaryPart.Position.Magnitude<.01,'Tree root pivot moved')
   local _,size=copy:GetBoundingBox();assert(size.Y>35 and size.Y<120,'Tree scale lost')
   local leaves=0
   for _,p in ipairs(copy:GetChildren())do
    if p:IsA('PartOperation')and p:GetAttribute('ArtGroup')=='Leaves'then leaves+=1;assert(p.SmoothingAngle==0,'Leaf planes smoothed into blobs')end
   end
   assert(leaves>=5,'Leaf tonal layers missing');report.LeafyCanopies+=1;copy:Destroy()
  end
 end
 assert(report.AuthoredLeaves==6004 and report.Trees==18,'Leaf anatomy regression')
 assert(#workspace.SkyIslands:GetChildren()==7,'Islands lost')
 for _,p in ipairs(workspace.SkyIslands:GetDescendants())do
  assert(p.Name~='FacetedCanopy','Old ball canopy remains')
  if p:IsA('BasePart')then report.WorldParts+=1 end
  if p:IsA('Model')and(p.Name=='LeafyTree'or p.Name=='ArrivalGrove')then report.PlacedTrees+=1 end
 end
 assert(report.PlacedTrees>200,'Trees did not reach the world')
 sandbox:Destroy();return report
end
