local probe=Instance.new("ModuleScript");probe.Source=[====[return function()
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
]====];probe.Parent=game.ServerStorage
print("V9_REFINEMENT_REPORT",game:GetService("HttpService"):JSONEncode(require(probe)()))
local probe=Instance.new("ModuleScript");probe.Source=[====[return function()
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
]====];probe.Parent=game.ServerStorage
print("V8_DISTRIBUTION_REPORT",game:GetService("HttpService"):JSONEncode(require(probe)()))
local motion=Instance.new("ModuleScript");motion.Name="FlightMotionRegression";motion.Source=[====[-- Uses real Vector3/CFrame in Studio; snapshots deliberately arrive at 12–25 Hz.
return function()
 local motion=require(game.ReplicatedStorage.DragonShared.RideMotion)
 local rules=require(game.ServerScriptService.DragonServer.TravelRules)
 local metrics={MaxPitchStep60=0,RawPitchStep60=0,MaxTurnStep=0}
 for _,fps in ipairs({30,60,120}) do
  local state={};local dt=1/fps;local target=CFrame.new(0,1000,0);local nextPacket=0
  local previousY,previousPitch,previousRaw=1000,0,0
  motion.Step(state,target,dt)
  for index=1,fps*4 do
   local time=index*dt
   if time>=nextPacket then
    target=CFrame.new(time*80,1000+time*120,0)*CFrame.Angles(0,time,0)
    nextPacket=time+({.04,.08,.05,.06})[index%4+1]
   end
   local oldRawY=state.LastRawY or 1000;state.LastRawY=target.Y
   local raw=math.clamp((target.Y-oldRawY)/dt*.004,-.18,.18)
   local cf,pitch,bank=motion.Step(state,target,dt)
   assert(cf.Y>=previousY-.0001,"Flight interpolation moved backward")
   assert(cf.Y<=target.Y+.001,"Flight interpolation overshot the server")
   assert(math.abs(pitch)<=.180001 and math.abs(bank)<=.200001,"Unsafe visual tilt")
   if fps==60 then
    metrics.MaxPitchStep60=math.max(metrics.MaxPitchStep60,math.abs(pitch-previousPitch))
    metrics.RawPitchStep60=math.max(metrics.RawPitchStep60,math.abs(raw-previousRaw))
   end
   previousY=cf.Y;previousPitch=pitch;previousRaw=raw
  end
  for _=1,fps*2 do motion.Step(state,target,dt) end
  assert((state.CFrame.Position-target.Position).Magnitude<.002,"Hover never settles")
  assert(math.abs(state.Pitch)<.002 and math.abs(state.Bank)<.002,"Hover still rocks")
  local teleport=CFrame.new(1000,2000,3000)
  assert((motion.Step(state,teleport,dt).Position-teleport.Position).Magnitude<.001,"Teleport drags the camera across the map")
 end
 assert(metrics.MaxPitchStep60<.03 and metrics.RawPitchStep60>.17,"Snapshot tilt regression")
 local x,z=0,-1
 for _=1,120 do
  local nx,nz=rules.Turn(x,z,0,1,1/60)
  local angle=math.abs(math.atan2(x*nz-z*nx,x*nx+z*nz))
  metrics.MaxTurnStep=math.max(metrics.MaxTurnStep,angle)
  assert(math.abs(nx*nx+nz*nz-1)<.00001,"Turn direction collapsed")
  assert(angle<.31,"Reversal snaps in one frame")
  x,z=nx,nz
 end
 assert(z>.999,"Reversal did not complete")
 return metrics
end
]====];motion.Parent=game.ServerStorage
print("FLIGHT_MOTION_REPORT",game:GetService("HttpService"):JSONEncode(require(motion)()))
local flight=game.ReplicatedStorage.DragonShared.UI.FlightController
local source=flight.Source;local at=assert(source:find("seq+=1;remote:FireServer",1,true))
flight.Source=source:sub(1,at-1).."if gui:GetAttribute('V6TestFlightInput') then return end;"..source:sub(at)

