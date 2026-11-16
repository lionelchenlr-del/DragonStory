local R={}
function R.Build(G,DragonRecipe)
	local B=G.New(1)
	local ivory,gold,jade,roof="F1E7D3","E9C87B","54D5BA","202D55"
	local function ring(radius,y,color,thickness)
		local path={}
		for i=0,64 do local a=i*math.pi/32;table.insert(path,{math.cos(a)*radius,y,math.sin(a)*radius,thickness or .05}) end
		B.Tube("Body",path,color,6,color==jade)
	end
	B.Tube("Body",{{0,-.15,0,13},{0,.18,0,13},{0,.4,0,12.6}},ivory,64)
	ring(12.8,.32,gold,.12);ring(11.2,.42,gold,.035);ring(7,.43,jade,.045);ring(6.2,.43,jade,.025)
	for i=1,16 do
		local a=i*math.pi/8
		B.Crystal("Body",{math.cos(a)*6.6,.47,math.sin(a)*6.6},{.2,.08,.42},jade,true)
	end
	for i=0,5 do
		local a=i*math.pi/3
		local x,z=math.cos(a)*9.8,math.sin(a)*6.4
		B.Tube("Body",{{x,.35,z,.85},{x,.65,z,.85},{x,.8,z,.5},{x,9,z,.45},{x,9.3,z,.85},{x,9.7,z,.85}},ivory,12)
		for _,y in ipairs({.7,1.0,8.85,9.35}) do
			B.Tube("Body",{{x,y,z,.64},{x,y+.13,z,.64}},gold,12)
		end
		local spiral={}
		for j=0,45 do
			local theta=j*math.pi/10
			table.insert(spiral,{x+math.cos(theta)*.5,1+j/45*7.5,z+math.sin(theta)*.5,.035})
		end
		B.Tube("Body",spiral,gold,5)
		B.Crystal("Body",{x,8.5,z+.7},{.5,1.15,.5},jade,true)
	end
	local fractions={.08,.28,.55,.85,1}
	local heights={14,12,10.4,10.2,11.2}
	local m=B.Group("Body")
	local rows={}
	for j,r in ipairs(fractions) do
		local row={}
		for i=0,47 do
			local a=i*math.pi/24
			local flare=1+.11*math.cos(a*3)
			table.insert(row,B.Vertex(m,{math.cos(a)*15*r*flare,heights[j]+(j==5 and math.cos(a*2)*.9 or 0),math.sin(a)*10*r*flare}))
		end
		table.insert(rows,row)
	end
	for j=1,#rows-1 do
		for i=1,48 do
			local k=i%48+1
			B.Face(m,rows[j][i],rows[j+1][k],rows[j+1][i],roof)
			B.Face(m,rows[j][i],rows[j][k],rows[j+1][k],roof)
		end
	end
	for i=0,11 do
		local a=i*math.pi/6
		local path={}
		for j,r in ipairs(fractions) do
			local flare=1+.11*math.cos(a*3)
			table.insert(path,{math.cos(a)*15*r*flare,heights[j]+.06+(j==5 and math.cos(a*2)*.9 or 0),math.sin(a)*10*r*flare,.065})
		end
		B.Tube("Body",path,gold,6)
	end
	local eave={}
	for i=0,96 do
		local a=i*math.pi/48;local f=1+.11*math.cos(a*3)
		table.insert(eave,{math.cos(a)*15*f,11.2+math.cos(a*2)*.9,math.sin(a)*10*f,.08})
	end
	B.Tube("Body",eave,gold,6)
	B.Crystal("Body",{0,14.7,0},{1.4,3,1.4},jade,true)
	for _,side in ipairs({-1,1}) do
		B.Tube("Body",{{0,14,0,.18},{side*1.1,14.4,0,.13},{side*1.5,15.4,0,.03}},gold,8)
	end
	local counter={}
	for i=0,20 do
		local a=-math.pi*.05+i/20*math.pi*1.1
		table.insert(counter,{math.cos(a)*4.8,1.8,-4+math.sin(a)*1.4,.8,1.3})
	end
	B.Tube("Body",counter,"24635D",10)
	local rim={}
	for i,p in ipairs(counter) do rim[i]={p[1],3.0,p[3],.12} end
	B.Tube("Body",rim,gold,8)
	for _,x in ipairs({-3.2,0,3.2}) do
		B.Tube("Body",{{x,3,-4,.8},{x,3.2,-4,.8}},gold,12)
		B.Crystal("Body",{x,4.7,-4},{.42,2.6,.25},x==0 and "FFD077" or "94DFFF",true)
		B.Tube("Body",{{x-.75,3.6,-4,.07},{x,3.9,-4,.1},{x+.75,3.6,-4,.07}},gold,6)
	end
	-- A matching ivory pair of guardian dragons, sculpted from the same recipe.
	local statue={Id="statue",Color="D9E8E2",Accent="FFF1D1",Glow="86D9CB",Scale=.44,MinLevel=5,Wing=2,Horns=4,Spikes=5}
	for _,side in ipairs({-1,1}) do
		B.Tube("Body",{{side*10.7,.4,4.9,1.9},{side*10.7,1.1,4.9,1.9}},ivory,16)
		for _,data in ipairs(DragonRecipe.Build(statue,G)) do
			local dest=B.Group("Body",data.Glow)
			local offset=#dest.Vertices
			local angle=side*-.38
			for _,v in ipairs(data.Vertices) do
				B.Vertex(dest,{math.cos(angle)*v[1]+math.sin(angle)*v[3]+side*10.7,v[2]+2.1,-math.sin(angle)*v[1]+math.cos(angle)*v[3]+4.9})
			end
			for _,f in ipairs(data.Faces) do B.Face(dest,offset+f[1],offset+f[2],offset+f[3],f[4]) end
		end
	end
	return B.Result()
end
return R
