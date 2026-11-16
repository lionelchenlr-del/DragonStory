-- Render-only spring. Never writes to the authoritative character or sends positions.
local Motion={}
function Motion.Step(state,target,dt)
 dt=math.clamp(dt,0,.1)
 if not state.CFrame or (state.CFrame.Position-target.Position).Magnitude>80 then
  state.CFrame=target;state.Velocity=Vector3.zero;state.Pitch=0;state.Bank=0
  return target,0,0
 end
 local previous=state.CFrame
 local omega=20
 local decay=math.exp(-omega*dt)
 local offset=previous.Position-target.Position
 local temp=(state.Velocity+offset*omega)*dt
 local position=target.Position+(offset+temp)*decay
 state.Velocity=(state.Velocity-temp*omega)*decay
 local rotation=previous.Rotation:Lerp(target.Rotation,1-math.exp(-12*dt))
 local cf=CFrame.new(position)*rotation
 local angle=math.atan2(previous.LookVector:Cross(cf.LookVector).Y,previous.LookVector:Dot(cf.LookVector))
 local alpha=1-math.exp(-7*dt)
 state.Pitch+=(math.clamp(state.Velocity.Y*.004,-.18,.18)-state.Pitch)*alpha
 state.Bank+=(math.clamp(-angle/math.max(dt,.001)*.13,-.2,.2)-state.Bank)*alpha
 state.CFrame=cf
 return cf,state.Pitch,state.Bank
end
return Motion