local server=Instance.new("Script");server.Name="FlightFixIntegration";server.Source=[====[local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local STS=game:GetService("StudioTestService")
local control=Instance.new("RemoteEvent");control.Name="V6TestControl";control.Parent=RS
local replies={};local ready;local failure;local ended=false;local metrics={}
control.OnServerEvent:Connect(function(p,kind,command,data)
 if kind=="Ready" then ready=p elseif kind=="Failure" then failure=tostring(command)..": "..tostring(data)
 elseif kind=="Result" then replies[command]=data end
end)
local function waitUntil(fn,seconds,message)
 local t=os.clock()+seconds
 repeat if failure then error(failure)end;if fn()then return end;task.wait(.05)until os.clock()>t
 error(message)
end
local function phase(p,cmd)
 replies[cmd]=nil;control:FireClient(p,cmd);waitUntil(function()return replies[cmd]~=nil end,20,cmd.." timed out")
end
local function finish(value)if ended then return end;ended=true;print("V6_SERVER_REPORT",game:GetService("HttpService"):JSONEncode(value));STS:EndTest(value)end
task.delay(110,function()finish({Ok=false,Error="Engine integration timeout"})end)
local ok,err=pcall(function()
 waitUntil(function()return ready end,60,"Client/UI did not become ready")
 local p=ready;local r=p.Character:WaitForChild("HumanoidRootPart",10)
 local helper=game.ServerScriptService.DragonServer:WaitForChild("StudioTest",10)
 assert(#workspace.DragonWorld.Monsters:GetChildren()==126,"Actual spawn count wrong")
 assert(#RS.DragonShared.BakedArt.PolishedModels:GetChildren()==62,"Baked model library incomplete")
 phase(p,"Mount");task.wait(.25);assert(p:GetAttribute("IsRiding") and r.Anchored,"Root not server-owned during flight")
 local start=r.Position.Y
 phase(p,"Up");task.wait(.85);local up=r.Position.Y;assert(up>start+25,"UP did not change actual server altitude")
 phase(p,"Down");task.wait(.55);local down=r.Position.Y;metrics.StartY=start;metrics.UpY=up;metrics.DownY=down;assert(down<up-15,"DOWN did not lower actual server altitude")
 metrics.StartY=start;metrics.UpY=up;metrics.DownY=down
 phase(p,"Forward");task.wait(.6);phase(p,"Reverse");task.wait(.6);
 phase(p,"Stop");task.wait(.25);local at=r.Position;task.wait(.4);assert((r.Position-at).Magnitude<1,"Hover drifts")
 phase(p,"InspectUI");metrics.Presentation=replies.InspectUI
 phase(p,"Down");task.wait(1.7);phase(p,"Dismount");assert(not p:GetAttribute("IsRiding") and not r.Anchored,"Cannot land and dismount")
 phase(p,"CheckCleanup")
 assert(helper:Invoke(p.UserId,"Merchant"));task.wait(.3);phase(p,"Shop")
 assert(helper:Invoke(p.UserId,"Target","slime_1"));task.wait(.3);phase(p,"Attack")
 metrics.ActualPurchase=true;metrics.ActualEquip=true;metrics.UnownedDenied=true;metrics.ActualKillReward=true;metrics.Tabs=6;metrics.Spawns=126
 metrics.Ok=true
end)
if not ok then finish({Ok=false,Error=tostring(err),Metrics=metrics})else finish(metrics)end
]====];server.Parent=game.ServerScriptService
local starter=game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts") or Instance.new("StarterPlayerScripts",game:GetService("StarterPlayer"))
local client=Instance.new("LocalScript");client.Name="FlightFixClient";client.Source=[====[local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local Run=game:GetService("RunService")
local player=Players.LocalPlayer;local control=RS:WaitForChild("V6TestControl",30)
local remotes=RS:WaitForChild("DragonRemotes",30);assert(control and remotes,"V6 remotes missing")
local responses={};local state
remotes.Update.OnClientEvent:Connect(function(p)if p.Id then responses[p.Id]=p end;if p.State then state=p.State end end)
local function exchange(action,key,quantity)
 local id=game:GetService("HttpService"):GenerateGUID(false)
 remotes.Request:FireServer({Id=id,Action=action,Key=key,Quantity=quantity})
 local untilTime=os.clock()+12;repeat task.wait(.05)until responses[id] or os.clock()>untilTime
 assert(responses[id],"No response for "..action);return responses[id]
end
local horizontal=0;local mode=0;local seq=100000;local active=false;local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if not active or elapsed<.1 then return end;elapsed=0;seq+=1
 remotes.FlightInput:FireServer({Seq=seq,X=horizontal,Y=mode,Z=0,Boost=horizontal~=0})
end)
local samples,seatError,dragonError,badSubject=0,0,0,0
Run:BindToRenderStep("FlightRegressionSample",Enum.RenderPriority.Camera.Value+2,function()
 local cf=require(RS.DragonShared.UI.RidePresentation).Get(player)
 local f=workspace:FindFirstChild("DragonRiderPresentation")
 local cosmetics=workspace:FindFirstChild("DragonCosmetics");local dragon=cosmetics and cosmetics:FindFirstChild("sky")
 if cf and f and dragon then
  samples+=1;seatError=math.max(seatError,(f.VisualRider.HumanoidRootPart.Position-cf.Position).Magnitude)
  dragonError=math.max(dragonError,(dragon.PrimaryPart.Position-(cf*CFrame.new(0,-7,0)).Position).Magnitude)
  if workspace.CurrentCamera.CameraSubject~=f.FlightCameraAnchor then badSubject+=1 end
 end
end)
control.OnClientEvent:Connect(function(command)
 task.spawn(function()
  local resultData={}
  local ok,err=pcall(function()
   if command=="Mount" then local r=exchange("Ride");assert(r.Ok,r.Code)
   elseif command=="Up" then active=true;mode=1
   elseif command=="Down" then active=true;mode=-1
   elseif command=="Forward" then active=true;mode=0;horizontal=1
   elseif command=="Reverse" then active=true;mode=0;horizontal=-1
   elseif command=="Stop" then active=true;mode=0;horizontal=0
   elseif command=="CheckCleanup" then
    task.wait(.15)
    assert(not workspace:FindFirstChild("DragonRiderPresentation"),"Rider proxy leaked after landing")
    assert(workspace.CurrentCamera.CameraSubject==player.Character:FindFirstChildOfClass("Humanoid"),"Camera not restored")
    assert(player.CameraMinZoomDistance==5,"Zoom not restored")
    assert(not require(RS.DragonShared.UI.RidePresentation).Get(player),"Stale presentation")
    for _,p in ipairs(player.Character:GetDescendants())do if p:IsA("BasePart") and p.Transparency==0 then assert(p.LocalTransparencyModifier==0,"Character left invisible")end end
   elseif command=="Dismount" then active=false;local r=exchange("Ride");assert(r.Ok,r.Code)
   elseif command=="Shop" then
    local r=exchange("Buy","sky_guard_sword_offer",1);assert(r.Ok and r.State.Coins==360,"Server purchase validation failed")
    r=exchange("Equip","sky_guard_sword");assert(r.Ok and r.State.Equipment.Weapon=="sky_guard_sword","Equip failed")
    r=exchange("Equip","void_sword");assert(not r.Ok and r.Code=="NOT_OWNED","Unowned equip accepted")
   elseif command=="Attack" then
    for _=1,8 do local r=exchange("Attack","slime_1");if r.Code=="LOOT" then break end;task.wait(.62)end
    local r=exchange("Sync");assert((r.State.Kills.slime or 0)==1 and r.State.Coins>360,"Actual kill was not rewarded once")
   elseif command=="InspectUI" then
    local gui=player.PlayerGui:WaitForChild("DragonUI",15)
    assert(gui:FindFirstChild("FlightDeck"),"Flight deck missing")
    assert(gui.FlightDeck:FindFirstChild("AscendButton") and gui.FlightDeck:FindFirstChild("DescendButton"),"Vertical controls missing")
    for _,name in ipairs({"Inventory","Sets","Monsters","Shop","Dragon","Map"})do assert(gui.MainMenu:FindFirstChild(name.."Button"),"Missing tab: "..name)end
    local cosmetics=workspace:WaitForChild("DragonCosmetics",10);local creature=workspace:WaitForChild("CreatureCosmetics",10)
    local baked=0;for _,folder in ipairs({cosmetics,creature})do for _,m in ipairs(folder:GetChildren())do if m:GetAttribute("ArtRenderer")=="BakedSculpture" then baked+=1 end end end
    assert(baked>=1,"Baked sculptures not displayed")
    local mapView=require(RS.DragonShared.UI.MapView)
    local mapFrame=Instance.new("Frame");mapFrame.Size=UDim2.fromOffset(600,400);mapFrame.Visible=false;mapFrame.Parent=gui
    local plot=mapView.DrawNative(mapFrame,"grassland");task.wait()
    local markers=0;for _,child in ipairs(plot:GetChildren())do if child.Name:sub(1,6)=="Spawn_"then markers+=1 end end
    assert(markers==14,"Actual map does not show distributed surface spawn points")
    mapView.SetWaypoint("grassland",3,"slime_1")
    local data=require(RS.DragonShared.WorldData);local source=data.Islands.grassland.Spawns[1]
    assert(mapView.Waypoint.Point.Position[1]==source.Position[1]and mapView.Waypoint.Point.Position[3]==source.Position[3],"Spawn waypoint is inaccurate")
    mapView.Waypoint=nil;mapFrame:Destroy()
    local preview=require(RS.DragonShared.UI.Preview)
    local previewSwitches=0
    for _,id in ipairs({"gale_wolf","sky_guard_armor"})do
     local isMonster=id=="gale_wolf"
     local inspector=preview.Inspect(gui,isMonster and id or "Armor",Color3.new(.6,.8,.9),isMonster,isMonster and nil or id,230)
     local body=inspector.Host.PreviewBody
     local view=assert(body:FindFirstChild("ActualModel"),"Default preview is not an actual model")
     assert(view.CurrentCamera and #view:GetChildren()>=2,"Missing model preview camera")
     local model=view:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
     assert(model:GetAttribute("AuthoredRevision")==9,"Detail preview uses old art")
     local prior=model:GetPivot();inspector.Rotate(25)
     assert(math.abs(prior.LookVector:Dot(model:GetPivot().LookVector))<.99,"Preview rotation is ineffective")
     inspector.Show("Art");task.wait(.1)
     assert(body:FindFirstChild("ApprovedArt") and not body:FindFirstChild("ActualModel"),"Design view did not replace native view")
     inspector.Show("Model");task.wait()
     assert(body:FindFirstChild("ActualModel") and not body:FindFirstChild("ApprovedArt"),"Native view did not return")
     assert(inspector.Host:FindFirstChild("TurnLeft") and inspector.Host.TurnLeft.Visible,"Rotation controls disappeared")
     inspector.Host:Destroy();previewSwitches+=2
    end
    local presentation=require(RS.DragonShared.UI.RidePresentation)
    local cf=assert(presentation.Get(player),"No common rider frame")
    local folder=assert(workspace:FindFirstChild("DragonRiderPresentation"),"Rider not rendered")
    assert(#folder:GetChildren()==2,"Duplicate rider copies")
    local camera=workspace.CurrentCamera
    assert(camera.CameraSubject==folder.FlightCameraAnchor,"Camera follows network steps")
    assert((folder.FlightCameraAnchor.Position-(cf*CFrame.new(0,1.5,0)).Position).Magnitude<.001,"Camera/rider split")
    assert((folder.VisualRider.HumanoidRootPart.Position-cf.Position).Magnitude<.001,"Rider body/dragon split")
    assert(player.Character.HumanoidRootPart.LocalTransparencyModifier==1,"Unsmooth body is still drawn")
    local dragon=assert(cosmetics:FindFirstChild("sky"),"Mounted dragon missing")
    assert((dragon.PrimaryPart.Position-(cf*CFrame.new(0,-7,0)).Position).Magnitude<.01,"Dragon/rider offset drift")
    assert(samples>20 and seatError<.002 and dragonError<.02 and badSubject==0,"Per-frame rider/camera/dragon diverged")
    resultData={BakedVisible=baked,UnifiedCamera=true,UnifiedRider=true,UnifiedDragon=true,Samples=samples,MaxSeatError=seatError,MaxDragonError=dragonError,BadCameraFrames=badSubject,SpawnMapMarkers=markers,PreviewSwitches=previewSwitches}
    return
   end
  end)
  control:FireServer(ok and "Result" or "Failure",command,ok and resultData or tostring(err))
 end)
end)
local function boot()
 for _=1,20 do local r=exchange("Sync");if r.State then state=r.State;break end;task.wait(.5)end
 assert(state and state.Coins==600 and state.Level==1,"Not a fresh Studio profile")
 local gui=player.PlayerGui:WaitForChild("DragonUI",20);assert(gui:WaitForChild("FlightDeck",20));gui:SetAttribute("V6TestFlightInput",true)
 task.wait(2);control:FireServer("Ready")
end
local ok,err=pcall(boot);if not ok then control:FireServer("Failure","Boot",tostring(err))end
]====];client.Parent=starter
local result=game:GetService("StudioTestService"):ExecutePlayModeAsync({Run="FlightFix"})
print("FLIGHT_FIX_TEST",game:GetService("HttpService"):JSONEncode(result));if result==nil then task.wait(120)end
