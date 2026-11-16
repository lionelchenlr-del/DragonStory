local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Evolution=require(script.Parent.Parent.DragonEvolution)
local Native=require(script.Parent.Parent.NativeModel)
local Motion=require(script.Parent.Parent.RideMotion)
local Presentation=require(script.Parent.RidePresentation)
local R={}
function R.Start()
 local stopPresentation=Presentation.Start()
 local world=workspace:WaitForChild("DragonWorld");local descriptors=world:WaitForChild("Companions")
 local folder=Instance.new("Folder");folder.Name="DragonCosmetics";folder.Parent=workspace
 local entries={}
 local function add(d)
  if d:IsA("Folder") then entries[d]={} end
 end
 local a=descriptors.ChildAdded:Connect(add)
 local b=descriptors.ChildRemoved:Connect(function(d)local e=entries[d];if e and e.Rig then e.Rig.Model:Destroy() end;entries[d]=nil end)
 for _,d in ipairs(descriptors:GetChildren()) do add(d) end
 RunService:BindToRenderStep("DragonCompanions",Enum.RenderPriority.Camera.Value-1,function(dt)
  for d,e in pairs(entries) do
   local owner=Players:GetPlayerByUserId(d:GetAttribute("OwnerUserId") or 0)
   local ch=owner and owner.Character;local r=ch and ch:FindFirstChild("HumanoidRootPart");local h=ch and ch:FindFirstChildOfClass("Humanoid")
   local index=d:GetAttribute("StageIndex");local stage=type(index)=="number" and Evolution.Stages[index]
   local mounted=owner and owner:GetAttribute("IsRiding")==true
   local mine=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
   local visible=r and h and h.Health>0 and stage and mine and (r.Position-mine.Position).Magnitude<1000
   if visible then
    local key=stage.Id..(mounted and "_mount" or "_follow")
    if key~=e.Key then
     if e.Rig then e.Rig.Model:Destroy() end
     e.Key=key;e.Rig=Native.Build(folder,stage.Id,{Scale=mounted and 1 or .58,Mesh=true});e.Position=nil;e.Motion=nil
    end
    local target,cf,pitch,bank
    if mounted then
     local rider,localPitch,localBank=Presentation.Get(owner)
     if rider then pitch=localPitch;bank=localBank
     else e.Motion=e.Motion or {};rider,pitch,bank=Motion.Step(e.Motion,r.CFrame,dt) end
     cf=rider*CFrame.new(0,-(3.6*stage.Scale+2.5),0)
    else
     e.Motion=nil;pitch=0;bank=0
     target=r.CFrame*CFrame.new(12+stage.Scale,3+math.sin(os.clock()*2)*.3,12+stage.Scale)
     cf=e.Position
     if not cf or (cf.Position-target.Position).Magnitude>80 then cf=target else cf=cf:Lerp(target,1-math.exp(-5*dt)) end
    end
    e.Position=cf;Native.Pose(e.Rig,cf*CFrame.Angles(pitch,0,bank),os.clock()*(mounted and 1.7 or 1),true)
    if e.Rig.Model.Parent~=folder then e.Rig.Model.Parent=folder end
   elseif e.Rig then e.Rig.Model.Parent=nil;e.Position=nil;e.Motion=nil end
  end
 end)
 return function()RunService:UnbindFromRenderStep("DragonCompanions");stopPresentation();a:Disconnect();b:Disconnect();for _,e in pairs(entries) do if e.Rig then e.Rig.Model:Destroy() end end;folder:Destroy()end
end
return R

