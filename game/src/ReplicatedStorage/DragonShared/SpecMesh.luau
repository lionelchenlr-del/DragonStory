local G=script and require(script.Parent.Geometry) or require("./Geometry")
local DragonRecipe=script and require(script.Parent.DragonMeshRecipe) or require("./DragonMeshRecipe")
local S={}
local function transform(v,p,scale)
 local out
 if p.Basis then
  local a=p.Basis
  out={a[1][1]*v[1]+a[2][1]*v[2]+a[3][1]*v[3],a[1][2]*v[1]+a[2][2]*v[2]+a[3][2]*v[3],a[1][3]*v[1]+a[2][3]*v[2]+a[3][3]*v[3]}
 else
  local r=p.Rotation;local x,y,z=math.rad(r[1]),math.rad(r[2]),math.rad(r[3])
  local ax,ay=v[1]*math.cos(z)-v[2]*math.sin(z),v[1]*math.sin(z)+v[2]*math.cos(z)
  local bx,bz=ax*math.cos(y)+v[3]*math.sin(y),-ax*math.sin(y)+v[3]*math.cos(y)
  out={bx,ay*math.cos(x)-bz*math.sin(x),ay*math.sin(x)+bz*math.cos(x)}
 end
 return {(out[1]+p.Position[1])*scale,(out[2]+p.Position[2])*scale,(out[3]+p.Position[3])*scale}
end
function S.Build(record,scale)
 scale=scale or 1;local groups={}
 if record.Kind=="Dragon" and record.Stage and record.DesignRevision~=6 and record.DesignRevision~=7 and record.DesignRevision~=8 and record.DesignRevision~=9 then
  local out=DragonRecipe.Build(record.Stage,G)
  for _,group in ipairs(out) do for _,v in ipairs(group.Vertices) do v[1]*=scale;v[2]=(v[2]+2.3*record.Stage.Scale)*scale;v[3]*=scale end end
  local saddle={Parts={}}
  for _,p in ipairs(record.Parts) do if p.Name=="DragonSaddle" or p.Name=="SaddleRail" then table.insert(saddle.Parts,p) end end
  for _,group in ipairs(S.Build(saddle,scale)) do table.insert(out,group) end
  return out
 end
 for _,p in ipairs(record.Parts) do
  local g=G.New();local size=p.Size
  if p.Shape=="Ball" then g.Ellipsoid("Body",{0,0,0},size,p.Color,24,14,p.Neon)
  else
   local vertices,faces
   if p.Shape=="Crystal" then
    vertices={{0,.5,0},{0,-.5,0},{-.5,0,-.5},{.5,0,-.5},{.5,0,.5},{-.5,0,.5}}
    faces={{1,4,3},{1,5,4},{1,6,5},{1,3,6},{2,3,4},{2,4,5},{2,5,6},{2,6,3}}
   elseif p.Shape=="Wedge" then
    vertices={{-.5,-.5,-.5},{.5,-.5,-.5},{-.5,-.5,.5},{.5,-.5,.5},{-.5,.5,.5},{.5,.5,.5}}
    faces={{1,2,4},{1,4,3},{3,4,6},{3,6,5},{1,5,6},{1,6,2},{1,3,5},{2,6,4}}
   else
    vertices={{-.5,-.5,-.5},{.5,-.5,-.5},{.5,.5,-.5},{-.5,.5,-.5},{-.5,-.5,.5},{.5,-.5,.5},{.5,.5,.5},{-.5,.5,.5}}
    faces={{1,3,2},{1,4,3},{5,6,7},{5,7,8},{1,2,6},{1,6,5},{4,8,7},{4,7,3},{1,5,8},{1,8,4},{2,3,7},{2,7,6}}
   end
   local data=g.Group("Body",p.Neon)
   for _,v in ipairs(vertices) do g.Vertex(data,{v[1]*size[1],v[2]*size[2],v[3]*size[3]}) end
   for _,f in ipairs(faces) do g.Face(data,f[1],f[2],f[3],p.Color) end
  end
  for _,data in ipairs(g.Result()) do
   local group=p.Group or "Body";local key=group..(p.Neon and "_Glow" or "")
   if not groups[key] then groups[key]={Name=key,Group=group,Glow=p.Neon,Vertices={},Faces={}} end
   local dest=groups[key];local offset=#dest.Vertices
   for _,v in ipairs(data.Vertices) do table.insert(dest.Vertices,transform(v,p,scale)) end
   for _,f in ipairs(data.Faces) do table.insert(dest.Faces,{f[1]+offset,f[2]+offset,f[3]+offset,f[4]}) end
  end
 end
 local out={};for _,group in pairs(groups) do table.insert(out,group) end;return out
end
return S

