-- Pure mesh authoring: reusable by the game, offline validation and OBJ export.
local G = {}
function G.Add(a,b) return {a[1]+b[1],a[2]+b[2],a[3]+b[3]} end
function G.Sub(a,b) return {a[1]-b[1],a[2]-b[2],a[3]-b[3]} end
function G.Mul(a,k) return {a[1]*k,a[2]*k,a[3]*k} end
function G.Dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function G.Cross(a,b) return {a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]} end
function G.Unit(a)
	local n=math.sqrt(G.Dot(a,a))
	return n>1e-9 and G.Mul(a,1/n) or {0,1,0}
end
function G.Split(data,limit)
	limit=limit or 8000
	local result={}
	local chunk,remap=nil,nil
	for _,face in ipairs(data.Faces) do
		if not chunk or #chunk.Faces>=limit then
			chunk={Name=data.Name.."_"..(#result+1),Group=data.Group,Glow=data.Glow,Vertices={},Faces={}}
			remap={};table.insert(result,chunk)
		end
		local copy={face[1],face[2],face[3],face[4]}
		for i=1,3 do
			local original=face[i]
			if not remap[original] then table.insert(chunk.Vertices,data.Vertices[original]);remap[original]=#chunk.Vertices end
			copy[i]=remap[original]
		end
		table.insert(chunk.Faces,copy)
	end
	return result
end
function G.New(scale)
	local B={Groups={},Scale=scale or 1}
	function B.Group(name,glow)
		local key=name..(glow and "Glow" or "")
		if not B.Groups[key] then B.Groups[key]={Name=key,Group=name,Glow=glow or false,Vertices={},Faces={}} end
		return B.Groups[key]
	end
	function B.Vertex(m,v)
		table.insert(m.Vertices,G.Mul(v,B.Scale));return #m.Vertices
	end
	function B.Face(m,a,b,c,color) table.insert(m.Faces,{a,b,c,color}) end
	function B.Triangle(name,a,b,c,color,glow)
		local m=B.Group(name,glow)
		B.Face(m,B.Vertex(m,a),B.Vertex(m,b),B.Vertex(m,c),color)
	end
	function B.Tube(name,path,color,sides,glow)
		sides=sides or 10
		local m=B.Group(name,glow)
		local rings={}
		local previousRight=nil
		for i,p in ipairs(path) do
			local tangent=G.Unit(G.Sub(path[math.min(#path,i+1)],path[math.max(1,i-1)]))
			local reference=math.abs(tangent[2])>0.92 and {1,0,0} or {0,1,0}
			local right=G.Unit(G.Cross(reference,tangent))
			if previousRight then
				local projected=G.Sub(previousRight,G.Mul(tangent,G.Dot(previousRight,tangent)))
				if G.Dot(projected,projected)>1e-6 then right=G.Unit(projected) end
			end
			previousRight=right
			local up=G.Cross(tangent,right)
			local ring={}
			for j=0,sides-1 do
				local angle=j*math.pi*2/sides
				local offset=G.Add(G.Mul(right,math.cos(angle)*p[4]),G.Mul(up,math.sin(angle)*(p[5] or p[4])))
				table.insert(ring,B.Vertex(m,G.Add(p,offset)))
			end
			table.insert(rings,ring)
		end
		for i=1,#rings-1 do
			for j=1,sides do
				local k=j%sides+1
				local a,b,c,d=rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]
				B.Face(m,a,b,c,color);B.Face(m,a,c,d,color)
			end
		end
		local first,last=B.Vertex(m,path[1]),B.Vertex(m,path[#path])
		for j=1,sides do
			local k=j%sides+1
			B.Face(m,first,rings[1][k],rings[1][j],color)
			B.Face(m,last,rings[#rings][j],rings[#rings][k],color)
		end
	end
	function B.Ellipsoid(name,position,size,color,sides,rings,glow)
		sides,rings=sides or 12,rings or 8
		local m=B.Group(name,glow)
		local rows={}
		for i=1,rings-1 do
			local row={};local phi=i*math.pi/rings
			for j=0,sides-1 do
				local theta=j*math.pi*2/sides
				table.insert(row,B.Vertex(m,G.Add(position,{math.sin(phi)*math.cos(theta)*size[1]/2,math.cos(phi)*size[2]/2,math.sin(phi)*math.sin(theta)*size[3]/2})))
			end
			table.insert(rows,row)
		end
		for i=1,#rows-1 do
			for j=1,sides do
				local k=j%sides+1
				B.Face(m,rows[i][j],rows[i][k],rows[i+1][k],color)
				B.Face(m,rows[i][j],rows[i+1][k],rows[i+1][j],color)
			end
		end
		local top=B.Vertex(m,G.Add(position,{0,size[2]/2,0}))
		local bottom=B.Vertex(m,G.Add(position,{0,-size[2]/2,0}))
		for j=1,sides do
			local k=j%sides+1
			B.Face(m,top,rows[1][k],rows[1][j],color)
			B.Face(m,bottom,rows[#rows][j],rows[#rows][k],color)
		end
	end
	function B.Crystal(name,center,size,color,glow)
		local m=B.Group(name,glow)
		local ids={}
		for _,v in ipairs({{0,size[2]/2,0},{0,-size[2]/2,0},{size[1]/2,0,0},{0,0,size[3]/2},{-size[1]/2,0,0},{0,0,-size[3]/2}}) do
			table.insert(ids,B.Vertex(m,G.Add(center,v)))
		end
		for i=3,6 do
			local k=i==6 and 3 or i+1
			B.Face(m,ids[1],ids[k],ids[i],color);B.Face(m,ids[2],ids[i],ids[k],color)
		end
	end
	function B.Result()
		local out={}
		for _,m in pairs(B.Groups) do table.insert(out,m) end
		table.sort(out,function(a,b)return a.Name<b.Name end)
		return out
	end
	return B
end
return G
