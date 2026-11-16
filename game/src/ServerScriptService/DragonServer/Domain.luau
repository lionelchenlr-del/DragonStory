-- All economy, XP, equipment and loot mutations are pure, bounded and non-yielding.
local Domain={}
function Domain.new(C,Settings)
 local D={}
 local function integer(n,fallback,lo,hi)
  if type(n)~="number" or n~=n or n==math.huge or n==-math.huge then return fallback end
  return math.clamp(math.floor(n),lo,hi)
 end
 function D.Fresh()
  return {Version=2,Revision=0,Coins=600,Level=1,XP=0,HomeIsland="grassland",CheckpointSlot=1,Inventory={training_sword=1,traveler_armor=1},
   Equipment={Weapon="training_sword",Armor="traveler_armor"},Discovered={training_sword=true,traveler_armor=true},
   Kills={},QuestClaims={},PendingItems={},Secrets={}}
 end
 function D.Normalize(raw)
  if raw==nil then return D.Fresh() end
  if type(raw)~="table" or (raw.Version~=1 and raw.Version~=2) then return nil,"UNSUPPORTED_DATA" end
  local p={Version=2,Revision=integer(raw.Revision,0,0,1e12),Coins=integer(raw.Coins,0,0,Settings.MaxCoins),
   Level=integer(raw.Level,1,1,C.MaxLevel),XP=0,Inventory={},Equipment={},Discovered={},Kills={},QuestClaims={},PendingItems={},Secrets={}}
  p.XP=p.Level==C.MaxLevel and 0 or integer(raw.XP,0,0,C.RequiredXP(p.Level)-1)
  p.HomeIsland=type(raw.HomeIsland)=="string" and C.Islands[raw.HomeIsland] and p.Level>=C.Islands[raw.HomeIsland].MinLevel and raw.HomeIsland or "grassland"
  p.CheckpointSlot=integer(raw.CheckpointSlot,1,1,2)
  for id in pairs(C.Items) do
   local n=type(raw.Inventory)=="table" and integer(raw.Inventory[id],0,0,C.MaxStack) or 0
   if n>0 then p.Inventory[id]=n end
   local pending=type(raw.PendingItems)=="table" and integer(raw.PendingItems[id],0,0,Settings.MaxPendingPerItem) or 0
   if pending>0 then p.PendingItems[id]=pending end
   if n>0 or pending>0 or (type(raw.Discovered)=="table" and raw.Discovered[id]==true) then p.Discovered[id]=true end
  end
  for _,slot in ipairs(C.Slots) do
   local id=type(raw.Equipment)=="table" and raw.Equipment[slot]
   if type(id)=="string" and C.Items[id] and C.Items[id].Slot==slot and p.Inventory[id] and p.Level>=C.Items[id].Level then p.Equipment[slot]=id end
  end
  for id in pairs(C.Monsters) do
   local n=type(raw.Kills)=="table" and integer(raw.Kills[id],0,0,1e9) or 0
   if n>0 then p.Kills[id]=n end
  end
  for id in pairs(C.Quests) do if type(raw.QuestClaims)=="table" and raw.QuestClaims[id]==true then p.QuestClaims[id]=true end end
  for _,id in ipairs(C.IslandOrder) do for _,suffix in ipairs({"secret","relic"}) do local key=id.."_"..suffix;if type(raw.Secrets)=="table" and raw.Secrets[key]==true then p.Secrets[key]=true end end end
  return p
 end
 function D.Stats(p)
  local s={Attack=12+(p.Level-1)*2,HP=100+(p.Level-1)*10,Defense=0,Speed=16,Sets={}}
  for _,slot in ipairs(C.Slots) do local item=C.Items[p.Equipment[slot]]
   if item then
    for _,stat in ipairs({"Attack","HP","Defense","Speed"}) do s[stat]+=item[stat] or 0 end
    if item.Set then s.Sets[item.Set]=(s.Sets[item.Set] or 0)+1 end
   end
  end
  local atk,hp=0,0
  for id,count in pairs(s.Sets) do for _,bonus in ipairs(C.Sets[id].Bonuses) do if count>=bonus.Count then
   for _,stat in ipairs({"Attack","HP","Defense","Speed"}) do s[stat]+=bonus[stat] or 0 end
   atk+=bonus.AttackPercent or 0;hp+=bonus.HPPercent or 0
  end end end
  s.Attack=math.floor(s.Attack*(1+atk));s.HP=math.floor(s.HP*(1+hp));s.Speed=math.min(30,s.Speed)
  return s
 end
 local function quantityOK(n) return type(n)=="number" and n==n and n%1==0 and n>=1 and n<=10 end
 function D.Purchase(p,offerId,quantity)
  local offer=C.Shop[offerId];if not offer then return false,"BAD_OFFER" end
  if not quantityOK(quantity) then return false,"BAD_QUANTITY" end
  if p.Level<math.max(offer.Level,C.Items[offer.Item].Level) then return false,"LEVEL_LOW" end
  local count=p.Inventory[offer.Item] or 0
  if count+quantity>C.MaxStack then return false,"STACK_FULL" end
  local cost=offer.Price*quantity;if p.Coins<cost then return false,"NO_COINS" end
  p.Coins-=cost;p.Inventory[offer.Item]=count+quantity;p.Discovered[offer.Item]=true
  return true,"PURCHASED"
 end
 function D.Equip(p,id)
  local item=C.Items[id];if not item then return false,"BAD_ITEM" end
  if not p.Inventory[id] or p.Inventory[id]<1 then return false,"NOT_OWNED" end
  if p.Level<item.Level then return false,"LEVEL_LOW" end
  p.Equipment[item.Slot]=id;return true,"EQUIPPED"
 end
 function D.Unequip(p,slot)
  if not C.SlotNames[slot] then return false,"BAD_SLOT" end
  p.Equipment[slot]=nil;return true,"UNEQUIPPED"
 end
 function D.AddXP(p,xp)
  if p.Level==C.MaxLevel then p.XP=0;return end
  p.XP+=xp
  while p.Level<C.MaxLevel and p.XP>=C.RequiredXP(p.Level) do p.XP-=C.RequiredXP(p.Level);p.Level+=1 end
  if p.Level==C.MaxLevel then p.XP=0 end
 end
 function D.SelectDrop(monsterId,roll)
  assert(type(roll)=="number" and roll%1==0 and roll>=1 and roll<=10000,"server roll must be integer 1..10000")
  local drops=assert(Settings.DropTables[monsterId],"unknown monster");local cumulative=0
  for k,id in ipairs(drops.Items) do cumulative+=drops.Weights[k];if roll<=cumulative then return id end end
  return nil
 end
 function D.Reward(p,monsterId,roll,level)
  local monster=assert(C.Monsters[monsterId],"unknown monster")
  local stats=C.MonsterStats(monsterId,level or monster.Level)
  local notice={Coins=stats.Coins,XP=stats.XP}
  p.Coins=math.min(Settings.MaxCoins,p.Coins+stats.Coins)
  p.Kills[monsterId]=math.min(1e9,(p.Kills[monsterId] or 0)+1);D.AddXP(p,stats.XP)
  local id=D.SelectDrop(monsterId,roll)
  if id then
   p.Discovered[id]=true;notice.Item=id
   if (p.Inventory[id] or 0)<C.MaxStack then p.Inventory[id]=(p.Inventory[id] or 0)+1
   elseif (p.PendingItems[id] or 0)<Settings.MaxPendingPerItem then
    p.PendingItems[id]=(p.PendingItems[id] or 0)+1;notice.Pending=true
   else notice.Item=nil;notice.Overflow=true end
  end
  return notice
 end
 function D.ClaimPending(p,id)
  if not C.Items[id] then return false,"BAD_ITEM" end
  local pending=p.PendingItems[id] or 0
  local amount=math.min(pending,C.MaxStack-(p.Inventory[id] or 0))
  if amount<=0 then return false,pending>0 and "STACK_FULL" or "NOT_PENDING" end
  p.Inventory[id]=(p.Inventory[id] or 0)+amount
  p.PendingItems[id]=pending>amount and pending-amount or nil
  return true,"CLAIMED"
 end
 function D.Sell(p,id,quantity)
  local item=C.Items[id];if not item then return false,"BAD_ITEM" end
  if not quantityOK(quantity) then return false,"BAD_QUANTITY" end
  local count=p.Inventory[id] or 0
  if count<quantity then return false,"NOT_OWNED" end
  if p.Equipment[item.Slot]==id and count-quantity<1 then return false,"IN_USE" end
  p.Inventory[id]=count>quantity and count-quantity or nil
  p.Coins=math.min(Settings.MaxCoins,p.Coins+quantity*(item.Rarity=="Common" and 10 or 30+item.Level*12))
  return true,"SOLD"
 end
 function D.ClaimQuest(p,id)
  local q=C.Quests[id];if not q then return false,"BAD_QUEST" end
  if p.QuestClaims[id] then return false,"QUEST_CLAIMED" end
  if p.Level<C.Islands[q.Island].MinLevel then return false,"LEVEL_LOW" end
  if (p.Kills[q.Monster] or 0)<q.Count then return false,"QUEST_INCOMPLETE" end
  p.QuestClaims[id]=true;p.Coins=math.min(Settings.MaxCoins,p.Coins+q.Coins);D.AddXP(p,q.XP)
  return true,"QUEST_REWARD",{Coins=q.Coins,XP=q.XP}
 end
 function D.Gather(p,island)
  local i=C.Islands[island];if not i then return false,"NO_ISLAND" end
  if p.Level<i.MinLevel then return false,"LEVEL_LOW" end
  local coins=25+i.MinLevel*3;p.Coins=math.min(Settings.MaxCoins,p.Coins+coins)
  return true,"GATHERED",{Coins=coins,XP=0}
 end
 function D.Secret(p,island,suffix)
  local i=C.Islands[island];if not i or (suffix~="secret" and suffix~="relic") then return false,"BAD_SECRET" end
  if p.Level<i.MinLevel then return false,"LEVEL_LOW" end
  local key=island.."_"..suffix;if p.Secrets[key] then return false,"SECRET_CLAIMED" end
  p.Secrets[key]=true;local coins=200+i.MinLevel*8;local xp=math.floor(C.RequiredXP(i.MinLevel)*.6)
  p.Coins=math.min(Settings.MaxCoins,p.Coins+coins);D.AddXP(p,xp)
  return true,"SECRET_REWARD",{Coins=coins,XP=xp}
 end
 return D
end
return Domain

