local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("DragonShared")
local C = require(shared:WaitForChild("Catalog"))
local Evolution = require(shared:WaitForChild("DragonEvolution"))
local LootInfo = require(shared:WaitForChild("LootInfo"))
local uiModules = shared:WaitForChild("UI")
local U = require(uiModules:WaitForChild("Components"))
local Preview = require(uiModules:WaitForChild("Preview"))
local ApprovedArt = require(uiModules:WaitForChild("ApprovedArt"))
local CompanionRenderer = require(uiModules:WaitForChild("CompanionRenderer"))
local BoutiqueRenderer = require(uiModules:WaitForChild("BoutiqueRenderer"))
local WorldRenderer=require(uiModules.WorldRenderer)
local FlightController=require(uiModules.FlightController)
local MapView=require(uiModules.MapView)
local WorldData=require(shared.WorldData)
task.spawn(function()local stop=WorldRenderer.Start();script.Destroying:Connect(stop)end)
local stopMap=MapView.StartHUD(script.Parent);script.Destroying:Connect(stopMap)
task.spawn(function()
	local stop = CompanionRenderer.Start()
	script.Destroying:Connect(stop)
end)
local remotes = ReplicatedStorage:WaitForChild("DragonRemotes")
local request, update = remotes:WaitForChild("Request"), remotes:WaitForChild("Update")
local gui = script.Parent
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 10

local state = nil
local activeTab, selected = "Inventory", nil
local category = "All"
local mobile, searchText, rarityFilter, sortMode = false, "", "All", "Rarity"
local pending, navButtons = {}, {}
local purchasePending = nil
local filterOrder = { "All", "Common", "Rare", "Epic", "Legendary", "Mythic" }
local tabNames = { Inventory = "裝備背包", Sets = "套裝圖鑑", Monsters = "怪物圖鑑", Shop = "龍晶商行", Dragon = "龍之覺醒", Map = "群島地圖" }
local messages = {
	PURCHASED = "購買成功！物品已放入背包。", EQUIPPED = "裝備完成，能力已更新。", UNEQUIPPED = "已卸下裝備。",
	NO_COINS = "金幣不足。", LEVEL_LOW = "尚未達到此島或裝備的需求等級。", STACK_FULL = "該裝備已達 99 件上限。",
	NOT_OWNED = "尚未擁有這件裝備。", SHOP_FAR = "請靠近目前島嶼的商人或裝備工作台。", TOO_FAR = "離怪物太遠，靠近後再攻擊。",
	BLOCKED = "攻擊路線被障礙物擋住。", BAD_TARGET = "怪物已消失，請重新選擇目標。", NOT_ALIVE = "角色死亡或尚未出生。",
	NOT_READY = "資料仍在載入，請稍候。", CLOSING = "伺服器正在關閉，請稍後重連。", DUPLICATE = "這個請求已處理，畫面已同步。",
	BAD_OFFER = "商品不存在。", BAD_ITEM = "裝備不存在。", BAD_SLOT = "裝備欄位不存在。", BAD_QUANTITY = "購買數量須為 1–10 件。",
}

messages.MOUNTED="已騎乘。";messages.DISMOUNTED="已下龍。";messages.LAND_FIRST="請先下降到島上地面附近，再按F下龍。"
messages.CAVE_NO_FLIGHT="洞窟內不能騎龍，請先返回地表。";messages.RIDE_REQUIRED="跨島必須騎龍。";messages.DISMOUNT_TO_FIGHT="請先下龍再戰鬥。"
messages.SOLD="裝備已回收，金幣已入帳。";messages.CLAIMED="待領裝備已放入背包。";messages.IN_USE="最後一件正在穿戴，請先卸下。"
messages.QUEST_REWARD="委託獎勵已領取。";messages.QUEST_FAR="請到本島補給區的委託NPC旁領取。";messages.QUEST_INCOMPLETE="委託目標尚未完成。";messages.QUEST_CLAIMED="這項委託已領取。";messages.NOT_PENDING="沒有待領的這件裝備。"
local hud = U.Frame(gui, "HUD", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 76) })
local title = U.Label(hud, "龍之覺醒", { Name = "Title", TextSize = 24, Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(16, 7), Size = UDim2.new(0.55, 0, 0, 30), TextColor3 = U.Colors.Gold })
local subtitle = U.Label(hud, "天空群島  /  DRAGON AWAKENING", { Position = UDim2.fromOffset(17, 38),
	TextSize = 11, TextColor3 = U.Colors.Muted, Size = UDim2.new(0.6, 0, 0, 20) })
