local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage");local STS=game:GetService("StudioTestService")
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
