-- Pure authoritative traversal rules; there is no client position or destination field.
local Rules={}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
function Rules.ValidateInput(r)
 if type(r)~="table" then return false end
 local allowed={Seq=true,X=true,Y=true,Z=true,Boost=true};local count=0
 for k in pairs(r) do if not allowed[k] then return false end;count+=1 end
 return count==5 and finite(r.Seq) and r.Seq%1==0 and r.Seq>=0 and r.Seq<=1e9
  and finite(r.X) and finite(r.Y) and finite(r.Z) and math.abs(r.X)<=1 and math.abs(r.Y)<=1 and math.abs(r.Z)<=1
  and type(r.Boost)=="boolean"
end
function Rules.CanCross(from,to,mounted,level,islands)
 if not to or not islands[to] then return false,"NO_ISLAND" end
 if level<islands[to].MinLevel then return false,"ISLAND_LOCKED" end
 if from~=to and not mounted then return false,"RIDE_REQUIRED" end
 return true,"OK"
end
function Rules.Step(position,input,speed,dt)
 dt=math.clamp(dt,0,.1)
 local x,y,z=input.X,input.Y,input.Z;local length=math.sqrt(x*x+y*y+z*z)
 if length>1 then x/=length;y/=length;z/=length end
 return {position[1]+x*speed*dt,math.clamp(position[2]+y*speed*dt,-180,2600),position[3]+z*speed*dt}
end
-- Interpolate yaw, not direction vectors: opposite vectors otherwise collapse to zero.
function Rules.Turn(x,z,tx,tz,dt)
 local yaw=math.atan2(-x,-z);local target=math.atan2(-tx,-tz)
 local delta=(target-yaw+math.pi)%(2*math.pi)-math.pi
 yaw+=delta*(1-math.exp(-6*math.clamp(dt,0,.1)))
 return -math.sin(yaw),-math.cos(yaw)
end
function Rules.GroundStepOK(previous,current,speed,dt)
 if not previous then return true end
 local dx,dz=current[1]-previous[1],current[3]-previous[3]
 return dx*dx+dz*dz <= (speed*math.clamp(dt,0,1)+34)^2
end
return Rules