local wallet = U.Label(hud, "連線中…", { Name = "Wallet", AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 8), Size = UDim2.new(0.43, 0, 0, 28), Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = U.Colors.Gold })
local hpLabel = U.Label(hud, "HP —", { Name = "Health", AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 38), Size = UDim2.new(0.43, 0, 0, 22), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right })
local menu = U.Frame(gui, "MainMenu", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.new(1, -24, 0, 48), BackgroundTransparency = 1 })
local panel = U.Frame(gui, "MainPanel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76) })
U.Round(panel, 18)
local panelStroke = U.Stroke(panel, U.Colors.Cyan, 0.15)
U.Ornate(panel,U.Tabs.Shop.Accent)
local topGem=U.Crest(panel,U.Tabs.Shop.Accent)
local panelGradient = U.Gradient(panel, Color3.fromHex("263047"), Color3.fromHex("101322"), 60)
local crest = U.Label(panel, "I", { Name = "Crest", Position = UDim2.fromOffset(16, 11), Size = UDim2.fromOffset(38, 38),
	BackgroundTransparency = 0, BackgroundColor3 = U.Colors.Card, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 16 })
U.Round(crest, 12)
local accentLine = U.Frame(panel, "AccentLine", { Position = UDim2.fromOffset(18, 61), Size = UDim2.new(1, -36, 0, 2), BackgroundColor3 = U.Colors.Cyan })
U.Gradient(accentLine, Color3.new(1, 1, 1), Color3.fromHex("19334C"))
local heading = U.Label(panel, "裝備背包", { Name = "Heading", Position = UDim2.fromOffset(18, 9),
	Size = UDim2.new(1, -120, 0, 30), TextSize = 23, Font = Enum.Font.GothamBold })
heading.Position = UDim2.fromOffset(64, 8)
local panelHint = U.Label(panel, "伺服器資料載入中…", { Position = UDim2.fromOffset(18, 39),
	Size = UDim2.new(1, -40, 0, 20), TextSize = 12, TextColor3 = U.Colors.Muted })
U.Button(panel, "×", function() panel.Visible = false end, { Name = "Close", Position = UDim2.new(1, -48, 0, 10), Size = UDim2.fromOffset(34, 34), TextSize = 24 })
local search = U.New("TextBox", panel, { Name = "Search", Position = UDim2.fromOffset(14, 109), Size = UDim2.new(0.5, -20, 0, 32),
	BackgroundColor3 = U.Colors.Card, BorderSizePixel = 0, Text = "", PlaceholderText = "搜尋名稱、部位…", ClearTextOnFocus = false,
	Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = U.Colors.Text, PlaceholderColor3 = U.Colors.Muted })
U.Round(search, 9); U.Padding(search, 8)
local filterButton, sortButton
local categories=U.Frame(panel,"CategoryTabs",{Position=UDim2.fromOffset(14,68),Size=UDim2.new(1,-28,0,32),BackgroundTransparency=1})
local categoryButtons={}
local body = U.Frame(panel, "Body", { Position = UDim2.fromOffset(12, 150), Size = UDim2.new(1, -24, 1, -164), BackgroundTransparency = 1 })
local list = U.Scroll(body, "EntryList")
local entryLayout=U.List(list,7)
U.Padding(list,6)
local detail = U.Scroll(body, "Detail")
detail.BackgroundTransparency, detail.BackgroundColor3 = 0, U.Colors.Background
U.Round(detail, 12); U.List(detail, 9); U.Padding(detail, 12)
local actionDock=U.Frame(body,"ActionDock",{AnchorPoint=Vector2.new(0,1),BackgroundTransparency=1,Size=UDim2.fromOffset(200,44)})
local toast = U.Label(gui, "", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.new(1, -36, 0, 64), BackgroundTransparency = 0.05, BackgroundColor3 = U.Colors.Card,
	TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 30 })
U.Round(toast); U.Stroke(toast, U.Colors.Gold, 0.2); U.Padding(toast, 10)
local toastSerial = 0
local function notify(text, bad)
	toastSerial += 1
	local serial = toastSerial
	toast.Text, toast.TextColor3, toast.Visible = text, bad and U.Colors.Danger or U.Colors.Gold, true
	task.delay(3.5, function() if serial == toastSerial then toast.Visible = false end end)
end

local render, renderDetail
local function send(action, key, quantity)
	if not state and action ~= "Sync" then notify("資料載入中…", true); return end
	local id = HttpService:GenerateGUID(false)
	pending[id] = { Action = action, Sent = os.clock() }
	request:FireServer({ Id = id, Action = action, Key = key, Quantity = quantity })
	task.delay(8, function()
		if not pending[id] then return end
		pending[id] = nil
		if purchasePending == id then purchasePending = nil end
		if action ~= "Attack" and action ~= "Sync" then
			notify("回覆逾時；請檢查背包或金幣確認結果，再決定是否重試。", true)
			send("Sync") -- Never automatically retry a purchase with a new ID.
		end
	end)
	return id
end
local stopFlight=FlightController.Start(gui,send,notify,function()panel.Visible=false end)
script.Destroying:Connect(stopFlight)
local function statText(item)
	local parts = {}
	for _, pair in ipairs({ { "Attack", "攻擊" }, { "HP", "生命" }, { "Defense", "防禦" }, { "Speed", "速度" } }) do
		if item[pair[1]] then table.insert(parts, pair[2] .. " +" .. item[pair[1]]) end
	end
	return table.concat(parts, "  ·  ")
end
local function textRow(text, color, size)
	return U.Label(detail, text, { Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = size or 15, TextColor3 = color or U.Colors.Text, TextYAlignment = Enum.TextYAlignment.Top })
end
local function previewRow(kind, color, monster, itemId)
	Preview.Inspect(detail, kind, color, monster, itemId, math.clamp(detail.AbsoluteSize.Y*.76,170,310))
end
local function lootCard(id,chance)
	local item=C.Items[id]
	local card=U.Frame(detail,"Drop_"..id,{Size=UDim2.new(1,-4,0,108),BackgroundColor3=U.Colors.Panel})
	U.Round(card,10)
	ApprovedArt.Mount(card,id,{Position=UDim2.fromOffset(6,5),Size=UDim2.fromOffset(100,98)})
	U.Label(card,(LootInfo.Codes[id] or "").." "..item.Name,{Position=UDim2.fromOffset(116,9),Size=UDim2.new(1,-126,0,38),TextSize=14,TextColor3=Color3.fromHex(C.Rarities[item.Rarity].Color),Font=Enum.Font.GothamBold})
	U.Label(card,"實際掉落率 "..LootInfo.Percent(chance),{Position=UDim2.fromOffset(116,54),Size=UDim2.new(1,-126,0,38),TextColor3=U.Colors.Gold,TextSize=16})
