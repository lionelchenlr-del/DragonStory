-- Pure geometry recipe shared by the actual game models and exported previews.
local A = {}
local function sub(a, b) return { a[1]-b[1], a[2]-b[2], a[3]-b[3] } end
local function neg(a) return { -a[1], -a[2], -a[3] } end
local function dot(a, b) return a[1]*b[1] + a[2]*b[2] + a[3]*b[3] end
local function cross(a, b) return { a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1] } end
local function unit(a) local d = math.sqrt(dot(a,a)); return { a[1]/d, a[2]/d, a[3]/d } end
local function mid(a,b) return { (a[1]+b[1])/2, (a[2]+b[2])/2, (a[3]+b[3])/2 } end
function A.Parts(stage)
	local parts = {}
	local function add(name, shape, size, position, rotation, color, neon, group)
		local scaledSize, scaledPosition = {}, {}
		for i = 1, 3 do scaledSize[i], scaledPosition[i] = size[i] * stage.Scale, position[i] * stage.Scale end
		table.insert(parts, { Name = name, Shape = shape, Size = scaledSize, Position = scaledPosition,
			Rotation = rotation or { 0, 0, 0 }, Color = color or stage.Color, Neon = neon or false, Group = group })
	end
	local body, pale, glow = stage.Color, stage.Accent, stage.Glow
	local adult = stage.MinLevel >= 3
	local function triangle(a, b, c, color, group)
		local ab, ac, bc = sub(b,a), sub(c,a), sub(c,b)
		local abd, acd, bcd = dot(ab,ab), dot(ac,ac), dot(bc,bc)
		if abd > acd and abd > bcd then c,a = a,c elseif acd > abd and acd > bcd then a,b = b,a end
		ab,ac,bc = sub(b,a),sub(c,a),sub(c,b)
		local right = unit(cross(ac,ab))
		local back = unit(bc)
		local up = unit(cross(bc,right))
		local height = math.abs(dot(ab,up))
		add("WingMembrane", "Wedge", {0.09,height,math.abs(dot(ab,back))}, mid(a,b), nil, color, false, group)
		parts[#parts].Basis = {right,up,back}
		add("WingMembrane", "Wedge", {0.09,height,math.abs(dot(ac,back))}, mid(a,c), nil, color, false, group)
		parts[#parts].Basis = {neg(right),up,neg(back)}
	end
	local function rib(a,b,group,neon)
		local back = unit(sub(b,a))
		local right = unit(cross({0,1,0},back))
		local up = cross(back,right)
		add("WingRib", "Block", {0.15,0.15,math.sqrt(dot(sub(b,a),sub(b,a)))},mid(a,b),nil,neon and glow or pale,neon,group)
		parts[#parts].Basis = {right,up,back}
	end
	add("Body", "Ball", { 2.35, 2.6, 3.7 }, { 0, 0, 0 })
	add("Chest", "Ball", { 1.5, 2.1, 1.3 }, { 0, -0.2, -1.25 }, nil, pale)
	add("Neck", "Ball", { 1.5, 2.1, 1.7 }, { 0, 1.05, -1.45 }, { -22, 0, 0 })
	add("Head", "Ball", { adult and 1.95 or 2.15, adult and 1.6 or 1.9, adult and 2.6 or 2.3 }, { 0, 2, -2.15 })
	add("Muzzle", "Ball", { 1.65, 0.9, 1.65 }, { 0, 1.62, -3.05 }, nil, pale)
	add("Jaw", "Ball", { 1.4, 0.4, 1.4 }, { 0, 1.22, -2.9 }, nil, body)
	add("ForeheadCrystal", "Wedge", { 0.65, 0.8, 0.65 }, { 0, 2.92, -2.7 }, { -20, 0, 0 }, glow, true)
	for _, side in ipairs({ -1, 1 }) do
		add("EyeSocket", "Ball", { 0.5, adult and 0.38 or 0.72, 0.75 }, { side * 0.88, 2.17, -2.65 }, nil, "17223F")
		add("Eye", "Ball", { 0.17, adult and 0.19 or 0.5, 0.48 }, { side * 1.09, 2.2, -2.8 }, nil, glow, true)
		add("Brow", "Wedge", { 0.6, adult and 0.2 or 0.4, 0.85 }, { side * 0.95, adult and 2.4 or 2.56, -2.62 }, { 0, side * 12, side * -14 }, pale)
		add("Nostril", "Ball", { 0.16, 0.12, 0.12 }, { side * 0.43, 1.8, -3.79 }, nil, "23314E")
		add("HindLeg", "Ball", { 1.1, 1.4, 1.4 }, { side * 1.05, -1.1, 0.95 })
		add("ForeLeg", "Ball", { 0.65, 1.5, 0.7 }, { side * 0.9, -1.05, -1.2 }, { 0, 0, side * -12 })
		for _, z in ipairs({ -1.5, 0.6 }) do
			add("Paw", "Ball", { 0.85, 0.45, 1.2 }, { side * 1.05, -1.85, z }, nil, pale)
			for toe = -1, 1 do add("Claw", "Wedge", { 0.18, 0.3, 0.5 }, { side * 1.05 + toe * 0.24, -1.95, z - 0.58 }, { 0, 0, 180 }, "FFF4D4") end
		end
		local group = side == -1 and "WingLeft" or "WingRight"
		local shoulder = {side * 0.95,0.85,0.15}
		local previous = {side * (4.3+stage.Wing*0.45),3.8,0.1}
		rib(shoulder,previous,group,false)
		for blade = 1, stage.Wing + 1 do
			local tip = {side*(4.3+stage.Wing*0.45-blade*0.32),3.8-blade*0.8,0.1+blade*0.95}
			triangle(shoulder,previous,tip,blade%2==0 and pale or body,group)
			rib(shoulder,tip,group,false)
			rib(previous,tip,group,stage.MinLevel>=5)
			previous = tip
		end
		for horn = 1, stage.Horns / 2 do
			add("CrownHorn", "Wedge", { 0.38, 1.2 + horn * 0.3, 0.6 }, { side * (0.7 + horn * 0.12), 3.0 + horn * 0.11, -1.9 + horn * 0.5 },
				{ -25, side * -15, side * -22 }, pale)
		end
		if stage.Horns > 0 then
			add("ShoulderArmor", "Wedge", { 1.1, 0.65, 1.5 }, { side * 1.18, 0.6, -0.7 }, { 0, 0, side * -20 }, pale)
			add("ShoulderCrystal", "Ball", { 0.35, 0.45, 0.4 }, { side * 1.55, 0.9, -0.95 }, nil, glow, true)
		end
	end
	for n = 1, 5 do
		add("Tail", "Ball", { 1.25 - n * 0.16, 1.1 - n * 0.15, 1.5 }, { math.sin(n * 0.55) * 0.8, -0.15 + n * 0.12, 1.35 + n * 0.82 }, { n * -3, 8, 0 })
	end
	add("TailGem", "Wedge", { 0.65, 0.8, 1.15 }, { 0.25, 0.55, 6.15 }, { 0, 180, 0 }, glow, true)
	for spike = 1, stage.Spikes do
		add("DorsalSpine", "Wedge", { 0.28, 0.7, 0.7 }, { 0, 1.36 - spike * 0.07, -0.9 + spike * 0.52 }, { 0, 180, 0 }, pale)
	end
	if stage.Halo then
		for n = 1, 16 do
			local angle = n * math.pi / 8
			add("CrownHalo", "Block", { 0.65, 0.12, 0.14 }, { math.cos(angle) * 1.7, 4.05, -0.9 + math.sin(angle) * 1.7 }, { 0, -math.deg(angle) - 90, 0 }, glow, true)
		end
		for _, side in ipairs({ -1, 1 }) do
			add("OrbitCrystal", "Wedge", { 0.5, 1.2, 0.5 }, { side * 2.15, 2.4, 0.6 }, { 0, 45, side * 20 }, glow, true)
		end
	end
	return parts
end
return A
