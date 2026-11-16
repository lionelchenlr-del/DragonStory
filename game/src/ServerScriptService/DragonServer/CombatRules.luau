-- One server-owned life can cross the death boundary only once.
local Combat = {}
function Combat.Apply(target, damage)
	if target.Dead then return false, false end
	assert(type(damage) == "number" and damage > 0 and damage < math.huge, "invalid server damage")
	target.HP = math.max(0, target.HP - damage)
	local killed = target.HP == 0
	if killed then target.Dead = true end
	return true, killed
end
return Combat
