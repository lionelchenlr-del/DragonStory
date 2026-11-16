-- Authoritative, planar steering. The client never supplies targets or positions.
local Motion={}
function Motion.Distance(a,b)
 local x,z=a.X-b.X,a.Z-b.Z;return math.sqrt(x*x+z*z)
end
function Motion.ClampHome(position,home,leash)
 local delta=Vector3.new(position.X-home.X,0,position.Z-home.Z)
 if delta.Magnitude>leash then delta=delta.Unit*leash end
 return Vector3.new(home.X+delta.X,position.Y,home.Z+delta.Z)
end
function Motion.Patrol(home,time,phase,radius)
 return home+Vector3.new(math.sin(time*.19+phase)*radius,0,math.sin(time*.13+phase*1.7)*radius*.72)
end
function Motion.Advance(position,target,speed,dt)
 local delta=Vector3.new(target.X-position.X,0,target.Z-position.Z)
 if delta.Magnitude<.05 then return position end
 return position+delta.Unit*math.min(delta.Magnitude,speed*math.clamp(dt,0,.25))
end
function Motion.Separate(candidate,id,neighbors,minimum,maxPush)
 local correction=Vector3.zero
 for _,other in ipairs(neighbors) do
  if other.Id~=id and not other.Dead then
   local pos=other.Root.Position
   local delta=Vector3.new(candidate.X-pos.X,0,candidate.Z-pos.Z)
   local distance=delta.Magnitude;local spacing=math.max(minimum,other.Separation or minimum)
   if distance<spacing then
    local direction=distance>.001 and delta.Unit or Vector3.new(id<other.Id and -1 or 1,0,0)
    correction+=direction*(spacing-distance)
   end
  end
 end
 if correction.Magnitude>maxPush then correction=correction.Unit*maxPush end
 return candidate+correction
end
return Motion
