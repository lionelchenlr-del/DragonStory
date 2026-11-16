local ProfileStore = {}
local function copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
	return out
end
function ProfileStore.new(Domain, Settings, dependencies)
	-- Optional dependency injection lets the same lock/save code run in offline tests.
	local services = dependencies or {
		DataStoreService = game:GetService("DataStoreService"),
		HttpService = game:GetService("HttpService"),
		RunService = game:GetService("RunService"),
	}
	local DataStoreService, HttpService, RunService = services.DataStoreService, services.HttpService, services.RunService
	local now = services.Time or os.time
	local wait = services.Wait or task.wait
	local report = services.Warn or warn
	local P = { Entries = {} }
	P.Persistent = not RunService:IsStudio() or Settings.StudioPersistence
	local store = nil
	if P.Persistent then
		store = DataStoreService:GetDataStore(RunService:IsStudio() and Settings.StudioDataStoreName or Settings.DataStoreName)
	end
	function P.Load(userId)
		local token = HttpService:GenerateGUID(false)
		local entry = { Token = token, Saving = false, Closing = false, Lost = false, Expires = math.huge }
		if not P.Persistent then
			entry.Data = Domain.Fresh()
			P.Entries[userId] = entry
			return entry
		end
		for attempt = 1, 3 do
			local rejection = nil
			local ok, result = pcall(function()
				return store:UpdateAsync("u_" .. userId, function(old)
					rejection = nil -- Transform may be called repeatedly by Roblox.
					if old ~= nil and (type(old) ~= "table" or old.Schema ~= 1 or type(old.Data) ~= "table") then
						rejection = "UNSUPPORTED_DATA"; return nil
					end
					local lock = old and old.Lock
					if lock and (type(lock) ~= "table" or type(lock.Token) ~= "string" or type(lock.Expires) ~= "number") then
						rejection = "UNSUPPORTED_DATA"; return nil
					end
					if lock and lock.Token ~= token and lock.Expires > now() then rejection = "SESSION_LOCKED"; return nil end
					local data, reason = Domain.Normalize(old and old.Data)
					if not data then rejection = reason; return nil end
					return { Schema = 1, Data = data, Lock = { Token = token, Expires = now() + Settings.LeaseSeconds }, CommitToken = token }
				end)
			end)
			if ok and result and result.Lock and result.Lock.Token == token then
				entry.Data = Domain.Normalize(result.Data)
				entry.Expires = result.Lock.Expires
				P.Entries[userId] = entry
				return entry
			end
			if ok and rejection then return nil, rejection end
			report("[Dragon] Profile load failed", userId, attempt)
			if attempt < 3 then wait(attempt * 2) end
		end
		return nil, "LOAD_FAILED"
	end
	function P.Writable(userId)
		local e = P.Entries[userId]
		return e ~= nil and not e.Closing and not e.Lost and now() < e.Expires - 15
	end
	function P.Save(userId, release)
		local e = P.Entries[userId]
		if not e or e.Saving or e.Lost then return false end
		if not P.Persistent then return true end
		e.Saving = true
		local snapshot = copy(e.Data) -- Snapshot before any network yield.
		local saved = false
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:UpdateAsync("u_" .. userId, function(old)
					if type(old) ~= "table" or old.Schema ~= 1 or not old.Lock or old.Lock.Token ~= e.Token then return nil end
					local lock = nil
					if not release then lock = { Token = e.Token, Expires = now() + Settings.LeaseSeconds } end
					return { Schema = 1, Data = snapshot, Lock = lock, CommitToken = e.Token }
				end)
			end)
			if ok then
				if result and result.CommitToken == e.Token then
					e.Expires = result.Lock and result.Lock.Expires or 0
					saved = true
				else
					e.Lost = true -- Never overwrite a different session.
				end
				break
			end
			report("[Dragon] Profile save failed", userId, attempt)
			if attempt < 3 then wait(attempt * 2) end
		end
		e.Saving = false
		return saved
	end
	function P.Close(userId)
		local e = P.Entries[userId]
		if not e or e.CloseStarted then return end
		e.CloseStarted = true
		e.Closing = true -- Prevent new purchases/rewards while waiting for an autosave.
		while e.Saving do wait(0.05) end
		local saved = P.Save(userId, true)
		if not saved then report("[Dragon] Final save not confirmed", userId) end
		if P.Entries[userId] == e then P.Entries[userId] = nil end
	end
	return P
end
return ProfileStore
