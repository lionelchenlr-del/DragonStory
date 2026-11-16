-- Only the server's saved player level can change the replicated appearance tier.
local Service = {}
function Service.new(parent, Evolution, factory)
	local create = factory or Instance.new
	local folder = create("Folder")
	folder.Name, folder.Parent = "Companions", parent
	local S = { Descriptors = {} }
	function S.Refresh(player, level)
		local _, index = Evolution.Resolve(level)
		local descriptor = S.Descriptors[player]
		if not descriptor then
			descriptor = create("Folder")
			descriptor.Name = "Dragon_" .. player.UserId
			descriptor:SetAttribute("OwnerUserId", player.UserId)
			descriptor:SetAttribute("StageIndex", index)
			descriptor.Parent = folder
			S.Descriptors[player] = descriptor
		end
		descriptor:SetAttribute("PlayerLevel", level)
		descriptor:SetAttribute("StageIndex", index)
	end
	function S.Remove(player)
		local descriptor = S.Descriptors[player]
		if descriptor then descriptor:Destroy(); S.Descriptors[player] = nil end
	end
	return S
end
return Service
