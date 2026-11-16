-- Uses real Vector3/CFrame in Studio; snapshots deliberately arrive at 12–25 Hz.
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
