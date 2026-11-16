local Library={}
function Library.Clone(id)
	local folder=script.Parent:FindFirstChild("ApprovedModels")
	local template=folder and folder:FindFirstChild(id)
	if not template or not template:IsA("Model") then return nil end
	local model=template:Clone()
	local oldPivot=model:GetPivot()
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false end
	end
	local root=Instance.new("Part")
	root.Name,root.Transparency,root.Size="ApprovedModelPivot",1,Vector3.new(.1,.1,.1)
	root.Anchored,root.CanCollide,root.CanQuery,root.CanTouch=true,false,false,false
	root.CFrame,root.Parent=oldPivot,model
	model.PrimaryPart=root
	model:PivotTo(CFrame.new())
	return model
end
return Library
