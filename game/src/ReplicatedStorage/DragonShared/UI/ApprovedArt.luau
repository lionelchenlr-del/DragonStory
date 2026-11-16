-- Displays literal pixels from the approved originals; no generative repainting.
local AssetService=game:GetService("AssetService")
local EncodingService=game:GetService("EncodingService")
local shared=script.Parent.Parent
local Manifest=require(shared:WaitForChild("ArtManifest"))
local Config=require(shared:WaitForChild("ArtConfig"))
local Art={Cache={},Loading={},ActiveBytes=0}
local function acquire(tile)
	while Art.Loading[tile.Name] do task.wait() end
	local cached=Art.Cache[tile.Name]
	if cached then cached.References+=1;return cached.Image end
	Art.Loading[tile.Name]=true
	local editable=nil
	local ok,reason=pcall(function()
		local payload=require(shared:WaitForChild("ArtPixels"):WaitForChild(tile.Name))
		local compressed=EncodingService:Base64Decode(buffer.fromstring(payload))
		local expected=EncodingService:GetDecompressedBufferSize(compressed,Enum.CompressionAlgorithm.Zstd)
		assert(expected==tile.Width*tile.Height*4 and expected==tile.Bytes,"art payload size mismatch")
		local pixels=EncodingService:DecompressBuffer(compressed,Enum.CompressionAlgorithm.Zstd)
		assert(buffer.len(pixels)==expected,"art pixels truncated")
  if tile.Encoding=="Sub" then
   local stride=tile.Width*4
   for row=0,tile.Height-1 do
    local offset=row*stride
    for x=4,stride-1 do local index=offset+x;buffer.writeu8(pixels,index,(buffer.readu8(pixels,index)+buffer.readu8(pixels,index-4))%256) end
   end
  end
		editable=AssetService:CreateEditableImage({Size=Vector2.new(tile.Width,tile.Height)})
		assert(editable,"art image memory unavailable")
		editable:WritePixelsBuffer(Vector2.zero,Vector2.new(tile.Width,tile.Height),pixels)
	end)
	Art.Loading[tile.Name]=nil
	if not ok then if editable then editable:Destroy() end;return nil,reason end
	Art.Cache[tile.Name]={Image=editable,References=1,Bytes=tile.Bytes}
	Art.ActiveBytes+=tile.Bytes
	return editable
end
local function release(name)
	local cached=Art.Cache[name]
	if not cached then return end
	cached.References-=1
	if cached.References==0 then
		cached.Image:Destroy();Art.ActiveBytes-=cached.Bytes;Art.Cache[name]=nil
	end
end
function Art.Has(key) return Manifest.Regions[key]~=nil end
function Art.Mount(parent,key,props)
	local region=Manifest.Regions[key]
	assert(region,"unknown approved artwork: "..tostring(key))
	local root=Instance.new("Frame")
	root.Name,root.BackgroundTransparency,root.ClipsDescendants="ApprovedArt",1,true
	root.Size=UDim2.fromScale(1,1)
	for k,v in pairs(props or {}) do root[k]=v end
	local canvas=Instance.new("Frame")
	canvas.Name,canvas.BackgroundTransparency="ImageCanvas",1
	canvas.AnchorPoint,canvas.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	canvas.Parent=root
	local rect=region.Rect
	local function fit()
		local size=root.AbsoluteSize
		local w=math.min(size.X,size.Y*rect[3]/rect[4])
		canvas.Size=UDim2.fromOffset(w,w*rect[4]/rect[3])
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	local retained={}
	local destroyed=false
	root.Destroying:Connect(function()
		destroyed=true
		for _,name in ipairs(retained) do release(name) end
		table.clear(retained)
	end)
	root.Parent=parent;fit()
 if key:sub(1,4)=="map_" and Config.UseEmbeddedMaps==false and not Config.AssetIds[region.Atlas] then
  canvas:Destroy();require(script.Parent.MapView).DrawNative(root,key:sub(5));return root
 end
	task.spawn(function()
		local assetId=Config.AssetIds[region.Atlas]
		if assetId then
			if destroyed then return end
			local image=Instance.new("ImageLabel")
			image.BackgroundTransparency,image.Size=1,UDim2.fromScale(1,1)
			image.Image="rbxassetid://"..tostring(assetId)
			image.ImageRectOffset,image.ImageRectSize=Vector2.new(rect[1],rect[2]),Vector2.new(rect[3],rect[4])
			image.Parent=canvas;return
		end
		if not Config.UseEmbeddedOriginals then return end
		local failures=0
		for _,tile in ipairs(Manifest.Atlases[region.Atlas].Tiles) do
			if destroyed then return end
			local left,top=math.max(rect[1],tile.X),math.max(rect[2],tile.Y)
			local right,bottom=math.min(rect[1]+rect[3],tile.X+tile.Width),math.min(rect[2]+rect[4],tile.Y+tile.Height)
			if right>left and bottom>top then
				local image,reason=acquire(tile)
				if destroyed then if image then release(tile.Name) end;return end
				if image then
					table.insert(retained,tile.Name)
					local label=Instance.new("ImageLabel")
					label.Name,label.BackgroundTransparency=tile.Name,1
					label.Position=UDim2.fromScale((left-rect[1])/rect[3],(top-rect[2])/rect[4])
					label.Size=UDim2.fromScale((right-left)/rect[3],(bottom-top)/rect[4])
					label.ImageRectOffset,label.ImageRectSize=Vector2.new(left-tile.X,top-tile.Y),Vector2.new(right-left,bottom-top)
					label.ImageContent=Content.fromObject(image)
					label.Parent=canvas
     task.wait()
				else failures+=1;if failures==1 then warn("[Approved Art]",region.Atlas,reason) end;break end
			end
		end
		if failures>0 and not destroyed then
   canvas:Destroy()
   for _,name in ipairs(retained) do release(name) end;table.clear(retained)
   if key:sub(1,4)=="map_" then require(script.Parent.MapView).DrawNative(root,key:sub(5))
   else
    local C=require(shared.Catalog);local id=key=="emperor_head" and "astral" or key
    local view=Instance.new("ViewportFrame");view.Size=UDim2.fromScale(1,1);view.BackgroundTransparency=1;view.Parent=root
    local Preview=require(script.Parent.Preview)
    if C.Items[id] then Preview.Build(view,C.Items[id].Slot,Color3.new(1,1,1),false,id)
    elseif C.Monsters[id] then Preview.Build(view,id,Color3.new(1,1,1),true)
    else Preview.Dragon(view,require(shared.DragonEvolution).Stages[({sky=1,gale=2,solar=3,astral=4})[id] or 1]) end
   end
   return
  end
	end)
	return root
end
return Art