end
local function buttonRow(text, callback, color)
	local theme = U.Tabs[activeTab]
	local button = U.Button(detail, text, callback, { BackgroundColor3 = color or theme.Dark, TextColor3 = theme.Accent })
	button:FindFirstChildOfClass("UIStroke").Color = theme.Accent
	return button
end
local function equippedSummary()
	textRow("穿戴欄位", U.Colors.Gold, 13)
	for _, slot in ipairs(C.Slots) do
		local itemId = state.Equipment[slot]
		local slotName = C.SlotNames[slot]
		buttonRow(slotName .. "  ·  " .. (itemId and C.Items[itemId].Name or "未裝備") .. (itemId and "  [卸下]" or ""), function()
			if itemId then send("Unequip", slot) end
		end)
	end
end

local modal = U.Frame(gui, "PurchaseConfirm", { Visible = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.25, Active = true, ZIndex = 50 })
local box = U.Frame(modal, "Dialog", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -40, 0, 304), ZIndex = 51 })
U.New("UISizeConstraint", box, { MaxSize = Vector2.new(440, 304) }); U.Round(box, 16); U.Stroke(box, U.Colors.Gold)
U.Gradient(box, Color3.fromHex("294D4D"), Color3.fromHex("16203B"), 60)
local modalTitle = U.Label(box, "確認購買", { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 30), Font = Enum.Font.GothamBold, TextSize = 21, ZIndex = 52 })
local modalBody = U.Label(box, "", { Position = UDim2.fromOffset(20, 55), Size = UDim2.new(1, -40, 0, 90), ZIndex = 52 })
local quantityLabel = U.Label(box, "1", { Position = UDim2.new(0.5, -40, 0, 155), Size = UDim2.fromOffset(80, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52 })
local currentOffer, quantity = nil, 1
local function updateModal()
	local offer = currentOffer and C.Shop[currentOffer]
	if not offer then modal.Visible = false; return end
	modalTitle.Text = "購買 · " .. C.Items[offer.Item].Name
	modalBody.Text = "每件 " .. offer.Price .. " 金幣\n總價 " .. offer.Price * quantity .. " 金幣\n目前持有 " .. (state and state.Coins or 0) .. " 金幣"
	quantityLabel.Text = tostring(quantity)
end
U.Button(box, "−", function() quantity = math.max(1, quantity - 1); updateModal() end,
	{ Position = UDim2.new(0.5, -100, 0, 153), Size = UDim2.fromOffset(44, 44), ZIndex = 52 })
U.Button(box, "+", function() quantity = math.min(10, quantity + 1); updateModal() end,
	{ Position = UDim2.new(0.5, 56, 0, 153), Size = UDim2.fromOffset(44, 44), ZIndex = 52 })
U.Button(box, "取消", function() modal.Visible = false end,
	{ Position = UDim2.new(0, 20, 1, -66), Size = UDim2.new(0.45, -16, 0, 44), ZIndex = 52 })
U.Button(box, "確認購買", function()
	if purchasePending then notify("上一筆購買仍在等待回覆。", true); return end
	if currentOffer then
		local offerId, count = currentOffer, quantity
		modal.Visible = false
		purchasePending = send("Buy", offerId, count)
	end
end, { Position = UDim2.new(0.5, 4, 1, -66), Size = UDim2.new(0.5, -24, 0, 44), BackgroundColor3 = Color3.fromHex("27685C"), TextColor3 = Color3.fromHex("C0FFE9"), ZIndex = 52 })
local dockButton=U.Button(actionDock,"選擇裝備",function()
	if not selected or not state then return end
	if activeTab=="Shop" and C.Shop[selected] then currentOffer=selected;quantity=1;updateModal();modal.Visible=true
	elseif activeTab=="Inventory" and C.Items[selected] then
		local item=C.Items[selected]
		if (state.Inventory[selected] or 0)==0 and state.PendingItems and (state.PendingItems[selected] or 0)>0 then send("ClaimPending",selected)
		elseif state.Equipment[item.Slot]==selected then send("Unequip",item.Slot) else send("Equip",selected) end
	end
end,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromHex("275A51"),TextColor3=U.Colors.Gold})
U.Ornate(dockButton,U.Tabs.Shop.Accent)

