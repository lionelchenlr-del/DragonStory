local TweenService = game:GetService("TweenService")
local U = {}
U.Colors = {
	Background = Color3.fromHex("101426"), Panel = Color3.fromHex("1B2038"), Card = Color3.fromHex("242B49"),
	Text = Color3.fromHex("EDF1FF"), Muted = Color3.fromHex("A5B2D4"), Gold = Color3.fromHex("FFD278"),
	Purple = Color3.fromHex("9F80FF"), Cyan = Color3.fromHex("6CDEFF"), Danger = Color3.fromHex("FF7F91"),
}
U.Tabs = {
	Inventory = { Accent = Color3.fromHex("65DEFF"), Dark = Color3.fromHex("153747"), Label = "背包", Mark = "I" },
	Sets = { Accent = Color3.fromHex("FFBC75"), Dark = Color3.fromHex("463025"), Label = "套裝", Mark = "II" },
	Monsters = { Accent = Color3.fromHex("FF85B5"), Dark = Color3.fromHex("42243E"), Label = "怪物", Mark = "III" },
	Shop = { Accent = Color3.fromHex("82F5D2"), Dark = Color3.fromHex("153D3C"), Label = "商店", Mark = "IV" },
	Map = {Accent=Color3.fromHex("A5DFFF"),Dark=Color3.fromHex("1A334D"),Label="地圖",Mark="VI"},
	Dragon = { Accent = Color3.fromHex("CFADFF"), Dark = Color3.fromHex("392C58"), Label = "龍寵", Mark = "V" },
}
function U.Gradient(parent, first, last, rotation)
	return U.New("UIGradient", parent, { Color = ColorSequence.new(first, last), Rotation = rotation or 35 })
end
function U.New(class, parent, props)
	local instance = Instance.new(class)
	for key, value in pairs(props or {}) do instance[key] = value end
	instance.Parent = parent
	return instance
end
function U.Round(parent, radius)
	return U.New("UICorner", parent, { CornerRadius = UDim.new(0, radius or 12) })
end
function U.Stroke(parent, color, transparency)
	return U.New("UIStroke", parent, { Color = color or U.Colors.Purple, Thickness = 1, Transparency = transparency or 0.6 })
end
function U.Frame(parent, name, props)
	local p = { Name = name, BackgroundColor3 = U.Colors.Panel, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do p[k] = v end
	return U.New("Frame", parent, p)
end
function U.Label(parent, text, props)
	local p = { BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham, TextSize = 15,
		TextColor3 = U.Colors.Text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true, Size = UDim2.new(1, 0, 0, 24) }
	for k, v in pairs(props or {}) do p[k] = v end
	return U.New("TextLabel", parent, p)
end
function U.Button(parent, text, callback, props)
	local p = { Text = text, Active = true, Selectable = true, AutoButtonColor = false, BackgroundColor3 = U.Colors.Card, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = U.Colors.Text, Size = UDim2.new(1, 0, 0, 44) }
	for k, v in pairs(props or {}) do p[k] = v end
	local b = U.New("TextButton", parent, p)
	U.Round(b, 10)
	U.Stroke(b)
	b.Activated:Connect(function() if b.Active then callback() end end)
	local baseColor = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		local border = b:FindFirstChildOfClass("UIStroke")
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = baseColor:Lerp(border and border.Color or U.Colors.Purple, 0.18) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
	return b
end
function U.List(parent, spacing)
	return U.New("UIListLayout", parent, { Padding = UDim.new(0, spacing or 8), SortOrder = Enum.SortOrder.LayoutOrder })
end
function U.Padding(parent, amount)
	return U.New("UIPadding", parent, { PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount) })
end
function U.Scroll(parent, name)
	return U.New("ScrollingFrame", parent, { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
		Active = true,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = U.Colors.Purple, ScrollingDirection = Enum.ScrollingDirection.Y })
end
function U.Clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end
function U.Ornate(parent,accent)
	local border=parent:FindFirstChildOfClass("UIStroke") or U.Stroke(parent,U.Colors.Gold,0.05)
	border.Color,border.Thickness=U.Colors.Gold,1.5
	local inner=U.Frame(parent,"InnerGoldLine",{BackgroundTransparency=1,Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,1,-10)})
	U.Round(inner,10);U.Stroke(inner,U.Colors.Gold,.72)
	for _,corner in ipairs({{0,0},{1,0},{0,1},{1,1}}) do
		local gem=U.Frame(parent,"CornerGem",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(corner[1],corner[2]),Size=UDim2.fromOffset(13,13),Rotation=45,BackgroundColor3=accent})
		U.Stroke(gem,U.Colors.Gold,.1);U.Round(gem,2)
	end
	return border
end
function U.Crest(parent,accent)
	local crest=U.Frame(parent,"DragonCrest",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(30,30),Rotation=45,BackgroundColor3=accent})
	U.Round(crest,5);U.Stroke(crest,U.Colors.Gold,0)
	for _,side in ipairs({-1,1}) do
		for i=1,3 do
			local feather=U.Frame(parent,"CrestWing",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,side*(22+i*10),0,-7+i*3),Size=UDim2.fromOffset(27-i*3,4),Rotation=side*(15+i*9),BackgroundColor3=U.Colors.Gold})
			U.Round(feather,2)
		end
	end
	return crest
end
return U
