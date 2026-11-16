local Appearance = require(script.Parent:WaitForChild("DragonAppearance"))
local Meshes = require(script.Parent:WaitForChild("DragonMeshes"))
local Library = require(script.Parent:WaitForChild("ModelLibrary"))
local DragonModel = {}
function DragonModel.Build(parent, stage, effects)
	local approved=Library.Clone(stage.Id)
	if approved then
		approved.Name=stage.Name
		approved:SetAttribute("ArtRenderer","ApprovedImportedModel")
		approved.Parent=parent
		return {Model=approved,Wings={},Destroyed=false}
	end
	local model = Instance.new("Model")
	model.Name = stage.Name
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "Root", Vector3.new(0.2, 0.2, 0.2), 1
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.Parent, model.PrimaryPart = model, root
	local wings = {}
	for _, spec in ipairs(Appearance.Parts(stage)) do
		local p = Instance.new(spec.Shape == "Wedge" and "WedgePart" or "Part")
		p.Name, p.Size = spec.Name, Vector3.new(table.unpack(spec.Size))
		if spec.Shape == "Ball" then p.Shape = Enum.PartType.Ball end
		local r = spec.Rotation
		p.CFrame = CFrame.new(table.unpack(spec.Position)) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		if spec.Basis then
			p.CFrame = CFrame.fromMatrix(Vector3.new(table.unpack(spec.Position)), Vector3.new(table.unpack(spec.Basis[1])), Vector3.new(table.unpack(spec.Basis[2])), Vector3.new(table.unpack(spec.Basis[3])))
		end
		p.Color, p.Material = Color3.fromHex(spec.Color), spec.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = not spec.Neon
		p.Parent = model
		if spec.Group then
			local side = spec.Group == "WingLeft" and -1 or 1
			table.insert(wings, { Part = p, Base = p.CFrame, Hinge = CFrame.new(side * stage.Scale, stage.Scale, 0), Side = side })
		end
	end
	if effects and stage.MinLevel >= 5 then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Parent = Color3.fromHex(stage.Glow), 10, 0.7, root
	end
	model.Parent = parent
	local rig={Model=model,Wings=wings,Destroyed=false}
	model:SetAttribute("ArtRenderer","Compatible")
	model.Destroying:Connect(function() rig.Destroyed=true;if rig.MeshKey then Meshes.Release(rig.MeshKey) end end)
	task.spawn(function()
		local parts=Meshes.Get(stage)
		if not parts or rig.Destroyed then if rig.Destroyed then Meshes.Prune() end;return end
		Meshes.Retain(stage.Id);rig.MeshKey=stage.Id
		local cf=model:GetPivot()
		for _,p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p~=root then p:Destroy() end end
		rig.Wings={}
		for _,data in ipairs(parts) do
			local p=data.Template:Clone()
			p.CFrame=cf*data.Center
			p.Parent=model
			if data.Group~="Body" then
				local side=data.Group=="WingLeft" and -1 or 1
				table.insert(rig.Wings,{Part=p,Base=data.Center,Hinge=CFrame.new(side*.72*stage.Scale,.9*stage.Scale,-.45*stage.Scale),Side=side})
			end
		end
		model:SetAttribute("ArtRenderer","SculptedMesh")
	end)
	return rig
end
function DragonModel.Pose(rig, cf, time)
	rig.Model:PivotTo(cf)
	for _, wing in ipairs(rig.Wings) do
		wing.Part.CFrame = cf * wing.Hinge * CFrame.Angles(0, 0, wing.Side * math.sin(time * 3.8) * 0.14) * wing.Hinge:Inverse() * wing.Base
	end
end
return DragonModel