renderDetail = function()
	local oldScroll = detail.CanvasPosition
	U.Clear(detail)
	if not state then textRow("正在向伺服器載入角色資料…"); return end
	if not selected then
		dockButton.Text="沒有可操作的裝備"
		textRow("選擇左側項目查看詳細資料。", U.Colors.Muted)
		if activeTab == "Inventory" then equippedSummary() end
		return
	end
	if activeTab == "Inventory" or activeTab == "Shop" then
		local offer = activeTab == "Shop" and C.Shop[selected] or nil
		local id = offer and offer.Item or selected
		local item = C.Items[id]
		if not item then return end
		local rarity = C.Rarities[item.Rarity]
		dockButton.Text=offer and ("◇ 購買裝備 · "..offer.Price.." 金幣") or state.Equipment[item.Slot]==id and "卸下裝備" or "裝備"
		if not offer and (state.Inventory[id] or 0)==0 and state.PendingItems and (state.PendingItems[id] or 0)>0 then dockButton.Text="領取待領裝備" end
		textRow(item.Name, Color3.fromHex(rarity.Color), 22)
		textRow(rarity.Name .. "  /  " .. C.SlotNames[item.Slot] .. "  /  需求 Lv." .. item.Level, U.Colors.Muted, 13)
		previewRow(item.Slot, Color3.fromHex(rarity.Color), false, id)
		textRow(statText(item), U.Colors.Cyan)
		local sources=LootInfo.ForItem(id,C.MonsterOrder)
		if #sources==0 then textRow("取得方式：新手初始贈送 1 件",U.Colors.Gold,13)
		else
			textRow("掉落來源（每次擊殺的實際機率）",U.Colors.Gold,14)
			for _,source in ipairs(sources) do textRow(C.Monsters[source.Monster].Name.."  ·  "..LootInfo.Percent(source.Chance),U.Colors.Cyan,14) end
		end
		textRow(item.Description or "龍族之力凝聚的天空裝備。", U.Colors.Muted)
		textRow("持有數量 " .. (state.Inventory[id] or 0) .. " / " .. C.MaxStack, U.Colors.Gold)
		if item.Set then textRow("套裝：" .. C.Sets[item.Set].Name .. "（穿戴 " .. (state.Stats.Sets[item.Set] or 0) .. "/4）") end
		if offer then
			textRow("單價 " .. offer.Price .. " 金幣  ·  需求 Lv." .. offer.Level, U.Colors.Gold, 18)
			buttonRow("◇  選購此裝備  ·  " .. offer.Price .. " 金幣", function() currentOffer = selected; quantity = 1; updateModal(); modal.Visible = true end)
			textRow("需靠近目前島嶼的商人；購買後不會自動裝備。", U.Colors.Muted, 13)
		else
			local equipped = state.Equipment[item.Slot] == id
			buttonRow(equipped and "卸下裝備" or "裝備", function()
				if equipped then send("Unequip", item.Slot) else send("Equip", id) end
			end, Color3.fromHex("6652AD"))
			local pendingCount=state.PendingItems and state.PendingItems[id] or 0
			if pendingCount>0 then buttonRow("領取待領裝備 ×"..pendingCount,function()send("ClaimPending",id)end) end
			buttonRow("出售 1 件（需靠近商人或工作台）",function()send("Sell",id,1)end)
			equippedSummary()
		end
	elseif activeTab == "Sets" then
		local set = C.Sets[selected]
		if not set then return end
		local discovered, owned = 0, 0
		for _, id in ipairs(set.Items) do
			if state.Discovered[id] then discovered += 1 end
			if state.Inventory[id] then owned += 1 end
		end
		local wearing = state.Stats.Sets[selected] or 0
		textRow(set.Name .. "套裝", Color3.fromHex(set.Color), 22)
		textRow(set.Region .. "  ·  已發現 " .. discovered .. "/4  ·  現持有 " .. owned .. "/4", U.Colors.Muted, 13)
		previewRow("Armor", Color3.fromHex(set.Color),false,set.Items[3])
		textRow("目前穿戴 " .. wearing .. "/4 件", U.Colors.Gold, 18)
		for _, bonus in ipairs(set.Bonuses) do
			textRow((wearing >= bonus.Count and "[已啟動] " or "[未啟動] ") .. bonus.Count .. " 件 · " .. bonus.Text,
				wearing >= bonus.Count and U.Colors.Cyan or U.Colors.Muted)
		end
		for _, id in ipairs(set.Items) do
			textRow((state.Discovered[id] and "[已發現] " or "[未發現] ") .. C.Items[id].Name .. "  ×" .. (state.Inventory[id] or 0),
				state.Equipment[C.Items[id].Slot] == id and U.Colors.Gold or U.Colors.Text)
		end
		textRow("收集紀錄永久保留；套裝能力只計算目前穿戴的不同部位。", U.Colors.Muted, 13)
	elseif activeTab == "Monsters" then
		local monster = C.Monsters[selected]
		if not monster then return end
		local kills = state.Kills[selected] or 0
		textRow(monster.Name .. (monster.Boss and "  BOSS" or ""), Color3.fromHex(monster.Color), 22)
		textRow(monster.Region .. "  /  Lv." .. monster.Level .. "  /  " .. (kills > 0 and "已解鎖" or "待首次擊敗"), U.Colors.Muted, 13)
		previewRow(selected, Color3.fromHex(monster.Color), true)
		textRow("HP " .. monster.HP .. "  ·  攻擊 " .. monster.Attack .. "  ·  擊敗 " .. kills .. " 次", U.Colors.Cyan)
		textRow("獎勵 " .. monster.Coins .. " 金幣 / " .. monster.XP .. " EXP", U.Colors.Gold)
		textRow("出現地點："..monster.Location,U.Colors.Gold,14)
		textRow("重生 "..monster.Respawn.." 秒  /  基準數值以最低等級顯示",U.Colors.Muted,12)
		local pool=LootInfo.Pools[selected]
		textRow("掉任一件裝備 "..LootInfo.Percent(pool.Chance).."  /  不掉裝備 "..LootInfo.Percent(1-pool.Chance),U.Colors.Gold)
		for k,id in ipairs(pool.Items) do lootCard(id,pool.Weights[k]/10000) end
		textRow("每次最多 1 件；可重複、無保底。各結果互斥；頭目必掉一件，但不保證指定部位。",U.Colors.Muted,13)
		textRow("尾刀玩家獲獎；堆疊滿時優先進入待領裝備。",U.Colors.Muted,13)
	elseif activeTab=="Map" then
		MapView.Show(detail,selected,state,send,notify)
	elseif activeTab == "Dragon" then
		local index = tonumber(selected)
		local stage = index and Evolution.Stages[index]
		if not stage then return end
		local current = state.DragonStage or select(2, Evolution.Resolve(state.Level))
		local unlocked = state.Level >= stage.MinLevel
		textRow(stage.Name, Color3.fromHex(stage.Glow), 24)
		textRow("第 " .. index .. " 階  /  玩家 Lv." .. stage.MinLevel .. " 覺醒  /  " .. (index == current and "目前形態" or unlocked and "已覺醒" or "未覺醒預覽"), U.Colors.Muted, 13)
		local view = U.New("Frame", detail, { Name = "DragonPreview", Size = UDim2.new(1, -4, 0, mobile and 250 or 340), BackgroundColor3 = Color3.fromHex("131A30"), BorderSizePixel = 0 })
		U.Round(view, 16); U.Stroke(view, Color3.fromHex(stage.Glow), 0.25)
		ApprovedArt.Mount(view,stage.Id)
		textRow("騎龍與跟隨形態會使用同一階龍模型；升級後自動覺醒。",U.Colors.Muted,12)
		textRow(stage.Description, U.Colors.Text)
		local progress = Evolution.Progress(state.Level)
		local currentStage = Evolution.Stages[current]
		textRow("目前跟隨：" .. currentStage.Name .. "  ·  玩家 Lv." .. state.Level, U.Colors.Gold)
		textRow(progress.NextLevel and ("下一階在 Lv." .. progress.NextLevel .. " 覺醒，還差 " .. progress.Remaining .. " 級") or "已達最終覺醒：星穹龍皇", U.Colors.Cyan)
		local track = U.Frame(detail, "EvolutionProgress", { Size = UDim2.new(1, -4, 0, 10), BackgroundColor3 = U.Colors.Card })
		U.Round(track, 5)
		local fill = U.Frame(track, "Fill", { Size = UDim2.fromScale(progress.Fraction, 1), BackgroundColor3 = Color3.fromHex(currentStage.Glow) })
		U.Round(fill, 5)
		textRow("按F騎龍，WASD／搖桿移動，空白鍵上升、Q下降、Shift加速。跨島必須騎龍。", U.Colors.Muted, 13)
	end
	detail.CanvasPosition = oldScroll
