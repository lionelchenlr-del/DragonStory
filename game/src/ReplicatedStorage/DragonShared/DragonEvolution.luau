local E={Stages={{["Glow"]="81F2EC",["Spikes"]=2,["Id"]="sky",["Horns"]=0,["Wing"]=1,["Name"]="晴空幼龍",["Scale"]=1.25,["MinLevel"]=1,["Color"]="59B8C7",["Accent"]="D1ECED",["Gold"]="C8B889"},{["Glow"]="74D6F2",["Spikes"]=4,["Id"]="gale",["Horns"]=2,["Wing"]=2,["Name"]="蒼嵐戰龍",["Scale"]=1.65,["MinLevel"]=151,["Color"]="203C67",["Accent"]="C3CEDC",["Gold"]="D5C399"},{["Glow"]="78EDD0",["Spikes"]=6,["Id"]="solar",["Horns"]=4,["Wing"]=3,["Name"]="曜金聖龍",["Scale"]=2,["MinLevel"]=351,["Color"]="7E602E",["Accent"]="E2D4B2",["Gold"]="DDBE7A"},{["Glow"]="BC83FA",["Spikes"]=8,["Id"]="astral",["Horns"]=6,["Wing"]=3,["Name"]="星穹龍皇",["Halo"]=true,["Scale"]=2.35,["MinLevel"]=651,["Color"]="322D4B",["Accent"]="BFBAD0",["Gold"]="D9B879"}}}
function E.Resolve(level)
 if type(level)~="number" or level~=level or level==math.huge or level==-math.huge then level=1 end
 local index=1
 for i,s in ipairs(E.Stages) do if level>=s.MinLevel then index=i end end
 return E.Stages[index],index
end
function E.Progress(level)
 local s,i=E.Resolve(level);local n=E.Stages[i+1]
 if not n then return {Stage=i,Fraction=1,Remaining=0} end
 local v=type(level)=="number" and level==level and level>-math.huge and level<math.huge and level or 1
 return {Stage=i,Fraction=math.clamp((v-s.MinLevel)/(n.MinLevel-s.MinLevel),0,1),NextLevel=n.MinLevel,Remaining=math.max(0,n.MinLevel-math.floor(v))}
end
return E
