-- OPTIONAL. Paste into a new LocalScript in StarterPlayerScripts, in a fresh
-- test place only. Not included in the delivered place / Rojo tree by default.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local remotes = ReplicatedStorage:WaitForChild("DragonRemotes")
local responses = {}
local connection = remotes.Update.OnClientEvent:Connect(function(packet)
	if packet.Id then responses[packet.Id] = packet end
end)
local function exchange(payload, silent)
	payload.Id = payload.Id or HttpService:GenerateGUID(false)
	remotes.Request:FireServer(payload)
	local deadline = os.clock() + (silent and 1 or 6)
	while not responses[payload.Id] and os.clock() < deadline do task.wait(0.05) end
	local result = responses[payload.Id]
	responses[payload.Id] = nil
	if not silent then assert(result, "No server response: " .. payload.Action) end
	return result
end
local baseline
for _ = 1, 20 do
	local response = exchange({ Action = "Sync" }, true)
	if response and response.State then baseline = response.State; break end
	task.wait(1)
end
assert(baseline, "Profile not ready")
assert(baseline.Level == 1 and baseline.Coins == 600, "Use a fresh volatile Studio profile; don't play during the probe")
local function sameEconomy(s)
	assert(s.Coins == baseline.Coins and s.Revision == baseline.Revision, "Unauthorized economy change")
	assert(s.DragonStage == baseline.DragonStage, "Unauthorized dragon evolution")
	for id, n in pairs(s.Inventory) do assert(baseline.Inventory[id] == n, "Unexpected inventory grant") end
	for id, n in pairs(baseline.Inventory) do assert(s.Inventory[id] == n, "Unexpected inventory removal") end
end
local malicious = {
	{ Action = "Buy", Key = "flame_blade", Quantity = 1, Price = 0 },
	{ Action = "Buy", Key = "flame_blade", Quantity = -1 },
	{ Action = "Buy", Key = "flame_blade", Quantity = 0/0 },
	{ Action = "Attack", Key = "slime_1", Damage = 999999 },
	{ Action = "GrantLoot", Key = "void_sword" },
	{ Action = "Save", Key = "coins", Coins = 999999 },
	{ Action = "Evolve", Key = "astral" },
	{ Action = "Sync", DragonStage = 4 },
}
for _, payload in ipairs(malicious) do
	assert(exchange(payload, true) == nil, "Malformed request should be silently discarded")
	sameEconomy(exchange({ Action = "Sync" }).State)
end
local unowned = exchange({ Action = "Equip", Key = "void_sword" })
assert(not unowned.Ok and unowned.Code == "NOT_OWNED", "Unowned item must be rejected")
sameEconomy(unowned.State)
local wrongSlot = exchange({ Action = "Unequip", Key = "Coins" })
assert(not wrongSlot.Ok and wrongSlot.Code == "BAD_SLOT", "Unknown slot must be rejected")
sameEconomy(wrongSlot.State)
local far = exchange({ Action = "Attack", Key = "slime_1" })
assert(not far.Ok and far.Code == "TOO_FAR", "Starting spawn should be out of attack range")
local badOffer = exchange({ Action = "Buy", Key = "fake_offer", Quantity = 1 })
assert(not badOffer.Ok, "Unknown offer cannot be bought (shop proximity may reject first)")
sameEconomy(exchange({ Action = "Sync" }).State)
local replayId = HttpService:GenerateGUID(false)
exchange({ Id = replayId, Action = "Sync" })
local replay = exchange({ Id = replayId, Action = "Sync" })
assert(not replay.Ok and replay.Code == "DUPLICATE", "Replay ID should be rejected")
sameEconomy(replay.State)
-- Flood only harmless Syncs. A following Sync recovers after the bucket refills.
for _ = 1, 40 do remotes.Request:FireServer({ Id = HttpService:GenerateGUID(false), Action = "Sync" }) end
task.wait(3)
sameEconomy(exchange({ Action = "Sync" }).State)
connection:Disconnect()
print("[Dragon Security Probe] PASS: malformed inputs, unowned equip, slots, range, replay, flood; no economy changes")
