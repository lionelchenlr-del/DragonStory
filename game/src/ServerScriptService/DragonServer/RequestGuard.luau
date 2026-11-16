local Guard={}
function Guard.new(now) return {Tokens=16,Last=now,Seen={},Order={}} end
function Guard.Allow(g,now)
 g.Tokens=math.min(16,g.Tokens+math.max(0,now-g.Last)*8);g.Last=now
 if g.Tokens<1 then return false end;g.Tokens-=1;return true
end
function Guard.Validate(r)
 if type(r)~="table" then return false end
 local allowed={Id=true,Action=true,Key=true,Quantity=true};local count=0
 for k in pairs(r) do count+=1;if count>4 or not allowed[k] then return false end end
 if type(r.Id)~="string" or #r.Id<1 or #r.Id>48 or not r.Id:match("^[%w_%-]+$") then return false end
 if r.Action=="Sync" or r.Action=="Ride" then return r.Key==nil and r.Quantity==nil end
 local valid={Buy=true,Equip=true,Unequip=true,Attack=true,Sell=true,ClaimPending=true,ClaimQuest=true}
 if not valid[r.Action] then return false end
 if type(r.Key)~="string" or #r.Key<1 or #r.Key>80 or not r.Key:match("^[%w_%-]+$") then return false end
 if r.Action=="Buy" or r.Action=="Sell" then local n=r.Quantity;return type(n)=="number" and n==n and n%1==0 and n>=1 and n<=10 end
 return r.Quantity==nil
end
function Guard.Remember(g,id)
 if g.Seen[id] then return false end
 g.Seen[id]=true;table.insert(g.Order,id)
 if #g.Order>128 then g.Seen[table.remove(g.Order,1)]=nil end
 return true
end
return Guard

