local shared=script.Parent.Parent
local Meshes=require(shared:WaitForChild("DragonMeshes"))
local Geometry=require(shared:WaitForChild("Geometry"))
local Recipe=require(shared:WaitForChild("BoutiqueRecipe"))
local DragonRecipe=require(shared:WaitForChild("DragonMeshRecipe"))
local R={}
function R.Start()
	local world=workspace:WaitForChild("DragonWorld")
	local anchor=world:WaitForChild("CoinShopAnchor")
	local parts=Meshes.Get({Id="boutique"},function() return Recipe.Build(Geometry,DragonRecipe) end)
	if not parts or not world.Parent then return end
	Meshes.Retain("boutique")
	local model=Instance.new("Model")
	model.Name="DragonBoutiqueSculpture"
	model.Destroying:Connect(function() Meshes.Release("boutique") end)
	local cf=CFrame.new(anchor.Position-Vector3.new(0,2,0))
	for _,data in ipairs(parts) do
		local p=data.Template:Clone();p.CFrame=cf*data.Center;p.Parent=model
	end
	model.Parent=workspace
	local compatible=world:FindFirstChild("DragonBoutique")
	if compatible then
		for _,p in ipairs(compatible:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier=1 end end
	end
	return model
end
return R
