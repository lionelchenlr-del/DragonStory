local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local Run=game:GetService("RunService")
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
    resultData={BakedVisible=baked,UnifiedCamera=true,UnifiedRider=true,UnifiedDragon=true,Samples=samples,MaxSeatError=seatError,MaxDragonError=dragonError,BadCameraFrames=badSubject,SpawnMapMarkers=markers}
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
