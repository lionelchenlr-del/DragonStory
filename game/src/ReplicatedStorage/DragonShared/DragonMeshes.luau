-- Cached, client-side continuous meshes; gameplay never depends on these APIs.
local AssetService=game:GetService("AssetService")
local G=require(script.Parent:WaitForChild("Geometry"))
local Recipe=require(script.Parent:WaitForChild("DragonMeshRecipe"))
local M={Cache={}}
function M.Prune(keep)
	for key,entry in pairs(M.Cache) do
		if key~=keep and not entry.Loading and (entry.References or 0)==0 then
			for _,part in ipairs(entry.Parts or {}) do part.Template:Destroy() end
			for _,editable in ipairs(entry.Editables) do editable:Destroy() end
			M.Cache[key]=nil
		end
	end
end
function M.Retain(key) local e=M.Cache[key];if e then e.References=(e.References or 0)+1 end end
function M.Release(key) local e=M.Cache[key];if e then e.References=math.max(0,(e.References or 0)-1) end;M.Prune() end
function M.Get(stage,customRecipe)
	local entry=M.Cache[stage.Id]
	if entry then
		while entry.Loading do task.wait() end
		return entry.Parts
	end
	entry={Loading=true,Parts={},Editables={}}
	M.Prune(stage.Id)
	M.Cache[stage.Id]=entry
	local ok,reason=pcall(function()
		local combined={}
		for _,data in ipairs(customRecipe and customRecipe() or Recipe.Build(stage,G)) do
			local key=data.Group..(data.Glow and "_Glow" or "")
			if not combined[key] then combined[key]={Name=key,Group=data.Group,Vertices={},Faces={},Glow=data.Glow} end
			local dest=combined[key];local offset=#dest.Vertices
			for _,v in ipairs(data.Vertices) do table.insert(dest.Vertices,v) end
			for _,f in ipairs(data.Faces) do table.insert(dest.Faces,{f[1]+offset,f[2]+offset,f[3]+offset,f[4]}) end
		end
		local chunks={}
		for _,data in pairs(combined) do for _,chunk in ipairs(G.Split(data,8000)) do table.insert(chunks,chunk) end end
		for _,data in ipairs(chunks) do
			local editable=AssetService:CreateEditableMesh()
			assert(editable,"mesh memory budget")
			table.insert(entry.Editables,editable)
			local low,high={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
			for _,v in ipairs(data.Vertices) do for i=1,3 do low[i]=math.min(low[i],v[i]);high[i]=math.max(high[i],v[i]) end end
			local center=G.Mul(G.Add(low,high),.5)
			local ids,normals,normalIds,colors={},{},{},{}
			for i,v in ipairs(data.Vertices) do
				ids[i]=editable:AddVertex(Vector3.new(table.unpack(G.Sub(v,center))))
				normals[i]={0,0,0}
			end
			for _,f in ipairs(data.Faces) do
				local n=G.Cross(G.Sub(data.Vertices[f[2]],data.Vertices[f[1]]),G.Sub(data.Vertices[f[3]],data.Vertices[f[1]]))
				for i=1,3 do normals[f[i]]=G.Add(normals[f[i]],n) end
			end
			for i,n in ipairs(normals) do normalIds[i]=editable:AddNormal(Vector3.new(table.unpack(G.Unit(n)))) end
			for _,f in ipairs(data.Faces) do
				local color=f[4]
				if not colors[color] then colors[color]=editable:AddColor(Color3.fromHex(color),1) end
				local face=editable:AddTriangle(ids[f[1]],ids[f[2]],ids[f[3]])
				editable:SetFaceColors(face,{colors[color],colors[color],colors[color]})
				editable:SetFaceNormals(face,{normalIds[f[1]],normalIds[f[2]],normalIds[f[3]]})
			end
			local p=AssetService:CreateMeshPartAsync(Content.fromObject(editable),{CollisionFidelity=Enum.CollisionFidelity.Box})
			p.Name,p.Color,p.DoubleSided=data.Name,Color3.new(1,1,1),true
			p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch=true,false,false,false
			p.Material=data.Glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.CastShadow=not data.Glow
			table.insert(entry.Parts,{Template=p,Center=CFrame.new(table.unpack(center)),Group=data.Group})
		end
	end)
	if not ok then
		for _,p in ipairs(entry.Parts) do p.Template:Destroy() end
		for _,mesh in ipairs(entry.Editables) do mesh:Destroy() end
		entry.Parts=nil;entry.Editables={}
		warn("[Dragon Art]",stage.Id,"mesh artwork unavailable; compatible models remain active:",reason)
	end
	entry.Loading=false
	return entry.Parts
end
return M
