return function()
 local Shared=game.ReplicatedStorage.DragonShared;local C=require(Shared.Catalog);local Data=require(Shared.WorldData)
 local Settings=require(game.ServerScriptService.DragonServer.Settings)
 local Motion=require(game.ServerScriptService.DragonServer.MonsterMotion)
 local World=require(game.ServerScriptService.DragonServer.World).new(C,Settings)
 local report={Spawns=0,SurfaceMin=math.huge,CaveMin=math.huge,IdleSurfaceMin=math.huge,IdleCaveMin=math.huge,MaxChasers=0,LeashChecks=0}
 for _,m in pairs(World.Monsters)do
  report.Spawns+=1
  assert(m.Spec.LeashRadius and m.Spec.AggroRange and m.Spec.IdleRadius,'Missing server movement limits')
  if m.Spec.Space=='Surface'then
   local hit=World.Ground(Vector3.new(table.unpack(m.Spec.Position)))
   assert(hit and math.abs(m.Root.Position.Y-m.HalfHeight-hit.Position.Y)<1,'Invalid actual ground: '..m.Id)
  else assert(Data.InCave(Data.Islands[m.Spec.Island],m.Root.Position.X,m.Root.Position.Y,m.Root.Position.Z),'Cave spawn outside rooms')end
 end
 local function spacing(surfaceKey,caveKey)
  for i,a in ipairs(World.Spawns)do for j=i+1,#World.Spawns do
   local b=World.Spawns[j]
   if a.Island==b.Island and a.Space==b.Space then
    local distance=Motion.Distance(World.Monsters[a.Id].Root.Position,World.Monsters[b.Id].Root.Position)
    local key=a.Space=='Cave'and caveKey or surfaceKey;report[key]=math.min(report[key],distance)
   end
  end end
 end
 spacing('SurfaceMin','CaveMin');assert(report.SurfaceMin>=90 and report.CaveMin>=65,'Spawns still clumped')
 -- Run actual server steering without players, then make one player draw aggro.
 for _=1,120 do World.Step(.12,{})end
 spacing('IdleSurfaceMin','IdleCaveMin');assert(report.IdleSurfaceMin>45 and report.IdleCaveMin>35,'Idle patrols collapse together')
 -- Put three live enemies within acquisition range to exercise the two-enemy cap.
 for _,entry in pairs(World.Monsters)do entry.Dead=true end
 local center=Vector3.new(table.unpack(Data.Islands.grassland.Points[3].Position))
 for n,delta in ipairs({Vector3.new(35,0,0),Vector3.new(-17.5,0,30.31),Vector3.new(-17.5,0,-30.31)})do
  local entry=World.Monsters["slime_"..n];local at=center+delta;local hit=World.Ground(at)
  entry.Home=Vector3.new(at.X,hit.Position.Y+entry.HalfHeight,at.Z);entry.Root.CFrame=CFrame.new(entry.Home);entry.Dead=false
 end
 local m=World.Monsters.slime_1
 local root=Instance.new('Part');root.Anchored=true;root.CanQuery=false;root.Position=center+Vector3.new(0,5,0);root.Parent=workspace
 local player={GetAttribute=function()return false end}
 local humanoid={Health=100000,Parent=workspace,TakeDamage=function()end}
 local p={Player=player,Root=root,Humanoid=humanoid,Stats={Defense=0},Island='grassland',InCave=false,CanFight=true}
 for tick=1,100 do
  World.Step(.12,{p});local attackers=0
  for _,entry in pairs(World.Monsters)do
   assert(Motion.Distance(entry.Root.Position,entry.Home)<=(entry.Spec.LeashRadius or 0)+.01,'Server leash escaped: '..entry.Id)
   report.LeashChecks+=1
   if entry.Aggro and not C.Monsters[entry.Kind].Boss then attackers+=1 end
  end
  report.MaxChasers=math.max(report.MaxChasers,attackers);assert(attackers<=2,'Whole pack follows player')
 end
 assert(report.MaxChasers==2,'Three-enemy fixture did not exercise the pursuit cap')
 root.Position=m.Home+Vector3.new(180,0,0);World.Step(.12,{p});assert(not m.Aggro,'Target outside home leash not released')
 -- Exact overlaps have a stable separation direction, and movement never exceeds its budget.
 local neighbors={{Id='b',Root={Position=Vector3.zero},Separation=13}}
 local separated=Motion.Separate(Vector3.zero,'a',neighbors,13,1.2)
 assert(separated.X<0 and separated.Magnitude<=1.2001,'Exact overlap steering is invalid')
 assert(Motion.Distance(Motion.ClampHome(Vector3.new(100,8,0),Vector3.zero,38),Vector3.zero)<=38.001,'Planar clamp failed')
 root:Destroy();World.Folder:Destroy();return report
end