end

local function entries()
	local out = {}
	if not state then return out end
	if activeTab == "Inventory" then
		local listed = {}
		for id, count in pairs(state.Inventory) do
			if count > 0 and C.Items[id] then listed[id]=true;table.insert(out, { Id = id, Name = C.Items[id].Name, Rarity = C.Items[id].Rarity, Item = id }) end
		end
		for id, count in pairs(state.PendingItems or {}) do
			if count>0 and C.Items[id] and not listed[id] then table.insert(out,{Id=id,Name=C.Items[id].Name,Rarity=C.Items[id].Rarity,Item=id}) end
		end
	elseif activeTab == "Shop" then
		for _, id in ipairs(C.ShopOrder) do
			local item = C.Items[C.Shop[id].Item]
			if C.Shop[id].Island==(player:GetAttribute("CurrentIsland") or "grassland") then table.insert(out, { Id = id, Name = item.Name, Rarity = item.Rarity, Item = C.Shop[id].Item }) end
		end
	elseif activeTab=="Map" then
		table.insert(out,{Id="world",Name="天空群島・世界地圖",Level=0,Color="B4DFF5"})
		for _,id in ipairs(C.IslandOrder) do local i=C.Islands[id];table.insert(out,{Id=id,Name=i.Name,Level=i.MinLevel,Color=i.Color}) end
	elseif activeTab == "Sets" then
		for _, id in ipairs(C.SetOrder) do table.insert(out, { Id = id, Name = C.Sets[id].Name, Rarity = C.Items[C.Sets[id].Items[1]].Rarity }) end
	elseif activeTab == "Dragon" then
		for i, stage in ipairs(Evolution.Stages) do table.insert(out, { Id = tostring(i), Name = stage.Name, Level = stage.MinLevel, Color = stage.Glow }) end
	else
		for _, id in ipairs(C.MonsterOrder) do table.insert(out, { Id = id, Name = C.Monsters[id].Name, Level = C.Monsters[id].Level }) end
	end
	local filtered = {}
	for _, entry in ipairs(out) do
		local haystack = entry.Name .. (entry.Item and C.SlotNames[C.Items[entry.Item].Slot] or "")..(activeTab=="Monsters" and (" "..C.Monsters[entry.Id].Region.." "..C.Monsters[entry.Id].Location) or "")
		local matchesText = searchText == "" or string.find(string.lower(haystack), string.lower(searchText), 1, true) ~= nil
		local matchesRarity = activeTab == "Monsters" or activeTab == "Dragon" or activeTab=="Map" or rarityFilter == "All" or entry.Rarity == rarityFilter
		local item=entry.Item and C.Items[entry.Item]
		local matchesCategory=category=="All" or not item
			or category=="Weapon" and item.Slot=="Weapon"
			or category=="Armor" and item.Slot~="Weapon"
			or category=="Owned" and ((state.Inventory[entry.Item] or 0)>0 or (state.PendingItems and (state.PendingItems[entry.Item] or 0)>0))
		if matchesText and matchesRarity and matchesCategory then table.insert(filtered, entry) end
	end
	table.sort(filtered, function(a, b)
		if activeTab == "Dragon" or activeTab=="Map" then return a.Level < b.Level end
		if sortMode == "Rarity" then
			local ar, br = a.Rarity and C.Rarities[a.Rarity].Rank or a.Level or 0, b.Rarity and C.Rarities[b.Rarity].Rank or b.Level or 0
			if ar ~= br then return ar > br end
		end
		return a.Name < b.Name
	end)
	return filtered
