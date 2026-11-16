return function()
 local Shared=game.ReplicatedStorage.DragonShared;local C=require(Shared.Catalog);local Native=require(Shared.NativeModel)
 local sandbox=Instance.new('Folder');sandbox.Parent=workspace
 local report={Monsters=0,Equipment=0,BootSides=0,TranslucentSlime=false}
 local function check(id,kind)
  local rig=Native.Build(sandbox,id,{Scale=1})
  assert(rig.Model:GetAttribute('AuthoredRevision')==9,'Missing v9 detail: '..id)
  assert(#rig.Model:GetChildren()<70,'Unbounded moving model: '..id)
  if kind=='Equipment'then report.Equipment+=1 else report.Monsters+=1 end
  for _,p in ipairs(rig.Model:GetChildren())do
   if p:IsA('BasePart')then
    assert(p.Anchored and not p.CanQuery and not p.CanCollide,'Cosmetic became authoritative physics')
    if id=='slime'and p.Transparency>.1 then report.TranslucentSlime=true end
   end
  end
  rig.Model:Destroy()
 end
 for id in pairs(C.Monsters)do check(id,'Monster')end
 for id,item in pairs(C.Items)do
  check(id,'Equipment')
  if item.Slot=='Boots'then for _,side in ipairs({'BootLeft','BootRight'})do
   local rig=Native.Build(sandbox,id,{Scale=.43})
   for _,p in ipairs(rig.Model:GetChildren())do if p:IsA('BasePart')and p~=rig.Root and p:GetAttribute('ArtGroup')~=side then p:Destroy()end end
   local count=0;for _,p in ipairs(rig.Model:GetChildren())do if p:IsA('BasePart')and p~=rig.Root then count+=1;assert(p:GetAttribute('ArtGroup')==side,'Boots overlap')end end
   assert(count>=3,'Boot side lost visible detail')
   local box,size=rig.Model:GetBoundingBox();local minY=box.Y-size.Y/2
   local footHeight=1.6;local footY=1.0;local offset=-footHeight/2-minY
   Native.Pose(rig,CFrame.new(0,footY+offset,0),0,false)
   box,size=rig.Model:GetBoundingBox();assert(math.abs(box.Y-size.Y/2-(footY-footHeight/2))<.005,'Boot sole fit changed')
   report.BootSides+=1;rig.Model:Destroy()
  end end
 end
 assert(report.Monsters==28 and report.Equipment==30 and report.BootSides==14 and report.TranslucentSlime)
 sandbox:Destroy();return report
end
