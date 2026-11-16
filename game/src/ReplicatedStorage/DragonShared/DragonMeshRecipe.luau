-- Pure continuous-surface dragon sculpture. Coordinates use Roblox's Y-up space.
local Recipe={}
function Recipe.Build(stage,G)
	local B=G.New(stage.Scale)
	local body,pale,gold,glow=stage.Color,stage.Accent,"E5BF72",stage.Glow
	local adult=stage.MinLevel>=3
	local headY=adult and 3.15 or 2.65
	B.Ellipsoid("Body",{0,0,0},{2,2.35,3.7},body,16,10)
	B.Ellipsoid("Body",{0,-.2,-1.1},{1.5,1.85,1.2},pale,12,8)
	B.Tube("Body",{{0,.6,-1.15,.72,.65},{0,1.5,-1.7,.6,.59},{0,headY-.7,-1.65,.44,.5},{0,headY,-1.95,.43,.4}},body,14)
	B.Tube("Body",{{0,.25,-1.72,.42,.18},{0,1.3,-2.12,.37,.16},{0,headY-.6,-2.08,.28,.15},{0,headY-.1,-2.3,.25,.12}},pale,10)
	B.Ellipsoid("Body",{0,headY+.15,-2.05},{adult and 1.65 or 1.7,adult and 1.25 or 1.4,1.95},body,16,10)
	B.Tube("Body",{{0,headY-.1,-2.3,.58,.34},{0,headY-.22,-3.1,.43,.24},{0,headY-.25,-3.65,.17,.13}},pale,12)
	B.Ellipsoid("Body",{0,headY-.48,-2.9},{.83,.18,1.2},body,12,6)
	B.Crystal("Body",{0,headY+.77,-2.35},{.5,.8,.36},glow,true)
	for _,side in ipairs({-1,1}) do
		B.Ellipsoid("Body",{side*.61,headY+.2,-2.56},{.2,adult and .31 or .5,.56},"142A49",12,8)
		B.Ellipsoid("Body",{side*.7,headY+.24,-2.62},{.08,adult and .14 or .3,.31},glow,10,6,true)
		B.Tube("Body",{{side*.43,headY+.48,-2.78,.12},{side*.7,headY+.48,-2.45,.1},{side*.82,headY+.37,-2.03,.015}},pale,6)
		B.Tube("Body",{{side*.6,headY-.1,-1.7,.26},{side*1.0,headY+.1,-1.16,.18},{side*1.4,headY+.45,-.73,.015}},pale,8)
		for horn=1,stage.Horns/2 do
			local z=-1.95+horn*.36
			B.Tube("Body",{{side*.45,headY+.55,z,.2},{side*.75,headY+1.1,z+.3,.15},{side*(1.1+horn*.14),headY+1.55,z+1.05,.065},{side*(1.35+horn*.16),headY+1.48,z+1.75,.008}},gold,8)
		end
		B.Ellipsoid("Body",{side*.97,-.7,.95},{1,1.5,1.55},body,12,8)
		B.Tube("Body",{{side*.97,-.5,-1.14,.35},{side*.94,-1.4,-1.4,.25},{side*1.04,-2.12,-1.62,.16}},body,10)
		B.Tube("Body",{{side*1.1,-1.05,1.15,.36},{side*.95,-1.72,1.65,.2},{side*1.1,-2.1,1.04,.16}},body,10)
		for _,z in ipairs({-1.72,1.0}) do
			B.Ellipsoid("Body",{side*1.06,-2.12,z},{.65,.3,.9},pale,10,6)
			for toe=-1,1 do
				local x=side*1.06+toe*.2
				B.Tube("Body",{{x,-2.17,z-.25,.09},{x,-2.18,z-.57,.06},{x,-2.12,z-.8,.007}},"FFF1CF",6)
			end
		end
		if adult then
			for row=1,3 do
				B.Crystal("Body",{side*(.8+row*.07),.85-row*.27,-1.02+row*.18},{.68,.8,.25},gold)
			end
			B.Crystal("Body",{side*1.04,.68,-.82},{.27,.5,.3},glow,true)
		end
		local wing=side==-1 and "WingLeft" or "WingRight"
		local w=.54+stage.Wing*.15
		local root={side*.72,.9,-.45}
		local elbow={side*2.1*w,2.85*w,-.1}
		local edge={{side*5.8*w,5.6*w,.7},{side*6.3*w,3.3*w,2.1},{side*5.35*w,1.25*w,3.8},{side*3.8*w,.45,4.5},{side*2.1*w,.6,3.4}}
		B.Tube(wing,{{root[1],root[2],root[3],.22},{elbow[1],elbow[2],elbow[3],.18},{edge[1][1],edge[1][2],edge[1][3],.025}},pale,8)
		for i=1,#edge-1 do
			B.Triangle(wing,elbow,edge[i],edge[i+1],i%2==0 and pale or body)
			B.Triangle(wing,root,elbow,edge[i+1],body)
			local p=edge[i+1]
			B.Tube(wing,{{elbow[1],elbow[2],elbow[3],.1},{p[1]*.8,(p[2]+elbow[2])*.5,p[3]*.6,.065},{p[1],p[2],p[3],.012}},gold,6)
			B.Tube(wing,{{edge[i][1],edge[i][2],edge[i][3],.035},{p[1],p[2],p[3],.035}},stage.MinLevel>=5 and glow or pale,5,stage.MinLevel>=5)
			if adult then B.Crystal(wing,{p[1],p[2]+.12,p[3]},{.22,.7,.35},gold) end
		end
		if stage.Halo then
			for i=1,6 do B.Crystal(wing,{side*(2.4+i*.36),2.8-i*.18,.7+i*.3},{.09,.16,.08},glow,true) end
		end
	end
	local tail={}
	for i=0,10 do
		local t=i/10
		table.insert(tail,{math.sin(t*math.pi*1.25)*1.75,-.15+t*.75,1.45+t*6.2,math.max(.025,.55*(1-t)),math.max(.025,.45*(1-t))})
	end
	B.Tube("Body",tail,body,10)
	local tip=tail[#tail]
	local crescent={}
	for i=0,10 do
		local a=-1.0+i/10*4.2
		table.insert(crescent,{tip[1]+math.cos(a)*.58,tip[2]+math.sin(a)*.8,tip[3],math.max(.012,math.sin(i/10*math.pi)*.1)})
	end
	B.Tube("Body",crescent,glow,6,true)
	for i=1,stage.Spikes+3 do
		local z=-.8+i*.34
		B.Crystal("Body",{0,1.15-i*.025,z},{.23,.85-i*.035,.5},pale)
	end
	if stage.MinLevel>=5 then
		for i=1,5 do B.Crystal("Body",{0,headY-1.4-i*.26,-1.95},{.75-i*.045,.47,.22},gold) end
		B.Crystal("Body",{0,.8,-1.8},{.7,1.0,.3},glow,true)
	end
	if stage.Halo then
		local ring={}
		for i=0,40 do
			local a=i*math.pi/20
			table.insert(ring,{math.cos(a)*1.8,headY+2.4,-.3+math.sin(a)*1.8,.028})
		end
		B.Tube("Body",ring,glow,5,true)
		for _,side in ipairs({-1,1}) do B.Crystal("Body",{side*2.1,headY+.5,.1},{.35,.95,.35},glow,true) end
	end
	return B.Result()
end
return Recipe