end
local layout
render = function(reset)
	local theme = U.Tabs[activeTab]
	heading.Text = tabNames[activeTab]
	heading.TextColor3, panelStroke.Color, accentLine.BackgroundColor3 = theme.Accent, theme.Accent, theme.Accent
	crest.Text, crest.TextColor3, crest.BackgroundColor3 = theme.Mark, theme.Accent, theme.Dark
	topGem.BackgroundColor3=theme.Accent
	panelGradient.Color = ColorSequence.new(theme.Dark:Lerp(U.Colors.Panel, 0.5), Color3.fromHex("111526"))
	list.ScrollBarImageColor3, detail.ScrollBarImageColor3 = theme.Accent, theme.Accent
	if state then
		local s = state.Stats
		wallet.Text = "Lv." .. state.Level .. "  ·  金幣 " .. state.Coins
		panelHint.Text = "ATK " .. s.Attack .. "  DEF " .. s.Defense .. "  HP " .. s.HP .. "  SPD " .. s.Speed .. "  |  " .. (state.Persistent and "自動存檔" or "測試：離線不保存")
	end
	for tab, button in pairs(navButtons) do
		button.TextColor3 = tab == activeTab and U.Tabs[tab].Accent or U.Colors.Muted
		local label=button:FindFirstChild("Caption")
		if label then label.TextColor3=button.TextColor3 end
		local border = button:FindFirstChildOfClass("UIStroke")
		if border then border.Transparency = tab == activeTab and 0.05 or 0.65 end
	end
	filterButton.Text = rarityFilter == "All" and "全部稀有度" or C.Rarities[rarityFilter].Name
	filterButton.Visible = activeTab ~= "Monsters" and activeTab ~= "Dragon" and activeTab~="Map"
	sortButton.Visible = activeTab ~= "Dragon" and activeTab~="Map"
	for key,button in pairs(categoryButtons) do
		button.TextColor3=category==key and theme.Accent or U.Colors.Muted
		button.BackgroundColor3=category==key and theme.Dark:Lerp(theme.Accent,.15) or U.Colors.Background
	end
	categories.Visible=activeTab=="Inventory" or activeTab=="Shop"
	actionDock.Visible=activeTab=="Inventory" or activeTab=="Shop"
	sortButton.Text = sortMode == "Rarity" and (activeTab == "Monsters" and "等級排序" or "稀有度排序") or "名稱排序"
	local oldScroll = list.CanvasPosition
	U.Clear(list)
	local rows = entries()
	local grid=activeTab=="Inventory" or activeTab=="Shop"
	if entryLayout then entryLayout:Destroy() end
	if grid then
		local width=list.AbsoluteSize.X
		local columns=mobile and 2 or 3
		local cellWidth=math.max(95,math.floor((width-24-(columns-1)*9)/columns))
		entryLayout=U.New("UIGridLayout",list,{SortOrder=Enum.SortOrder.LayoutOrder,CellPadding=UDim2.fromOffset(9,9),CellSize=UDim2.fromOffset(cellWidth,mobile and 152 or 185),FillDirectionMaxCells=columns})
	else entryLayout=U.List(list,8) end
	local selectionExists = false
	for _, entry in ipairs(rows) do if entry.Id == selected then selectionExists = true end end
	if reset or not selectionExists then
		selected = rows[1] and rows[1].Id or nil
		if activeTab == "Dragon" then
			local currentId = tostring(state and state.DragonStage or 1)
			for _, entry in ipairs(rows) do if entry.Id == currentId then selected = currentId end end
		end
		detail.CanvasPosition = Vector2.zero
	end
	for i, entry in ipairs(rows) do
		local accent = entry.Color and Color3.fromHex(entry.Color) or entry.Rarity and Color3.fromHex(C.Rarities[entry.Rarity].Color) or Color3.fromHex(C.Monsters[entry.Id].Color)
		local sub = ""
		if activeTab == "Inventory" then
			local item = C.Items[entry.Item]
			sub = C.SlotNames[item.Slot] .. "  ×" .. (state.Inventory[entry.Item] or 0) .. (state.Equipment[item.Slot] == entry.Item and "  ·  穿戴中" or "")
			if state.PendingItems and (state.PendingItems[entry.Item] or 0)>0 then sub..=" · 待領" end
		elseif activeTab == "Shop" then sub = C.Shop[entry.Id].Price .. " 金幣  ·  Lv." .. C.Shop[entry.Id].Level
		elseif activeTab == "Sets" then
			local count = 0
			for _, id in ipairs(C.Sets[entry.Id].Items) do if state.Discovered[id] then count += 1 end end
			sub = "已發現 " .. count .. "/4  ·  穿戴 " .. (state.Stats.Sets[entry.Id] or 0) .. "/4"
		elseif activeTab=="Map" then sub=entry.Id=="world" and "七座主島・騎龍飛行" or ("Lv."..entry.Level.."  ·  "..(state.Level>=entry.Level and "已解鎖" or "尚未解鎖"))
		elseif activeTab == "Dragon" then sub = "Lv." .. entry.Level .. " 覺醒  ·  " .. (state.Level >= entry.Level and "已解鎖" or "未解鎖預覽")
		else sub = "Lv." .. entry.Level .. "  ·  擊敗 " .. (state.Kills[entry.Id] or 0) .. " 次" end
		local b = U.Button(list, "", function() selected = entry.Id; detail.CanvasPosition = Vector2.zero; render(false) end,
			{ Name = entry.Id, LayoutOrder = i, Size = UDim2.new(1, -6, 0, 88), BackgroundColor3 = entry.Id == selected and theme.Dark:Lerp(accent, 0.2) or theme.Dark })
		U.Gradient(b, Color3.new(1, 1, 1), Color3.fromHex("8891B1"), 25)
		local border = b:FindFirstChildOfClass("UIStroke")
		if border then border.Color, border.Transparency = accent, entry.Id == selected and 0.1 or 0.7 end
		local stripe = U.Frame(b, "RarityAccent", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 4, 1, -20), BackgroundColor3 = accent })
		U.Round(stripe, 2)
		local inset = entry.Item and 76 or 16
		if grid then
			U.Ornate(b,entry.Id==selected and theme.Accent or accent)
			local icon=U.New("ViewportFrame",b,{Name="ItemIcon",Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-16,1,-62),BackgroundTransparency=1})
			if ApprovedArt.Has(entry.Item) then
				local pos,size=icon.Position,icon.Size;icon:Destroy()
				ApprovedArt.Mount(b,entry.Item,{Name="ItemIcon",Position=pos,Size=size})
			else Preview.Build(icon,C.Items[entry.Item].Slot,accent,false,entry.Item) end
			U.Label(b,entry.Name,{Position=UDim2.new(0,7,1,-54),Size=UDim2.new(1,-14,0,29),TextXAlignment=Enum.TextXAlignment.Center,TextColor3=accent,Font=Enum.Font.GothamBold,TextSize=mobile and 12 or 14})
			U.Label(b,sub,{Position=UDim2.new(0,5,1,-25),Size=UDim2.new(1,-10,0,20),TextXAlignment=Enum.TextXAlignment.Center,TextColor3=U.Colors.Gold,TextSize=11})
		else
			U.Label(b, entry.Name, { Position = UDim2.fromOffset(inset, 9), Size = UDim2.new(1, -inset - 10, 0, 36), TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 15 })
			U.Label(b, sub, { Position = UDim2.fromOffset(inset, 53), Size = UDim2.new(1, -inset - 10, 0, 24), TextColor3 = U.Colors.Muted, TextSize = 12 })
		end
	end
	if #rows == 0 then
		local empty=state and "沒有符合條件的項目。" or "正在載入資料…"
		local island=player:GetAttribute("CurrentIsland")
		if state and activeTab=="Shop" and (island=="shadow_abyss" or island=="dragon_sanctuary") then empty="本島套裝僅由怪物掉落。\n到怪物圖鑑查看所在地與機率；\n商人仍可回收重複裝備。" end
		U.Label(list,empty,{Size=UDim2.new(1,-8,0,100)})
	end
	list.CanvasPosition = reset and Vector2.zero or oldScroll
	renderDetail()
	if modal.Visible then updateModal() end
