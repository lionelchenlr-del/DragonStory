local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local U=require(script.Parent.Components)
local Intent=require(script.Parent.Parent.FlightIntent)
local F={}
function F.Start(gui,send,notify,hidePanel)
 local player=Players.LocalPlayer
 local remote=RS:WaitForChild("DragonRemotes"):WaitForChild("FlightInput")
 local connections,objects,held,heldInputs={},{},{},{}
 local seq,elapsed=0,0;local boostToggle=false;local focused=true
 local camera,baseFov=workspace.CurrentCamera,workspace.CurrentCamera.FieldOfView
 local function own(o)table.insert(objects,o);return o end
 local function connect(signal,fn)table.insert(connections,signal:Connect(fn))end
 local function hold(button,key)
  connect(button.InputBegan,function(input)
   if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then heldInputs[key]=input;held[key]=true end
  end)
 end
 local ride=own(U.Button(gui,"騎龍  [F]",function()send("Ride")end,{Name="RideButton",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-104),Size=UDim2.fromOffset(194,40),TextColor3=U.Colors.Gold,BackgroundColor3=Color3.fromHex("3D315B")}))
 local pilot=own(U.Frame(gui,"FlightDeck",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-154),Size=UDim2.fromOffset(194,164),BackgroundColor3=Color3.fromHex("122B3E"),BackgroundTransparency=.06,Visible=false}))
 U.Round(pilot,14);U.Stroke(pilot,Color3.fromHex("78D7DF"),.25);U.Gradient(pilot,Color3.fromHex("244858"),Color3.fromHex("101D34"),70)
 local altitude=U.Label(pilot,"飛行高度",{Position=UDim2.fromOffset(10,7),Size=UDim2.new(1,-20,0,22),TextSize=13,TextColor3=U.Colors.Gold,TextXAlignment=Enum.TextXAlignment.Center})
 local status=U.Label(pilot,"平飛／懸停",{Position=UDim2.fromOffset(10,29),Size=UDim2.new(1,-20,0,18),TextSize=11,TextColor3=Color3.fromHex("A8E4E9"),TextXAlignment=Enum.TextXAlignment.Center})
 local ascend=U.Button(pilot,"↑ 上升\n按住／空白鍵",function()end,{Name="AscendButton",Position=UDim2.fromOffset(9,53),Size=UDim2.fromOffset(84,54),TextSize=13,BackgroundColor3=Color3.fromHex("27606B"),TextColor3=Color3.fromHex("D7FFFF")})
 local descend=U.Button(pilot,"↓ 下降\n按住／Q",function()end,{Name="DescendButton",Position=UDim2.fromOffset(101,53),Size=UDim2.fromOffset(84,54),TextSize=13,BackgroundColor3=Color3.fromHex("49416F"),TextColor3=Color3.fromHex("E9E1FF")})
 hold(ascend,"Up");hold(descend,"Down")
 local boost=U.Button(pilot,"加速：關  ·  Shift",function()boostToggle=not boostToggle end,{Name="BoostButton",Position=UDim2.fromOffset(9,116),Size=UDim2.new(1,-18,0,36),TextSize=12,TextColor3=U.Colors.Gold,BackgroundColor3=Color3.fromHex("3E3A46")})
 local arrows={}
 for _,d in ipairs({{"Forward","↑",58,-250},{"Backward","↓",58,-154},{"Left","←",10,-202},{"Right","→",106,-202}}) do
  local b=own(U.Button(gui,d[2],function()end,{Name="Flight_"..d[1],AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,d[3],1,d[4]),Size=UDim2.fromOffset(44,42),Visible=false,TextColor3=Color3.fromHex("BFECEF")}))
  hold(b,d[1]);arrows[#arrows+1]=b
 end
 local help=own(U.Label(gui,"F 騎龍 · E 攻擊 · R 互動 · M 地圖",{Name="TravelHelp",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-152),Size=UDim2.new(.7,0,0,24),TextSize=11,TextColor3=U.Colors.Gold,TextXAlignment=Enum.TextXAlignment.Center}))
 local function clear()table.clear(held);table.clear(heldInputs);boostToggle=false end
 local function refresh()
  local riding=player:GetAttribute("IsRiding")==true
  ride.Text=riding and "降落下龍  [F]" or "騎龍  [F]"
  pilot.Visible=riding
  for _,b in ipairs(arrows)do b.Visible=riding and UIS.TouchEnabled end
  help.Text=riding and "WASD 移動 · 空白鍵↑ · Q↓ · 靠近地面按F下龍" or "F 騎龍 · E 攻擊 · R 互動 · M 地圖"
  if not riding then clear() else hidePanel();notify("龍已起飛！按住空白鍵／上升按鈕向上，按住Q／下降按鈕向下。") end
 end
 connect(player:GetAttributeChangedSignal("IsRiding"),refresh)
 connect(UIS.InputEnded,function(input)for key,value in pairs(heldInputs)do if value==input then heldInputs[key]=nil;held[key]=nil end end end)
 connect(UIS.WindowFocusReleased,function()focused=false;clear()end)
 connect(UIS.WindowFocused,function()focused=true end)
 connect(UIS.InputBegan,function(input,processed)
  if not processed and (input.KeyCode==Enum.KeyCode.F or input.KeyCode==Enum.KeyCode.ButtonB)then send("Ride")end
 end)
 local function gamepad(key)return UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1,key)end
 connect(RunService.RenderStepped,function(dt)
  local riding=player:GetAttribute("IsRiding")==true
  local panel=gui:FindFirstChild("MainPanel");local menu=panel and panel.Visible
  pilot.Visible=riding and not menu
  help.Visible=not menu and gui.AbsoluteSize.X>700
  for _,b in ipairs(arrows)do b.Visible=riding and UIS.TouchEnabled and not menu end
  local intent=Intent.Resolve({
   Right=held.Right or UIS:IsKeyDown(Enum.KeyCode.D),Left=held.Left or UIS:IsKeyDown(Enum.KeyCode.A),
   Forward=held.Forward or UIS:IsKeyDown(Enum.KeyCode.W),Backward=held.Backward or UIS:IsKeyDown(Enum.KeyCode.S),
   Up=held.Up or UIS:IsKeyDown(Enum.KeyCode.Space) or gamepad(Enum.KeyCode.ButtonR1),
   Down=held.Down or UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) or gamepad(Enum.KeyCode.ButtonL1),
   Boost=boostToggle or UIS:IsKeyDown(Enum.KeyCode.LeftShift) or gamepad(Enum.KeyCode.ButtonR2),
  },riding and focused and not menu and not UIS:GetFocusedTextBox())
  if workspace.CurrentCamera~=camera then camera=workspace.CurrentCamera;baseFov=camera.FieldOfView end
  camera.FieldOfView+=(baseFov+(riding and 4 or 0)+(riding and intent.Boost and 8 or 0)-camera.FieldOfView)*(1-math.exp(-5*dt))
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and riding then altitude.Text="飛行高度  "..math.floor(root.Position.Y).." 格" end
  status.Text=intent.Y>0 and "↑ 上升中" or intent.Y<0 and "↓ 下降中" or "平飛／懸停"
  status.TextColor3=intent.Y<0 and Color3.fromHex("C9B9F9") or Color3.fromHex("A8F3E8")
  ascend.BackgroundColor3=intent.Y>0 and Color3.fromHex("328996") or Color3.fromHex("27606B")
  descend.BackgroundColor3=intent.Y<0 and Color3.fromHex("6D5998") or Color3.fromHex("49416F")
  boost.Text=intent.Boost and "加速：開  ·  Shift" or "加速：關  ·  Shift"
  elapsed+=dt;if not riding or elapsed<.1 then return end;elapsed=0
  local forward=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
  forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
  local move=forward*intent.Z+forward:Cross(Vector3.yAxis)*intent.X
  if move.Magnitude<.01 and focused and not menu and not UIS:GetFocusedTextBox() then
   local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if h then move=h.MoveDirection end
  end
  if move.Magnitude>1 then move=move.Unit end
  seq+=1;remote:FireServer({Seq=seq,X=move.X,Y=intent.Y,Z=move.Z,Boost=intent.Boost})
 end)
 refresh()
 return function()for _,c in ipairs(connections)do c:Disconnect()end;for _,o in ipairs(objects)do o:Destroy()end;if camera then camera.FieldOfView=baseFov end end
end
return F
