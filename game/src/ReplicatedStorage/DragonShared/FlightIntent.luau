-- Pure, testable intent. All actual movement and island access remain server-authoritative.
local I={}
function I.Resolve(buttons,enabled)
 if not enabled then return {X=0,Y=0,Z=0,Boost=false} end
 local x=(buttons.Right and 1 or 0)-(buttons.Left and 1 or 0)
 local z=(buttons.Forward and 1 or 0)-(buttons.Backward and 1 or 0)
 local length=math.sqrt(x*x+z*z);if length>1 then x/=length;z/=length end
 return {X=x,Y=(buttons.Up and 1 or 0)-(buttons.Down and 1 or 0),Z=z,Boost=buttons.Boost==true}
end
return I