end
filterButton = U.Button(panel, "全部稀有度", function()
	local index = table.find(filterOrder, rarityFilter) or 1
	rarityFilter = filterOrder[index % #filterOrder + 1]
	render(true)
end, { Name = "RarityFilter", Position = UDim2.new(0.5, 0, 0, 109), Size = UDim2.new(0.25, -7, 0, 32), TextSize = 12 })
sortButton = U.Button(panel, "稀有度排序", function() sortMode = sortMode == "Rarity" and "Name" or "Rarity"; render(false) end,
	{ Name = "Sort", Position = UDim2.new(0.75, 0, 0, 109), Size = UDim2.new(0.25, -14, 0, 32), TextSize = 12 })
for i,data in ipairs({{"All","全部"},{"Weapon","武器"},{"Armor","防具"},{"Owned","已持有"}}) do
	categoryButtons[data[1]]=U.Button(categories,data[2],function() category=data[1];render(true) end,{Position=UDim2.new((i-1)/4,3,0,0),Size=UDim2.new(.25,-6,1,0),TextSize=13})
end
search:GetPropertyChangedSignal("Text"):Connect(function() searchText = search.Text:sub(1, 96); render(true) end)
for index, tab in ipairs({ "Inventory", "Sets", "Monsters", "Shop", "Dragon", "Map" }) do
	local theme = U.Tabs[tab]
	navButtons[tab] = U.Button(menu, "", function()
		if activeTab == tab and panel.Visible then panel.Visible = false; return end
		activeTab, selected = tab, nil
		rarityFilter,category = "All","All"
		search.Text = ""
		panel.Visible = true
		if layout then layout() end
		render(true)
	end, { Name = tab .. "Button", Position = UDim2.new((index - 1) / 6, 3, 0, 0), Size = UDim2.new(1/6, -6, 1, 0), TextSize = 14, BackgroundColor3 = theme.Dark })
	local border = navButtons[tab]:FindFirstChildOfClass("UIStroke")
	if border then border.Color = theme.Accent end
	U.Ornate(navButtons[tab],theme.Accent)
	local emblem={Inventory="flame_armor",Sets="flame_helmet",Monsters="void_dragon",Shop="flame_sword",Dragon="emperor_head"}
	if tab=="Map" then U.Label(navButtons[tab],"✦",{Position=UDim2.fromScale(0,.03),Size=UDim2.fromScale(1,.6),TextSize=29,TextXAlignment=Enum.TextXAlignment.Center,TextColor3=theme.Accent}) else ApprovedArt.Mount(navButtons[tab],emblem[tab],{Name="Emblem",Position=UDim2.fromScale(.16,.01),Size=UDim2.fromScale(.68,.68)}) end
	U.Label(navButtons[tab],theme.Label,{Name="Caption",Position=UDim2.fromScale(0,.68),Size=UDim2.fromScale(1,.3),TextXAlignment=Enum.TextXAlignment.Center,TextColor3=theme.Accent,TextSize=14,Font=Enum.Font.GothamBold})
end

local lastAttack = -math.huge
local function attackNearest()
	if modal.Visible or UserInputService:GetFocusedTextBox() then return end
	if os.clock() - lastAttack < 0.56 then return end -- UX only; server has its own cooldown.
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("DragonWorld")
	local monsters = world and world:FindFirstChild("Monsters")
	if not hrp or not monsters then notify("角色或怪物尚未準備好。", true); return end
	if player:GetAttribute("IsRiding")==true then notify("先下龍再攻擊。",true);return end
	local nearest, best = nil, 22
	for _, model in ipairs(monsters:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart and (model:GetAttribute("HP") or 0) > 0 then
			local distance = (hrp.Position - model.PrimaryPart.Position).Magnitude
			if distance < best then nearest, best = model, distance end
		end
	end
	if not nearest then notify("請靠近怪物（22 格內）再攻擊。", true); return end
	lastAttack = os.clock()
	send("Attack", nearest:GetAttribute("MonsterId"))
end
local attackButton = U.Button(gui, "斬擊  [E / 手把 X]", attackNearest, { Name = "AttackButton", AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(216, 38), BackgroundColor3 = Color3.fromHex("6A437F") })
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then attackNearest() end
	if input.KeyCode == Enum.KeyCode.B then activeTab="Inventory";rarityFilter,category="All","All";search.Text="";panel.Visible=not panel.Visible;layout();render(true) end
	if input.KeyCode==Enum.KeyCode.M then if activeTab=="Map" and panel.Visible then panel.Visible=false else activeTab="Map";selected="world";rarityFilter="All";search.Text="";panel.Visible=true;layout();render(true) end end
end)
local healthConnection, maxHealthConnection
local function bindCharacter(ch)
	if healthConnection then healthConnection:Disconnect() end
	if maxHealthConnection then maxHealthConnection:Disconnect() end
	local h = ch:WaitForChild("Humanoid")
	local function health()
		local xpText = state and ("  EXP " .. state.XP .. "/" .. C.RequiredXP(state.Level)) or ""
		hpLabel.Text = "HP " .. math.ceil(h.Health) .. "/" .. math.ceil(h.MaxHealth) .. xpText
	end
	healthConnection = h.HealthChanged:Connect(health)
	maxHealthConnection = h:GetPropertyChangedSignal("MaxHealth"):Connect(health)
	health()
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end

update.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then return end
	if packet.Kind=="Hint" then if packet.Tab and tabNames[packet.Tab] then activeTab=packet.Tab;selected=nil;rarityFilter,category="All","All";search.Text="";panel.Visible=true;layout();render(true) end;notify(packet.Text or "");return end
	if packet.State and (not state or packet.State.Revision >= state.Revision) then
		local oldStage = state and state.DragonStage
		state = packet.State
		render(false)
		if oldStage and state.DragonStage and state.DragonStage > oldStage then
			local stage = Evolution.Stages[state.DragonStage]
			task.delay(0.15, function() notify("龍之覺醒！\n你的夥伴進化為「" .. stage.Name .. "」！") end)
		end
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then hpLabel.Text = "HP " .. math.ceil(h.Health) .. "/" .. math.ceil(h.MaxHealth) .. "  EXP " .. state.XP .. "/" .. C.RequiredXP(state.Level) end
	end
	if packet.Kind ~= "Reply" then return end
	pending[packet.Id] = nil
	if purchasePending == packet.Id then purchasePending = nil end
	if packet.Code == "SYNC" then return end
	if packet.Code == "HIT" and packet.Notice then
		attackButton.Text = "命中 −" .. packet.Notice.Damage
		task.delay(0.45, function() attackButton.Text = "斬擊  [E / 手把 X]" end)
	elseif packet.Code == "LOOT" and packet.Notice then
		local n = packet.Notice
		notify("擊敗怪物！ +" .. n.Coins .. " 金幣  +" .. n.XP .. " EXP" .. (n.Item and ("\n獲得「" .. C.Items[n.Item].Name .. "」") or "")
			.. (n.Pending and "\n已放入待領裝備。" or "").. (n.Overflow and "\n背包與待領都已滿。" or ""))
	elseif packet.Code ~= "COOLDOWN" then notify(messages[packet.Code] or "請求無法完成，請重新同步。", not packet.Ok) end
end)

