require "Prodiction"

if myHero.charName ~= "Orianna" or not VIP_USER then return end

local ballPos = myHero
enemyHealth = {}

local InterruptList = 
	{
	  ["Katarina"] = "KatarinaR",
	  ["Malzahar"] = "AlZaharNetherGrasp",
	  ["Warwick"] = "InfiniteDuress",
	  ["Velkoz"] = "VelkozR",
	  ["MissFortune"] = "MissFortuneR", --not working
	  ["Caitlyn"] = "CaitlynR" -- not working
	}

local Qradius = 80
local Wradius = 245
local Eradius = 80
local Rradius = 380

local Qrange = 825
local Erange = 1095

local Qdelay = 0
local Wdelay = 0.25
local Edelay = 0.25
local Rdelay = 0.6

local BallSpeed = 1200
local BallSpeedE = 1700

levelSequenceQ = {1,2,3,1,1,4,1,2,1,2,4,2,2,3,3,4,3,3}
levelSequenceW = {1,2,3,2,2,4,2,1,2,1,4,1,1,3,3,4,3,3}

combo = {_Q, _W, _R}

local Rdamage = {150, 225, 300}
local Qdamage = {60, 90, 120, 150, 180}
local Wdamage = {70, 115, 160, 205, 250}


local LastChampionSpell = {}

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY, 1200)

