-- One presentation frame for the local rider, equipment, dragon and camera.
-- The real character remains at the server's validated position for gameplay.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Motion=require(script.Parent.Parent.RideMotion)
local P={}
local active,frame,motion,folder,proxy,anchor,character,parts,hidden
local oldSubject,oldMinZoom,camera
local binding="DragonRidePresentation"
function P.Get(player)
 if active and player==Players.LocalPlayer then return frame,motion.Pitch,motion.Bank end
end
local function stopRide()
 active=false;frame=nil
 if camera and camera.Parent and camera.CameraSubject==anchor then
  local ch=Players.LocalPlayer.Character
  camera.CameraSubject=ch and ch:FindFirstChildOfClass("Humanoid") or oldSubject
 end
 if oldMinZoom then Players.LocalPlayer.CameraMinZoomDistance=oldMinZoom end
 for original,value in pairs(hidden or {}) do if original.Parent then original.LocalTransparencyModifier=value end end
 if folder then folder:Destroy() end
 folder=nil;proxy=nil;anchor=nil;character=nil;parts=nil;hidden=nil;oldMinZoom=nil;camera=nil
end
local function cloneRider(ch)
 local archivable=ch.Archivable;ch.Archivable=true
 local ok,copy=pcall(function()return ch:Clone()end);ch.Archivable=archivable
 if not ok or not copy then return nil end
 parts={};hidden={}
 local function match(original,cloned)
  if original:IsA("BasePart") then parts[original]=cloned end
  local buckets={}
  for _,child in ipairs(cloned:GetChildren()) do
   local key=child.ClassName.."\0"..child.Name;buckets[key]=buckets[key] or {};table.insert(buckets[key],child)
  end
  for _,child in ipairs(original:GetChildren()) do
   local list=buckets[child.ClassName.."\0"..child.Name]
   if list and #list>0 then match(child,table.remove(list,1)) end
  end
 end
 match(ch,copy)
 for _,obj in ipairs(copy:GetDescendants()) do
  if obj:IsA("LuaSourceContainer") or obj:IsA("JointInstance") or obj:IsA("Constraint") or obj:IsA("Animator") or obj:IsA("Sound") or obj:IsA("Tool") then obj:Destroy()
  elseif obj:IsA("BasePart") then
   obj.Anchored=true;obj.CanCollide=false;obj.CanQuery=false;obj.CanTouch=false;obj.LocalTransparencyModifier=0
  elseif obj:IsA("Humanoid") then obj.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;obj.PlatformStand=true end
 end
 return copy
end
function P.Start()
 if P.Running then return function()end end
 P.Running=true
 local player=Players.LocalPlayer
 RunService:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value-2,function(dt)
  local ch=player.Character;local root=ch and ch:FindFirstChild("HumanoidRootPart");local h=ch and ch:FindFirstChildOfClass("Humanoid")
  if player:GetAttribute("IsRiding")~=true or not root or not h or h.Health<=0 then
   if active or folder then stopRide() end;return
  end
  if character~=ch then
   stopRide();proxy=cloneRider(ch);if not proxy then return end
   character=ch;folder=Instance.new("Folder");folder.Name="DragonRiderPresentation"
   anchor=Instance.new("Part");anchor.Name="FlightCameraAnchor";anchor.Size=Vector3.one*.1;anchor.Transparency=1
   anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Parent=folder
   proxy.Name="VisualRider";proxy.Parent=folder;folder.Parent=workspace
   motion={};oldMinZoom=player.CameraMinZoomDistance;player.CameraMinZoomDistance=math.max(oldMinZoom,20)
   active=true
  end
  frame=Motion.Step(motion,root.CFrame,dt)
  local offset=frame*root.CFrame:Inverse()
  for original,copy in pairs(parts) do
   if original.Parent and copy.Parent then
    copy.CFrame=offset*original.CFrame;copy.Transparency=original.Transparency
    if hidden[original]==nil then hidden[original]=original.LocalTransparencyModifier end
    original.LocalTransparencyModifier=1
   end
  end
  anchor.CFrame=frame*CFrame.new(0,1.5,0)
  local current=workspace.CurrentCamera
  if current~=camera then
   if camera and camera.Parent and camera.CameraSubject==anchor then camera.CameraSubject=oldSubject end
   camera=current;oldSubject=camera and camera.CameraSubject
  end
  if camera and camera.CameraType~=Enum.CameraType.Scriptable then camera.CameraSubject=anchor end
 end)
 return function()RunService:UnbindFromRenderStep(binding);stopRide();P.Running=false end
end
return P