layout = function()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	mobile = size.X < 720
	actionDock.Visible=activeTab=="Shop" or activeTab=="Inventory"
	local width = math.min(1100, size.X - 24)
	local height = math.min(720, size.Y - 240)
	panel.Size = UDim2.fromOffset(width, math.max(170, height))
	menu.Size = UDim2.new(0, math.min(1100, size.X - 24), 0, mobile and 72 or 88)
	attackButton.Position=UDim2.new(.5,0,1,mobile and -86 or -104)
	if mobile then
		list.Position, list.Size = UDim2.new(), UDim2.new(1, 0, 0.43, -5)
		detail.Position, detail.Size = UDim2.new(0, 0, 0.43, 5), UDim2.new(1, 0, 0.57, actionDock.Visible and -62 or -5)
		actionDock.Position,actionDock.Size=UDim2.new(0,6,1,0),UDim2.new(1,-12,0,44)
		title.TextSize, subtitle.Visible, wallet.TextSize = 20, false, 13
		panelHint.TextSize = 10
	else
		local split=(activeTab=="Shop" or activeTab=="Inventory") and .59 or .34
		list.Position, list.Size = UDim2.new(), UDim2.new(split, -6, 1, 0)
		detail.Position, detail.Size = UDim2.new(split, 6, 0, 0), UDim2.new(1-split, -6, 1, actionDock.Visible and -58 or 0)
		actionDock.Position,actionDock.Size=UDim2.new(split,12,1,-2),UDim2.new(1-split,-18,0,44)
		title.TextSize, subtitle.Visible, wallet.TextSize = 24, true, 16
		panelHint.TextSize = 12
	end
	if render then render(false) end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout(); render(true);panel.Visible=false
player:GetAttributeChangedSignal("CurrentIsland"):Connect(function()if state then render(true) end end)
-- Connect listener before requesting state; periodic Sync covers join/load races.
task.spawn(function()
	while not state do send("Sync"); task.wait(2) end
end)
TweenService:Create(panel, TweenInfo.new(0.3), { BackgroundTransparency = 0.03 }):Play()