function OnLoad()

	PrintChat("Prodiction-Orianna loaded - Prodiction v" .. Prodiction.GetVersion() .. " loaded")
	Menu = scriptConfig("Orianna", "Orianna")

		Menu:addSubMenu("Combo", "Combo")
		Menu.Combo:addParam("UseQ", "Use Q", SCRIPT_PARAM_ONOFF , true)
		Menu.Combo:addParam("UseW1", "Use W", SCRIPT_PARAM_ONOFF , true)
		Menu.Combo:addParam("UseW", "Use W if it will hit at least", SCRIPT_PARAM_SLICE, 1, 1, 5)
		Menu.Combo:addParam("UseR", "Use R if it will hit at least", SCRIPT_PARAM_SLICE, 3, 1, 5)
		Menu.Combo:addParam("Enabled", "Normal combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)

		Menu:addSubMenu("E", "E")
		Menu.E:addParam("UseE", "Use E for deepest ally in enemies", SCRIPT_PARAM_ONOFF, true)
		Menu.E:addParam("UseE2", "Force self shield if enemy is in range", SCRIPT_PARAM_ONOFF, true)
		Menu.E:addParam("UseE2Range", "Range:", SCRIPT_PARAM_SLICE, 500, 0, 700)

		Menu:addSubMenu("Block", "Block")
		Menu.Block:addParam("Block", "Block ultimate if it will hit nothing", SCRIPT_PARAM_ONOFF, true)
		Menu.Block:addParam("Interrupt", "Interrupt spells", SCRIPT_PARAM_ONOFF, true)

		Menu:addSubMenu("Misc", "Misc")
		Menu.Misc:addParam("rKill", "Kill enemy with ultimate if its possible", SCRIPT_PARAM_ONOFF, false)
		Menu.Misc:addParam("autolvl", "Auto lvl", SCRIPT_PARAM_ONOFF, true)
		Menu.Misc:addParam("autoMax", "Skill order:", SCRIPT_PARAM_LIST, 2, { "R>Q>W>E", "R>W>Q>E"})
		--Menu.Misc:addParam("manaManagerE", "Dont use E if Mana is under (in %)", SCRIPT_PARAM_SLICE, 0.3, 0, 1)

		Menu:addSubMenu("Drawing", "Drawing")
		Menu.Drawing:addParam("Qrange", "Draw Q range", SCRIPT_PARAM_ONOFF, true)
		Menu.Drawing:addParam("Wrange", "Draw W radius", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("Erange", "Draw E range", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("Rrange", "Draw R radius", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("comboDmg", "Draw Combo damage", SCRIPT_PARAM_ONOFF, true)

end

function OnGainBuff(unit, buff)
	if unit.team == myHero.team and buff.name:lower():find("orianaghostself") then
		ballPos = myHero
	end
end

function OnCreateObj(obj)

        if obj and obj.name:lower():find("yomu_ring_green") then
                ballPos = obj
        end
        
        if obj and obj.name:lower():find("orianna_ball_flash_reverse") then
            	ballPos = myHero
        end
end

function OnTick ()

ts:update()

if Menu.Misc.autolvl then
	if Menu.Misc.autoMax == 1 then
		autoLevelSetSequence(levelSequenceQ)
	elseif Menu.Misc.autoMax == 2 then
		autoLevelSetSequence(levelSequenceW)
	end
end

if Menu.Combo.Enabled then

if Menu.Combo.UseQ and myHero:CanUseSpell(_Q) == READY and myHero:GetSpellData(_Q).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then

	local Qpos, info = Prodiction.GetLineAOEPrediction(ts.target, Qrange, BallSpeed, Qdelay, Qradius, ballPos)
		if Qpos then
			 CastSpell(_Q, Qpos.x, Qpos.z)
	    end
end

if Menu.Combo.UseW1 and myHero:CanUseSpell(_W) == READY and myHero:GetSpellData(_W).level > 0 then
		if checkEnemiesHitWithW() >= Menu.Combo.UseW then
			CastSpell(_W)
			--Packet('S_CAST', {spellId = _W}):send()
	    end
end

if Menu.Combo.UseR and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then
		if checkEnemiesHitWithR() >= Menu.Combo.UseR then
			--Packet('S_CAST', {spellId = _R}):send()
			CastSpell(_R)
	    end
end
if Menu.E.UseE and myHero:CanUseSpell(_E) == READY and myHero:GetSpellData(_E).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then
		CastE()
end
if Menu.Block.Interrupt and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then
		Interrupt()
end
if Menu.Misc.rKill and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 and ts.target ~= nil and ValidTarget(ts.target) and checkEnemiesHitWithR() >= 1 then
	killR()
end

end -- enabled

end -- ontick

function OnProcessSpell(unit, spell)
	if unit.type == "obj_AI_Hero" then
		LastChampionSpell[unit.networkID] = {name = spell.name, time=os.clock()}
	end
end

function checkEnemiesHitWithR()

enemies = {}
enemyHealth = {}

for i, enemy in ipairs(GetEnemyHeroes()) do

		local dashing, dashPos, info = Prodiction.IsDashing(enemy, 0, math.huge, Rdelay, Rradius, ballPos)
		local position, info = Prodiction.GetCircularAOEPrediction(enemy, 0, math.huge, Rdelay, Rradius, ballPos)
		local toSlow, pos, info = Prodiction.IsToSlow(enemy, 0, math.huge, Rdelay, Rradius, ballPos)

		if not dashing and ValidTarget(enemy) and GetDistance(position, ballPos) <= Rradius and GetDistance(enemy.visionPos, ballPos) <= Rradius and toSlow then
				table.insert(enemies, enemy)
				table.insert(enemyHealth, enemy)
		elseif dashing and ValidTarget(enemy) and GetDistance(dashPos, ballPos) <= Rradius and GetDistance(enemy.visionPos, ballPos) <= Rradius and toSlow then
				table.insert(enemies, enemy)
				table.insert(enemyHealth, enemy)
		end
end

return #enemies

end

function checkEnemiesHitWithW()

enemies2 = {}

for i, enemy in ipairs(GetEnemyHeroes()) do
	    local dashing, dashPos, info = Prodiction.IsDashing(enemy, 0, math.huge, Wdelay, Wradius, ballPos)
		local position, info = Prodiction.GetCircularAOEPrediction(enemy, 0, math.huge, Wdelay, Wradius, ballPos)
		if not dashing and ValidTarget(enemy) and GetDistance(position, ballPos) <= Wradius and GetDistance(enemy.visionPos, ballPos) <= Wradius then
			table.insert(enemies2, enemy)
		elseif dashing and ValidTarget(enemy) and GetDistance(dashPos, ballPos) <= Wradius and GetDistance(enemy.visionPos, ballPos) <= Wradius then
			table.insert(enemies2, enemy)
		end
end

return #enemies2

end

function OnSendPacket(p)
	local packet = Packet(p)

	if Menu.Block.Block and p.header == Packet.headers.S_CAST then
		if packet:get('spellId') == _R then
			if checkEnemiesGetWithR() < 1 then
				p:Block()
			end
		end
	end
end

function OnDraw()
if Menu.Drawing.Qrange then
	DrawCircle(myHero.x, myHero.y, myHero.z, Qrange, ARGB(255, 0, 255, 0))
end
if Menu.Drawing.Rrange then
	DrawCircle(ballPos.x, 0, ballPos.z, Rradius, ARGB(255,0,0,255))
end
if Menu.Drawing.Wrange then
	DrawCircle(ballPos.x, 0, ballPos.z, Wradius, ARGB(255, 0, 255, 0))
end
if Menu.Drawing.Erange then
	DrawCircle(myHero.x, myHero.y, myHero.z, Erange, ARGB(255, 0, 255, 0))
end
if ts.target ~= nil and Menu.Drawing.comboDmg then
	DrawIndicator(ts.target, math.floor(comboDamage(ts.target)))
	DrawOnHPBar(ts.target, math.floor(comboDamage(ts.target)))
end
end

function CastE()
    smallestDist = nil
	allyToShield = myHero

	teamPos = {}
	enemyPos = {}

	for i=0, heroManager.iCount, 1 do
		currHero = heroManager:GetHero(i)
		if currHero.team == myHero.team and GetDistance(myHero, currHero) <= Erange then
			table.insert(teamPos, currHero)
		elseif currHero.team ~= myHero.team then
			table.insert(enemyPos, currHero)
		end
	end

	for _, enemy in ipairs(enemyPos) do
		for _, ally in ipairs(teamPos) do
			dist = GetDistance(ally, enemy)
			if smallestDist == nil or dist < smallestDist then
					smallestDist = dist
					allyToShield = ally
			end
		end
	end

	if Menu.E.UseE2 then
		for _, enemy in ipairs(enemyPos) do
			if GetDistance(enemy, myHero) <= Menu.E.UseE2Range then
				allyToShield = myHero
			end
		end
	end

	CastSpell(_E, allyToShield)
end

function Interrupt ()
		for i, unit in ipairs(GetEnemyHeroes()) do
			for champion, spell in pairs(InterruptList) do
				if GetDistance(unit) <= Qrange and LastChampionSpell[unit.networkID] and spell == LastChampionSpell[unit.networkID].name and (os.clock() - LastChampionSpell[unit.networkID].time < 1) then
					CastSpell(_Q, unit.x, unit.z)
					if GetDistance(ballPos, unit) < Rradius then
						--Packet('S_CAST', {spellId = _R}):send()
						CastSpell(_R)
					end
				end
			end
		end
end

function GetDamageR(spell, target)
	local damage = 0
	if spell == _R then
		damage = myHero:CalcMagicDamage(target, Rdamage[myHero:GetSpellData(_R).level] + myHero.ap * 0.7)
	elseif spell == _Q then
		damage = myHero:CalcMagicDamage(target, Rdamage[myHero:GetSpellData(_Q).level] + myHero.ap * 0.5)
	elseif spell == _W then
		damage = myHero:CalcMagicDamage(target, Rdamage[myHero:GetSpellData(_W).level] + myHero.ap * 0.7)
	end
	return damage
end

function killR ()

for _, enemy in ipairs(enemyHealth) do
	if enemy.health <= GetDamageR(_R, enemy) then
		CastSpell(_R)
	end
end

enemyHealth = {}

end

function comboDamage(target)
	local tDmg = 0
	for _, spell in ipairs(Combo) do
		tDmg = tDmg + GetDamage(spell, target)
	end
	return target.health - tDmg
end
