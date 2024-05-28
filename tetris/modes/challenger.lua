require 'funcs'

-- bgm.chlgr = {
--     lv1 = love.audio.newSource("res/bgm/BGM_1p_lv1.wav", "stream"),
--     lv2 = love.audio.newSource("res/bgm/BGM_1p_lv2.wav", "stream"),
--     lv3 = love.audio.newSource("res/bgm/BGM_1p_lv3.wav", "stream"),
--     lv4 = love.audio.newSource("res/bgm/BGM_1p_lv4.wav", "stream"),
--     lv5 = love.audio.newSource("res/bgm/BGM_1p_lv5.wav", "stream"),
--     lv6 = love.audio.newSource("res/bgm/BGM_1p_lv6.wav", "stream"),
-- }
sounds.chlgr = {
	nextsec = love.audio.newSource("res/se/levelup.wav", "static"),
	topout = love.audio.newSource("res/se/topout.wav", "static"),
	cool = love.audio.newSource("res/se/cool.wav", "static"),
	lvlstop = love.audio.newSource("res/se/bell.wav", "static"),
	garbage = love.audio.newSource("res/se/garbage.wav", "static"),
	gameOver = love.audio.newSource("res/se/gameover.wav", "static"),
	win = love.audio.newSource("res/se/excellent.wav", "static"),
	modified = love.audio.newSource("res/se/modified.wav", "static"),
	medal = love.audio.newSource("res/se/medal.wav", "static"),
}
local GameMode = require 'tetris.modes.gamemode'
local Piece = require 'tetris.components.piece'
local Ruleset = require 'tetris.rulesets.ruleset'
local CustomGrid = require 'tetris.components.chlggrid'

local History6RollsRandomizer = require 'tetris.randomizers.history_6rolls'

local ChallengerGame = GameMode:extend()
ChallengerGame.name = "Challenger"
ChallengerGame.hash = "Challenger"
ChallengerGame.tagline = "Highly flexible, configurable, challenging mode."
ChallengerGame.tags = {"Configurable", "Challenging"}

local tableBGMFadeout = {385,585,680,860,950,-1}

local tableBGMChange  = {400,600,700,900,1000,-1}

local bgmfadeframes = 0
local bgmlv = 1
local prevbgmlv = 0

-- function ChallengerGame:fadeBGM(time)
-- 	if tableBGMFadeout[bgmlv] ~= -1 and self:getSpeedLevel() >= tableBGMFadeout[bgmlv] * self.section_size / 100 then
-- 		bgmfadeframes = bgmfadeframes + 1
-- 		if bgmfadeframes == 1 then
-- 			fadeoutBGM(time)
-- 		end
-- 	else
-- 		bgmfadeframes = 0
-- 	end
-- end

-- function ChallengerGame:changeBGM(time)
-- 	if tableBGMChange[bgmlv] ~= -1 and self:getSpeedLevel() >= tableBGMChange[bgmlv] * self.section_size / 100 then
-- 		bgmlv = bgmlv + 1
-- 		resetBGMFadeout(time)
-- 		print("changed bgm to lv"..bgmlv)
-- 		switchBGMLoop("chlgr", "lv"..bgmlv)
-- 	end
-- end

-- function ChallengerGame:updateBGM()
-- 	if bgmlv ~= prevbgmlv then
-- 		prevbgmlv = bgmlv
-- 		switchBGMLoop("chlgr", "lv"..bgmlv)
-- 	end
-- end

local localRollTime = 0
local avgpps = 1.0
local gradescorereq = 100
local piececount = 0
local totaltime = 0
local virtualGradeScore = 0
local bellringed = false
local started = false
local selectedSegment = 0
local attemptsSinceStart = 1

function ChallengerGame:new(secret_inputs)
	ChallengerGame.super:new()
	-- if(scene == ReplayScene or scene == ReplaySelectScene) then love.window.showMessageBox("Chlg", "Oh hey!", "info", false) end
	if secret_inputs["rotate_180"] then
		playSE("blocks", "O")
	end
	started = true
	self.grid = CustomGrid(10, 40)
    localRollTime = 0
	selectedSegment = 0
    piececount = 0
    avgpps = 1.0
    gradescorereq = 100
	totaltime = 0
	virtualGradeScore = 0
	bgmlv = 1
	prevbgmlv = 0
	bellringed = false
	self.endingLevel = 2100
	self.LockDelayTiming = 30
	self.LockDelayModified = false
	self.LockDelayTicks = 0
	self.LockDelayResets = 0
	self.LockDelayRotResets = 0
	self.LockDelayMaxResets = 0
	self.LockDelayMaxRotResets = 0
	self.instant_gravity_sections = 0
	self.ARETiming = 25
	self.ARELineTiming = 10
	self.LineDelayTiming = 15
	self.TilesPerFrame = 0.078125
	self.instant_gravity_trigger = false
	self.percentage = 0.8
	self.ready_frames = 1
	self.waiting_frames = 96
	self.in_menu = true
	self.start_level = 0
	self.level = self.start_level * 100
	self.speed_level = self.start_level * 100
	self.roll_frames = 0
	self.garbage = 0
	self.combo = 1
	self.grade = 0
	self.grade_points = 0
	self.roll_points = 0
	self.grade_point_decay_counter = 0
	self.section_cool_grade = 0
	self.section_status = { [0] = "none" }
	self.section_start_time = 0
	self.internal_section_time = { [0] = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	self.section_70_times = { [0] = 0 }
	self.section_times = { [0] = 0 }
	self.section_cool = false
	self.coolchecked = false
	self.previouscool = false
	self.cooldisplayed = false
	self.section_size = 100
	self.nextseclv = (self.start_level + 1) * 100
	self.coolprevtime = 0;
	
	---@type love.ParticleSystem[]
	self.particle_systems = {}

	-- This is notorious for taking up a lot of memory. Also it needs to be disposed of at the end.
	for key, value in pairs(blocks["2tie"]) do
		self.particle_systems[key] = love.graphics.newParticleSystem(value, 3000)
		self.particle_systems[key]:setParticleLifetime(1) -- Particles live at 1s.
		self.particle_systems[key]:setLinearAcceleration(-50, -50, 50, 150) -- Randomized movement.
		self.particle_systems[key]:setSpread(360)
		self.particle_systems[key]:setSpeed(100, 250)
		self.particle_systems[key]:setSizes(0.2, 0.1, 0.05, 0)
		self.particle_systems[key]:setEmissionArea("uniform", 8, 8, 0, "true")
	end

	self.randomizer = History6RollsRandomizer()

self.SGnames = {
		"9", "8", "7", "6", "5", "4", "3", "2", "1",
		"S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9",
		"GM"
	}
	self.arrayLinesFrozen = {
		[0] = 0, 0, 0, 6, 4, 0, 0, 0, 8, 0, 0, 12, 16, 0, 0, 0, 19, 0, 0, 0, 10, 14
	}

	
	self.configType = 1

	if secret_inputs["rotate_right"] and secret_inputs["rotate_left"] then
		self.configType = 0
	end


	--Kinda has to fool the grid to not clear
	self.lineFreezingMechanic = false
	self.lock_drop = true
	self.lock_hard_drop = true
	self.enable_hold = true
	self.next_queue_length = 7
	
	self.coolregret_message = "COOL!!"
	self.coolregret_timer = 0

	self.randomcoolchance = 82
	
	self.torikan_passed = false

	self.recovery_flag = false
	self.fours = 0
	self.all_clears = 0
	self.medal_RE = 0

	bgm.credit_roll.gm3:stop()

	self:setTemplate(2)

	love.mouse.setVisible(false)
end

local function getTableContentInLimit(table, idx)
	if idx > #table then
		idx = #table
	end
	return table[idx]
end

function ChallengerGame:drawCursor(x, y)
    love.graphics.setColor(1,1,1,1)
    love.graphics.polygon("fill", x + 5, y + 0, x + 0, y + 10, x + 5, y + 8, x + 8, y + 20, x + 12, y + 18, x + 10, y + 7, x + 15, y + 5)
    love.graphics.setColor(0,0,0,1)
    love.graphics.polygon("line", x + 5, y + 0, x + 0, y + 10, x + 5, y + 8, x + 8, y + 20, x + 12, y + 18, x + 10, y + 7, x + 15, y + 5)
    love.graphics.setColor(1,1,1,1)
end
function ChallengerGame:getScaledCursorPos(x,y)
	local lx, ly = love.graphics.getDimensions()
	local scale_factor = math.min(lx / 640, ly / 480)
	return (x - (lx - scale_factor * 640) / 2)/scale_factor, (y - (ly - scale_factor * 480) / 2)/scale_factor
end

-- -- why did I bother writing this
-- function ChallengerGame:moveCursorScale(x,y,additive)
-- 	if additive == nil then additive = false end
-- 	local lx, ly = love.graphics.getDimensions()
-- 	local scale_factor = math.min(lx / 640, ly / 480)
-- 	if additive then
-- 		love.mouse.setPosition(love.mouse.getPosition() + self:getScaledCursorPos(x,y))
-- 	else
-- 		love.mouse.setPosition(self:getScaledCursorPos(x,y))
-- 	end
-- end


function ChallengerGame:lockReset(piece, grid)
	piece.lock_delay = 0 -- step reset
end

local cool_cutoffs = {
	frameTime(0,52), frameTime(0,52), frameTime(0,49), frameTime(0,45), frameTime(0,45),
    frameTime(0,42), frameTime(0,42), frameTime(0,38), frameTime(0,38), frameTime(0,38),
    frameTime(0,33), frameTime(0,33), frameTime(0,33), frameTime(0,28), frameTime(0,28),
    frameTime(0,22), frameTime(0,18), frameTime(0,14), frameTime(0,9), frameTime(0,6),
}

local regret_cutoffs = {
	[0] = 90, 75, 75, 68, 60, 60, 50, 50, 50, 50, 45, 45, 45, 40, 40, 34, 30, 26, 17, 8,
}

function ChallengerGame:checkCool()
	local section = math.floor(self.level / self.section_size)
	-- COOL check
	if self.level % self.section_size > self.section_size * 0.7 and self.coolchecked == false and self.level <= self.section_size * 20 then
		if (self.internal_section_time[section] <= cool_cutoffs[section+1] * (self.section_size / 100)) and
		 ((self.previouscool == false) or ((self.previouscool == true) and ((self.frames - self.section_start_time) <= self.coolprevtime + 60))) then
			self.section_cool = true
			self.section_status[section] = "cool"
		end
		self.coolprevtime = self.internal_section_time[section];
		self.coolchecked = true;
		print("COOL!! sect"..section)
	end

	if((self.level % self.section_size >= self.section_size * 0.82) and (self.section_cool == true) and (self.cooldisplayed == false)) then
		self.coolregret_timer = 180
		self.cooldisplayed = true
		self.coolregret_message = "COOL!!"
		virtualGradeScore = virtualGradeScore + 600
		print("RENDERED COOL!!")
		playSE("chlgr", "cool")
	end
end
function ChallengerGame:getSkin()
	return self.level >= self.section_size * 6 and "bone" or "2tie"
end
function ChallengerGame:getARE()
	return math.ceil(self.ARETiming)
end

function ChallengerGame:getFrozenLines()
	local result = 0
	if self.lineFreezingMechanic then
		result = self.arrayLinesFrozen[self:getSection()]
	end
	return result
end

local line_clone_per_piece = {[0] = 2147483647,2147483647,20,20,20,20,20,20,20,20,16,16,16,8,8,6,5,4,3,2,2,2};
function ChallengerGame:getGarbageLimit()
	return line_clone_per_piece[self:getSection()] or 1
end
function ChallengerGame:getLineARE()
	return math.ceil(self.ARELineTiming)
end
function ChallengerGame:onExit()
	love.mouse.setVisible(true)
	for key, particle_system in pairs(self.particle_systems) do
		particle_system:release() -- It's necessary to avoid getting out-of-memory crash.
	end
	bgm.credit_roll.gm3:stop() --it's necessary.
	self.super:onExit()
end
function ChallengerGame:getSection()
	local result = 0
	if self.section_size ~= nil then
		result = math.floor((self.level) / self.section_size)
	end
	return result
end
function ChallengerGame:getSpeedSection()
	local result = 4 + self.instant_gravity_sections
	return result
end
function ChallengerGame:getSpeedLevel()
	if self.instant_gravity_trigger then
		return 4 * self.section_size + self.level
	else
		return self.level
	end
end

function ChallengerGame:getDasLimit()
		if self.LockDelayModified then return math.floor(self.LockDelayTiming / 2)
	elseif self:getSpeedSection() < 5 then return 15
    elseif self:getSpeedSection() < 9 then return 9
    elseif self:getSpeedSection() < 13 then return 6
    elseif self:getSpeedSection() < 17 then return 2
	else return 1 end
end

function ChallengerGame:getLineClearDelay()
	return math.ceil(self.LineDelayTiming)
end

function ChallengerGame:getLockDelay()
	if self.LockDelayTiming < 2 then return 2 end
	return math.ceil(self.LockDelayTiming)
end


function ChallengerGame:getGravity()
	return self.TilesPerFrame
end

function ChallengerGame:getHowManyBlocks()
	local count = 0
	for y, value in ipairs(self.grid.grid) do
		for x, block in ipairs(value) do
			if self.grid:isOccupied(x - 1, y - 1) then
				count = count + 1
			end
		end
	end
	return count
end

local menuDAS = 12
local menuDASf = {["up"] = 0, ["down"] = 0, ["left"] = 0, ["right"] = 0}
local menuARR = {[0] = 8, 6, 5, 4, 3, 2, 2, 2, 1}
function ChallengerGame:menuDASInput(input, inputString)
	local result = false
	if(input) then menuDASf[inputString] = menuDASf[inputString] + 1
	else
		menuDASf[inputString] = 0
	end
	if (self.prev_inputs[inputString] == false or (menuDASf[inputString] >= menuDAS and menuDASf[inputString] % self:getMenuARR(menuDASf[inputString]) == 0) or menuDASf[inputString] == 1) and input then
		result = true
		if(self:getMenuARR(menuDASf[inputString]) > 2 or menuDASf[inputString] % 4 == 0) then playSE("cursor") end
	end
	return result
end
-- Template layout:
-- { "Name", float: lock delay, float: spawn delay, float: line drop delay, float: line spawn delay, gravity, ending level, percentage}
local templates = {
	{ "Easy", 60, 10, 5, 10, 1 / 4096, 600, 0.9 },
	{ "Standard", 30, 25, 10, 15, 0.078125, 2100, 0.8 },
	{ "Ultra Hard", 12, 4, 3, 2, 999999999, 1000, 0.9 },
	{ "TAS MODE", 0.0001, 0.0001, 0.0001, 0.0001, 999999999, 10000, 1},
}

function ChallengerGame:setTemplate(templateID)
	if type(templateID) ~= "number" or templateID ~= math.floor(templateID) then
		error("The input ".. templateID .. " is invalid. Please input an integer.")
	end
	self.TemplateType = templateID
	self.SelectedTemplateName = templates[templateID][1]
	self.LockDelayTiming = templates[templateID][2]
	self.ARETiming = templates[templateID][3]
	self.LineDelayTiming = templates[templateID][4]
	self.ARELineTiming = templates[templateID][5]
	self.TilesPerFrame = templates[templateID][6]
	self.endingLevel = templates[templateID][7]
	self.percentage = templates[templateID][8]
end

function ChallengerGame:menuIncrement(inputs, current_value, increase_by, limit_size)
	local scaled_increase_by = math.ceil(((current_value/60) / increase_by))
	if self:menuDASInput(inputs["right"], "right") then
		current_value = current_value + scaled_increase_by
	elseif self:menuDASInput(inputs["left"], "left") then
		current_value = current_value - scaled_increase_by
	end
	if current_value > limit_size then
		return limit_size
	end
	if current_value < 1 then return 1 end
	return current_value
end
function ChallengerGame:whilePieceActive()
	self.LockDelayTicks = self.piece.lock_delay
	self.LockDelayResets = self:VarCheck(self.piece.manipulations, -1)
	self.LockDelayRotResets = self:VarCheck(self.piece.rotations, -1)
end
function ChallengerGame:getMenuARR(number)
	if number < 60 then
		if (number / 30) > #menuARR then
			return #menuARR
		else
			return menuARR[math.floor(number / 30)]
		end
	end
	return math.ceil(25 / math.sqrt(number))
end
local lx, ly
local isPressed
function ChallengerGame:advanceOneFrame(inputs, ruleset)
	-- if self.in_menu then
	-- 	self.rpc_details = "In configuration menu"
	-- elseif self:getFrozenLines() > 12 then
	-- 	self.rpc_details = "Frozen to death. Level: "..self.level.."/"..self.nextseclv
	-- elseif self:getFrozenLines() > 0 then
	-- 	self.rpc_details = "Cold. Brrr... Level: "..self.level.."/"..self.nextseclv
	-- elseif self.level < 800 then
	-- 	self.rpc_details = "In game. Level: "..self.level.."/"..self.nextseclv
	-- else
	-- 	self.rpc_details = "Struggling. Level: "..self.level.."/"..self.nextseclv
	-- end
	for key, particle_system in pairs(self.particle_systems) do
		particle_system:update(0.01666)
	end
	DiscordRPC:update({
		details = self.rpc_details
	})
	self.grid:setFrozenLines(self:getFrozenLines())
    avgpps = piececount / math.abs(totaltime / 60)
	if self.in_menu then
		local maxSelection = 1
		if self.configType == 2 then
			maxSelection = 10
		elseif self.configType == 1 then
			maxSelection = 4
		end
		local adjusted_lv = self.instant_gravity_trigger and self.start_level + 4 or self.start_level
		if adjusted_lv == 4 then
			bgmlv = 2
		elseif adjusted_lv < 4 then
			bgmlv = 1
		elseif adjusted_lv == 6 then
			bgmlv = 3
		elseif adjusted_lv < 6 then
			bgmlv = 2
		elseif adjusted_lv == 7 then
			bgmlv = 4
		elseif adjusted_lv < 7 then
			bgmlv = 3
		elseif adjusted_lv == 9 then
			bgmlv = 5
		elseif adjusted_lv < 9 then
			bgmlv = 4
		elseif adjusted_lv > 9 then
			bgmlv = 6
		end
		if self.save_replay then
			lx, ly = self:getScaledCursorPos(love.mouse.getPosition())
			if lx > 50 and lx < 230 then
				local transformedCursorPos = math.floor((ly - 100) / 15)
				if lx > 60 and lx < 220 then
					if love.mouse.isDown(1) then
						scene.inputs["rotate_left"] = true
						if isPressed then
							scene.inputs["rotate_left"] = false
						end
					end
				end
				if transformedCursorPos < 0 or transformedCursorPos > maxSelection then
					scene.inputs["up"] = false
					scene.inputs["down"] = false
				elseif selectedSegment ~= transformedCursorPos then
					scene.inputs["up"] = (selectedSegment > transformedCursorPos) and true or false
					scene.inputs["down"] = selectedSegment < transformedCursorPos and true or false
				else
					scene.inputs["up"] = false
					scene.inputs["down"] = false
				end
			end
			if love.mouse.isDown(1) then
				if lx > 50 and lx < 60 then
					scene.inputs["left"] = true
				end
				if lx > 220 and lx < 230 then
					scene.inputs["right"] = true
				end
			else
				if lx > 50 and lx < 60 then
					scene.inputs["left"] = false
				end
				if lx > 220 and lx < 230 then
					scene.inputs["right"] = false
				end
			end
			isPressed = love.mouse.isDown(1)
		end
		self.LockDelayMaxResets = self:VarCheck(ruleset.MANIPULATIONS_MAX, 0)
		self.LockDelayMaxRotResets = self:VarCheck(ruleset.ROTATIONS_MAX, 0)
		if ChallengerGame:menuDASInput(inputs["up"], "up") then
			if selectedSegment < 1 then
				selectedSegment = maxSelection
			else
				selectedSegment = selectedSegment - 1
			end
		elseif ChallengerGame:menuDASInput(inputs["down"], "down") then
			if selectedSegment > maxSelection-1 then
				selectedSegment = 0
			else
				selectedSegment = selectedSegment + 1
			end
		end
		if self.configType == 2 then
			if selectedSegment == 0 then
				if ChallengerGame:menuDASInput(inputs["right"], "right") then
					self.start_level = math.min(self.endingLevel/self.section_size, self.start_level + 1)
				elseif ChallengerGame:menuDASInput(inputs["left"], "left") then
					self.start_level = math.max(0, self.start_level - 1)
				end
				self.start_level = math.ceil(self.start_level)
			elseif selectedSegment == 1 then
				self.LockDelayTiming = self:menuIncrement(inputs, self.LockDelayTiming, 1, 36000)
			elseif selectedSegment == 2 then
				self.ARETiming = self:menuIncrement(inputs, self.ARETiming, 1, 600)
			elseif selectedSegment == 3 then
				self.ARELineTiming = self:menuIncrement(inputs, self.ARELineTiming, 1, 300)
			elseif selectedSegment == 4 then
				self.LineDelayTiming = self:menuIncrement(inputs, self.LineDelayTiming, 1, 300)
			elseif selectedSegment == 5 then
				if ChallengerGame:menuDASInput(inputs["right"], "right") then
					self.percentage = self.percentage + 0.01
				elseif ChallengerGame:menuDASInput(inputs["left"], "left") then
					self.percentage = self.percentage - 0.01
				end
				if self.percentage < 0.01 then
					self.percentage = 0.01
				elseif self.percentage > 0.99 then
					self.percentage = 0.99
				end
			elseif selectedSegment == 6 then
				if ChallengerGame:menuDASInput(inputs["right"], "right") then
					self.endingLevel = self.endingLevel + (self.section_size / 10)
					if self.endingLevel > 1000000 then
						self.endingLevel = 1000000
					end
				elseif ChallengerGame:menuDASInput(inputs["left"], "left") then
					self.endingLevel = self.endingLevel - (self.section_size / 10)
					if self.endingLevel < self.section_size / 10 then
						self.endingLevel = self.section_size / 10
					end
					if self.start_level > math.ceil(self.endingLevel / self.section_size) then
						self.start_level = math.ceil(self.endingLevel / self.section_size)
					end
				end
			elseif selectedSegment == 7 then
				if ChallengerGame:menuDASInput(inputs["right"], "right") then
					self.section_size = self.section_size + 1
					if self.section_size > 600 then
						self.section_size = 600
					else
						self.endingLevel = math.floor((self.endingLevel / (self.section_size -1)) * (self.section_size))
					end
				elseif ChallengerGame:menuDASInput(inputs["left"], "left") then
					self.section_size = self.section_size - 1
					if self.section_size < 5 then
						self.section_size = 5
					else
						self.endingLevel = math.ceil((self.endingLevel * (self.section_size - 1)) / self.section_size)
					end
				end
			elseif selectedSegment == 8 then
				if (ChallengerGame:menuDASInput(inputs["right"], "right")) or (ChallengerGame:menuDASInput(inputs["left"], "left")) then
					self.instant_gravity_trigger = not self.instant_gravity_trigger
					if self.TilesPerFrame == 0.078125 then
						self.TilesPerFrame = math.huge
					else
						self.TilesPerFrame = 0.078125
					end
				end
			elseif selectedSegment == 9 then
				if (ChallengerGame:menuDASInput(inputs["right"], "right")) or (ChallengerGame:menuDASInput(inputs["left"], "left")) then
					self.lineFreezingMechanic = not self.lineFreezingMechanic
				end
			elseif selectedSegment == 10 then
				if (ChallengerGame:menuDASInput(inputs["right"], "right")) or (ChallengerGame:menuDASInput(inputs["left"], "left")) then
					self.big_mode = not self.big_mode
				end
			end
		elseif self.configType == 1 then
			if selectedSegment == 0 then
				if ChallengerGame:menuDASInput(inputs["right"], "right") then
					self.start_level = math.min(self.endingLevel/self.section_size, self.start_level + 1)
				elseif ChallengerGame:menuDASInput(inputs["left"], "left") then
					self.start_level = math.max(0, self.start_level - 1)
				end
				self.start_level = math.floor(self.start_level)
			elseif selectedSegment == 1 then
				if (ChallengerGame:menuDASInput(inputs["right"], "right")) or (ChallengerGame:menuDASInput(inputs["left"], "left")) then
					self.instant_gravity_trigger = not self.instant_gravity_trigger
					if self.TilesPerFrame == 0.078125 then
						self.TilesPerFrame = math.huge
					else
						self.TilesPerFrame = 0.078125
					end
				end
			elseif selectedSegment == 2 then
				if (ChallengerGame:menuDASInput(inputs["right"], "right")) or (ChallengerGame:menuDASInput(inputs["left"], "left")) then
					self.lineFreezingMechanic = not self.lineFreezingMechanic
				end
			elseif selectedSegment == 3 then
				if (ChallengerGame:menuDASInput(inputs["right"], "right")) or (ChallengerGame:menuDASInput(inputs["left"], "left")) then
					self.big_mode = not self.big_mode
				end
			end
		else
			if selectedSegment == 0 then
				local localTemplateID = self.TemplateType
				if ChallengerGame:menuDASInput(inputs["right"], "right") then
					localTemplateID = math.min(#templates, localTemplateID + 1)
				elseif ChallengerGame:menuDASInput(inputs["left"], "left") then
					localTemplateID = math.max(1, localTemplateID - 1)
				end
				self:setTemplate(localTemplateID)
			end
		end
		if ((inputs["rotate_left"] and not self.prev_inputs["rotate_left"]) or (inputs["rotate_left2"] and not self.prev_inputs["rotate_left2"])
		or (inputs["rotate_right"] and not self.prev_inputs["rotate_right"]) or (inputs["rotate_right2"] and not self.prev_inputs["rotate_right"])
		or (inputs["rotate_180"] and not self.prev_inputs["rotate_180"])) then
			if (self.configType < 2 and selectedSegment == (self.configType == 0 and 1 or 4)) then
				self.configType = self.configType + 1
				selectedSegment = 0
				playSE("main_decide")
				self:setTemplate(2)
			else
				if self.LockDelayTiming <= 30 then
					self.LockDelayModified = true
				end
				self.in_menu = false
				attemptsSinceStart = attemptsSinceStart + 1
				self.ready_frames = 100;
				self.nextseclv = self:getSectionEndLevel()
				for i = 0, self.start_level do
					table.insert(self.section_status, "none")
					table.insert(self.section_70_times, cool_cutoffs[i])
					if i > 0 then self:updateTimingsSection() end
				end
				if self.start_level == math.ceil(self.endingLevel / self.section_size) then
					self.clear = true
					self.roll_frames = -30
				end
				local adjusted_lv = self.instant_gravity_trigger and self.start_level + 4 or self.start_level
				if adjusted_lv == 4 then
					bgmlv = 2
				elseif adjusted_lv < 4 then
					bgmlv = 1
				elseif adjusted_lv == 6 then
					bgmlv = 3
				elseif adjusted_lv < 6 then
					bgmlv = 2
				elseif adjusted_lv == 7 then
					bgmlv = 4
				elseif adjusted_lv < 7 then
					bgmlv = 3
				elseif adjusted_lv == 9 then
					bgmlv = 5
				elseif adjusted_lv < 9 then
					bgmlv = 4
				elseif adjusted_lv > 9 then
					bgmlv = 6
				end
			end
		end
		self.endingLevel = math.floor(self.endingLevel)
		self.level = self.start_level * self.section_size
		if self.level > self.endingLevel then
			self.level = self.endingLevel
		end
		local if20g = false
		if20g = self.TilesPerFrame >= 20
		self.speed_level = if20g and self.start_level * self.section_size or self.start_level * self.section_size + self.section_size * 4
		self.prev_inputs = copy(inputs)
		return false
	elseif self.waiting_frames > 0 then
		self.waiting_frames = self.waiting_frames - 1
	elseif self.clear then
		self.roll_frames = self.roll_frames + 1
		if self.roll_frames < 0 then
			if self.roll_frames + 1 == 0 then
				bgm.credit_roll.gm3:setVolume(config.bgm_volume)
				bgm.credit_roll.gm3:setLooping(true)
				bgm.credit_roll.gm3:play()
			end
			return false
		elseif self.roll_frames > 6600 then
			bgm.credit_roll.gm3:stop()
			self.completed = true
		end
	end
	if self.ready_frames == 0 then
		self.frames = self.frames + 1
		-- self:changeBGM(180)
		-- self:fadeBGM(180)
		-- processBGMFadeout(1)
	end
	if self.frames == 1 then 
		-- switchBGMLoop("chlgr", "lv"..bgmlv)
		-- self:updateBGM()
		totaltime = 1
		self.grade_points = self.grade_points + math.abs(math.abs(1 + self:getSection() / 4) / 60)
	elseif self.frames > 1 then
		self.grade_points = self.grade_points + math.abs(math.abs(1 + self:getSection() + 1 / 4) / 60)
		totaltime = totaltime + 1
		if (self.level >= self.nextseclv and self.level < self.endingLevel) then
			playSE("chlgr", "nextsec")
			self.nextseclv = self:getSectionEndLevel()
		end
		if self.level < self.section_size * 20 then
			local section = self:getSection()
			self.internal_section_time[section] = self.internal_section_time[section] + 1
			-- if self.level % self.section_size > 0.7 * self.section_size then self.section_70_times[section] = self.section_70_times[section] + 1 end
		end
	end
	self:checkCool()
	return true
end

--#region Full-on override.
function ChallengerGame:update(inputs, ruleset)
	if self.game_over or self.completed then
		if self.save_replay and self.game_over_frames == 0 then
			self:saveReplay()
		end
		if self.game_over_frames == 0 then
			playSE("chlgr", "topout")
		end
		self.game_over_frames = self.game_over_frames + 1
		local isTASCrazy = false
		if self.LineDelayTiming < 0.1 and self.ARELineTiming < 0.1 and self.ARETiming < 0.1 and self.LineDelayTiming < 0.1 and self.TilesPerFrame > 999999 then
			isTASCrazy = true
		end
		if self.game_over_frames % 2 == 0 and self.game_over_frames / 2 < self.grid.height and not isTASCrazy then
			if self.grid:isRowEmpty(self.grid.height-self.game_over_frames/2) then
				playSE("erase", "single")
			end
			self.grid:clearSpecificRow(self.game_over_frames/2+1)
			if(self.game_over_frames > 2) then
				self.grid:clearSpecificRow(self.game_over_frames/2)
			end
		end
		if self.game_over_frames == self.grid.height*2 + 15 then
			if self.configType == 2 then playSE("chlgr", 'modified')
			elseif self.completed then playSE("chlgr", "win")
			else playSE("chlgr", "gameOver") end
		end
		return
	end

	if config.gamesettings.diagonal_input == 2 then
		if inputs["left"] or inputs["right"] then
			inputs["up"] = false
			inputs["down"] = false
		elseif inputs["down"] then
			inputs["up"] = false
		end
	end

	if self.save_replay then self:addReplayInput(inputs) end

	-- advance one frame
	if self:advanceOneFrame(inputs, ruleset) == false then return end

	self:chargeDAS(inputs, self:getDasLimit(), self:getARR())

	-- set attempt flags
	if inputs["left"] or inputs["right"] then self:onAttemptPieceMove(self.piece, self.grid) end
	if (
		inputs["rotate_left"] or inputs["rotate_right"] or
		inputs["rotate_left2"] or inputs["rotate_right2"] or
		inputs["rotate_180"]
	) then
		self:onAttemptPieceRotate(self.piece, self.grid)
	end
	
	if self.piece == nil then
		self:processDelays(inputs, ruleset)
	else
		-- perform active frame actions such as fading out the next queue
		self:whilePieceActive()

		if self.enable_hold and inputs["hold"] == true and self.held == false and self.prev_inputs["hold"] == false then
			self:hold(inputs, ruleset)
			self.prev_inputs = inputs
			return
		end

		if (self.lock_drop or (
			not ruleset.are or self:getARE() <= 0
		)) and inputs["down"] ~= true then
			self.drop_locked = false
		end

		if (self.lock_hard_drop or (
			not ruleset.are or self:getARE() <= 0
		)) and inputs["up"] ~= true then
			self.hard_drop_locked = false
		end

		-- diff vars to use in checks
		local piece_y = self.piece.position.y
		local piece_x = self.piece.position.x
		local piece_rot = self.piece.rotation

		ruleset:processPiece(
			inputs, self.piece, self.grid, self:getGravity(), self.prev_inputs,
			(
				inputs.up and self.lock_on_hard_drop and not self.hard_drop_locked
			) and "none" or self.move,
			self:getLockDelay(), self:getDropSpeed(),
			self.drop_locked, self.hard_drop_locked,
			self.enable_hard_drop, self.additive_gravity, self.classic_lock
		)

		local piece_dy = self.piece.position.y - piece_y
		local piece_dx = self.piece.position.x - piece_x
		local piece_drot = self.piece.rotation - piece_rot

		-- das cut
		if (
			(piece_dy ~= 0 and (inputs.up or inputs.down)) or
			(piece_drot ~= 0 and (
				inputs.rotate_left or inputs.rotate_right or
				inputs.rotate_left2 or inputs.rotate_right2 or
				inputs.rotate_180
			))
		) then
			self:dasCut()
		end

		if (piece_dx ~= 0) then
			self.piece.last_rotated = false
			self:onPieceMove(self.piece, self.grid, piece_dx)
		end
		if (piece_dy ~= 0) then
			self.piece.last_rotated = false
			self:onPieceDrop(self.piece, self.grid, piece_dy)
		end
		if (piece_drot ~= 0) then
			self.piece.last_rotated = true
			self:onPieceRotate(self.piece, self.grid, piece_drot)
		end

		if inputs["up"] == true and
			self.piece:isDropBlocked(self.grid) and
			not self.hard_drop_locked then
			self:onHardDrop(piece_dy)
			if self.lock_on_hard_drop then
				self.piece_hard_dropped = true
				self.piece.locked = true
			end
		end

		if inputs["down"] == true then
			if not (
				self.piece:isDropBlocked(self.grid) and
				piece_drot ~= 0
			) then
				self:onSoftDrop(piece_dy)
			end
			if self.piece:isDropBlocked(self.grid) and
				not self.drop_locked and
				self.lock_on_soft_drop
			then
				self.piece.locked = true
				self.piece_soft_locked = true
			end
		end

		if self.piece.locked == true then
			-- spin detection, immobile only for now
			if self.immobile_spin_bonus and
			   self.piece.last_rotated and (
				self.piece:isDropBlocked(self.grid) and
				self.piece:isMoveBlocked(self.grid, { x=-1, y=0 }) and 
				self.piece:isMoveBlocked(self.grid, { x=1, y=0 }) and
				self.piece:isMoveBlocked(self.grid, { x=0, y=-1 })
			) then
				self.piece.spin = true
			end

			self.grid:applyPiece(self.piece)
			
			-- mark squares (can be overridden)
			if self.square_mode then
				self.squares = self.squares + self.grid:markSquares()
			end

			local cleared_row_count = self.grid:getClearedRowCount()
			self:onPieceLock(self.piece, cleared_row_count)
			self:updateScore(self.level, self.drop_bonus, cleared_row_count)

			self.cleared_block_table = self.grid:markClearedRows()
			self.piece = nil
			if self.enable_hold then
				self.held = false
			end

			if cleared_row_count > 0 then
				local row_count_names = {"single","double","triple","quad"}
				playSE("erase",row_count_names[cleared_row_count] or "quad")
				self.lcd = self:getLineClearDelay()
				self.last_lcd = self.lcd
				self.are = (
					ruleset.are and self:getLineARE() or 0
				)
				if self.lcd <= 0 then
					self.grid:clearClearedRows()
					self:afterLineClear(cleared_row_count)
					if self.are <= 0 then
						self:initializeOrHold(inputs, ruleset)
					end
				end
				self:onLineClear(cleared_row_count)
			else
				if self:getARE() <= 0 or not ruleset.are then
					self:initializeOrHold(inputs, ruleset)
				else
					self.are = self:getARE()
				end
			end
		end
	end
	self.prev_inputs = inputs
end
--#endregion

function ChallengerGame:onPieceLock(piece, cleared_row_count)
	self.super:onPieceLock()
    avgpps = piececount / math.abs(totaltime / 60)
    piececount = piececount + 1
end
function ChallengerGame:onPieceEnter()
	-- The Initial Movement System, pioneered by DTET. It's necessary for imitation of the Unity version.
	if self.das.frames >= self:getDasLimit() - self:getARR() and self.grid:canPlacePiece(self.piece) then
		if self.das.direction == "left" then
			for i = 1, 10 do
				local new_piece = self.piece:withOffset({x=-i, y=0})
				if self.grid:canPlacePiece(new_piece) then
					self.piece:setOffset({x=-i, y=0})
					break
				end
				if self:getARE() ~= 0 then break end
			end
		elseif self.das.direction == "right" then
			for i = 1, 10 do
				local new_piece = self.piece:withOffset({x=i, y=0})
				if self.grid:canPlacePiece(new_piece) then
					self.piece:setOffset({x=i, y=0})
					break
				end
				if self:getARE() ~= 0 then break end
			end
		end
	end
	self:advanceBottomRow(1)
	if (self.level % self.section_size ~= self.section_size -1) and self.level ~= self.endingLevel -1 and self.level ~= self.endingLevel and self.frames ~= 0 then
		self:updateSectionTimes(self.level, self.level + 1)
		self.level = self.level + 1
		self.speed_level = self.speed_level + 1
		self.torikan_passed = self.level >= self.section_size * 5 and true or false
	elseif bellringed == false and (self.level / self.section_size) ~= self.start_level and self.level ~= self.endingLevel then
		playSE("chlgr", "lvlstop")
		bellringed = true
	end
end

local cleared_row_levels = {1, 3, 6, 10, 15, 21, 28, 36, 48, 70, 88, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90}

function ChallengerGame:onLineClear(cleared_row_count)
	for y, row in pairs(self.cleared_block_table) do
		for x, block in pairs(row) do
			if block.skin == "bone" then --nothing
			else
				self.particle_systems[block.colour]:setPosition(56 + x * 16, y * 16 - 248)
				self.particle_systems[block.colour]:emit(self.big_mode and 16 or 64)
			end
		end
	end
	if self.grid:checkForBravo(cleared_row_count) then
		if self.all_clears < 4 then
			playSE("chlgr", "medal")
		end
		playSE("chlgr", "nextsec")
		self.all_clears = self.all_clears + 1
	end

	if self.big_mode then
		cleared_row_count = cleared_row_count / 2
	end

	local blocks = self:getHowManyBlocks();

	if self.recovery_flag == false then
		if (blocks >= 150) then
			self.recovery_flag = true
		end
	else
		if blocks <= 70 then
			self.recovery_flag = false;
			playSE("chlgr", "medal");
			self.medal_RE = self.medal_RE + 1;
		end
	end
	local advanced_levels = cleared_row_levels[cleared_row_count]
	if self.level < self.section_size * 20 then self:updateSectionTimes(self.level, self.level + advanced_levels) end
	if not self.clear then
		self.level = math.min(self.level + advanced_levels, self.endingLevel)
	end
	self.speed_level = self.speed_level + advanced_levels
	if self.level == self.endingLevel and not self.clear then
		self.clear = true
		self.grid:clear()
		self.roll_frames = -30
	end
	if not self.torikan_passed and self.level >= 500 and self.frames >= 25200 then
	self.level = 500
	self.game_over = true
	end
end

function ChallengerGame:advanceBottomRow(dx)
	if self.level >= 200 then
		self.garbage = math.max(self.garbage + dx, 0)
		if self.garbage >= self:getGarbageLimit() then
			self.grid:copyBottomRow()
			if self.big_mode then self.grid:copyBottomRow() end
			self.garbage = 0
			playSE("chlgr", "garbage")
			while self.piece:isMoveBlocked(self.grid, {x = 0, y = 0}) do
				self.piece.position.y = self.piece.position.y - 1
			end
		end
	end
end
-- Update timings per section
function ChallengerGame:updateTimingsSection()
	if self.TilesPerFrame >= 20 then
		self.LockDelayTiming = self.LockDelayTiming * self.percentage
		self.ARELineTiming = self.ARELineTiming * self.percentage
		self.ARETiming = self.ARETiming * self.percentage
		self.LineDelayTiming = self.LineDelayTiming * self.percentage
		self.instant_gravity_sections = self.instant_gravity_sections + 1
	end
	self.TilesPerFrame = self.TilesPerFrame * 4
	
end
function ChallengerGame:updateSectionTimes(old_level, new_level)
	if self.clear then return end
	self:checkCool()
	local section = math.floor((self.level+1) / self.section_size)
	if math.floor(old_level / self.section_size) < math.floor(new_level / self.section_size) or new_level >= self.endingLevel then
		-- record new section
		local section_time = self.frames - self.section_start_time
		table.insert(self.section_times, section_time)
        -- table.insert(self.section_70_times, 0)
		
		table.insert(self.section_status, "none")
		self.section_start_time = self.frames
		if self.level < 2000 then
			if section_time > regret_cutoffs[section] * (self.section_size / (10 / 6)) then
				-- self.section_cool_grade = self.section_cool_grade - 1
				self.section_status[section] = "regret"
				self.coolregret_message = "REGRET!!"
				self.coolregret_timer = 300
			-- elseif self.section_cool then
			-- 	self.section_cool_grade = self.section_cool_grade + 1
			-- 	table.insert(self.section_status, "cool")
			-- else
			-- 	table.insert(self.section_status, "none")
			end
		end
		self:updateTimingsSection()
		if self.section_cool == true then
			self.previouscool = true;
		else 
			self.previouscool = false;
		end
		

		self.section_cool = false;
		self.coolchecked = false;
		self.cooldisplayed = false;
		bellringed = false
	elseif old_level % self.section_size < self.section_size * 0.7 and self.start_level < self.level / self.section_size and new_level % self.section_size >= self.section_size * 0.7 then
		-- record section 70 time
		local section_70_time = self.frames - self.section_start_time
        table.insert(self.section_70_times, section_70_time)
		-- if section <= 19 and self.previouscool == true and
		-- 		self.section_70_times[section] < self.section_70_times[section - 1] + 120 then
		-- 	self.section_cool = true
		-- 	self.coolregret_message = "COOL!!"
		-- 	self.grade_points = self.grade_points + 600
		-- 				self.coolregret_timer = 300
		-- elseif self.previouscool == true then self.section_cool = false
		-- elseif section <= 19 and self.section_70_times[section] < cool_cutoffs[section] and self.level < 2000 then
		-- 	self.section_cool = true
		-- 	self.coolregret_message = "COOL!!"
		-- 				self.coolregret_timer = 300
		-- 				self.grade_points = self.grade_points + 600
		-- end
	end
end

function ChallengerGame:updateScore(level, drop_bonus, cleared_lines)
	if self.big_mode then cleared_lines = cleared_lines / 2 end
	self:updateGrade(cleared_lines)
	if cleared_lines >= 4 then
		self.fours = self.fours + 1
	end
	if not self.clear then	
		if cleared_lines > 0 then
			self.combo = self.combo + (cleared_lines - 1) * 2
			self.score = self.score + (
				(math.ceil((level + cleared_lines) / 4) + drop_bonus) *
				cleared_lines * self.combo
			)
		else
			self.combo = 1
		end
		self.drop_bonus = 0
	end
end
local grade_point_bonuses = {
	10, 30, 60, 120, 180, 240, 300, 400, 520, 640, 780, 920, 1060, 1200, 1500, 1800, 2100, 2400, 3000, 4000, 5500, 7500, 10000
}
local grade_point_decays = {
	125, 80, 80, 50, 45, 45, 45,
	40, 40, 40, 40, 40, 30, 30, 30,
	20, 20, 20, 20, 20,
	15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
    8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
}
local combo_multipliers = {
	{ 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 },
	{ 1.0, 1.2, 1.2, 1.4, 1.4, 1.4, 1.4, 1.5, 1.5, 2.0 },
	{ 1.0, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.5 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
	{ 1.0, 1.5, 1.8, 2.0, 2.2, 2.3, 2.4, 2.5, 2.6, 3.0 },
}

function ChallengerGame:updateGrade(cleared_lines)
	if cleared_lines == 0 then
		self.grade_point_decay_counter = self.grade_point_decay_counter + 1
		if self.grade_point_decay_counter >= grade_point_decays[self.grade + 1] then
			self.grade_point_decay_counter = 0
			self.grade_points = math.max(0, self.grade_points - 1)
		end
	end
	if cleared_lines > 0 then
		self.grade_points = self.grade_points + (
			math.ceil(
				(getTableContentInLimit(grade_point_bonuses, cleared_lines) + virtualGradeScore)*
				getTableContentInLimit(combo_multipliers, cleared_lines)[math.min(self.combo, 10)]
			) * (1 + math.floor(self.level / 250))
		)
		virtualGradeScore = 0
		while self.grade_points >= gradescorereq do
			self.grade = self.grade < 19 and self.grade + 1 or 19
			self.grade_points = self.grade_points - gradescorereq
			if self:getSection() == 0 then
				gradescorereq = gradescorereq * (1 + math.abs(1 / 4))
			else
				gradescorereq = gradescorereq * math.abs(1 + ((self.level / 100) + 1) / 4)
			end
		end
	end
end
function ChallengerGame:qualifiesForMRoll()
	return true
end
function ChallengerGame:getAggregateGrade()
	if self.roll_frames > 6600 and self.LockDelayTiming < 2 and self.TilesPerFrame > 22 then
		return 19
	else return self.grade end
end
function ChallengerGame:getLetterGrade()
	local grade = self:getAggregateGrade()
	if grade < 9 then
		return tostring(9 - grade)
	elseif grade < 18 then
        return "S" .. tostring(grade - 8)
    elseif grade == 18 then
        return "GM"
	elseif grade >= 18 and self.roll_frames < 6600 then
		return "GM"
	else
		return "F-P GM"
	end
end

function ChallengerGame:drawGrid()
	if self.clear and not (self.completed or self.game_over) then
		localRollTime = localRollTime + 1
		self.grid:drawInvisible(self.mRollOpacityFunction)
	else
		self.grid:draw()
		if self.piece ~= nil and self.level < self.section_size then
			self:drawGhostPiece(ruleset)
		end
	end
end

ChallengerGame.rollOpacityFunction = function(age)
	if age < 240 then return 1
	elseif age > 300 then return 0
	else return 1 - (age - 240) / 60 end
end
function ChallengerGame.mRollOpacityFunction(age)
	local invisTime = 20 - math.floor(localRollTime / 400)
	return math.max(1 - (age / invisTime), 0)
end

function ChallengerGame:VarCheck(number, default)
	if number ~= nil then
		return number
	else
		return default
	end
end

--Called Double Sided Conversion
function ChallengerGame:DSC(compareFrom, compareTo)
	return compareFrom >= compareTo or compareFrom <= -compareTo
end

local scales = {[0] = 3600, 60, 1, 0.001, 0.001 ^ 2, 0.001 ^ 3, 0.001 ^ 4};
local indicators = {[0] = "h", "m", "s", "ms", "μs", "ns", "ps"};

function ChallengerGame:value_scale(input, scale, points)
	if points == nil or points < 0 then points = 0 end
	return math.floor(((input/scale) * 10 ^ points) + 0.5) / 10 ^ points;
end
function ChallengerGame:framesToDynamicTime(frames, fps)

	for i = 0, #scales do
		if (self:DSC(frames/fps, scales[i])) 
		then
			local value = self:value_scale(frames/fps, scales[i], 4-i);
			return value..indicators[i];
		end
	end
	return tostring(frames).." frames";
end
function ChallengerGame:framesToScaleIndex(frames, default)

	for i = 0, #scales do
		if (self:DSC(frames, scales[i])) 
		then
			return i;
		end
	end
	return default;
end
function ChallengerGame:frameScaleInSections(frames)
	local storedValue = frames
	for i = 1, self.start_level do
		if i > 4 or self.TilesPerFrame > 16 then
			storedValue = storedValue * self.percentage
		end
	end
	return storedValue
end

function ChallengerGame.colorMap(int)
	if int <= 1 then return 0.8, 0.5, 0.2, 1
	elseif int == 2 then return 0.75, 0.75, 0.75, 1
	elseif int == 3 then return 1, 0.84, 0, 1
	else return 0.13, 0.33, 1, 1
	end
end

function ChallengerGame:drawScoringInfo()
	if not self.in_menu then
		love.graphics.setColor(1, 1, 1, 1)

		local text_x = config["side_next"] and 320 or 240
		love.graphics.setFont(font_3x5_2)
		love.graphics.print(
			self.das.direction .. " " ..
			self.das.frames .. " " ..
			strTrueValues(self.prev_inputs)
		)
		love.graphics.printf("NEXT", 64, 40, 40, "left")
		love.graphics.printf("GRADE", 240, 120, 40, "left")
		-- love.graphics.printf("GRADE SCORE", 240, 240, 40, "left")
		love.graphics.printf("SCORE", 240, 200, 40, "left")
		love.graphics.printf("LEVEL", 240, 320, 40, "left")
		local sg = self.grid:checkSecretGrade()
		-- if sg >= 5 then
		-- 	love.graphics.printf("SECRET GRADE", 240, 430, 180, "left")
		-- end


		-- draw section time data
		local current_section = self:getSection()

		local section_x = 530
		local section_70_x = 440

		for section, time in pairs(self.section_times) do
			if section > 0 then
				love.graphics.printf(formatTime(time), section_x, 40 + 20 * section, 90, "left")
			end
		end

		for section, time in pairs(self.section_70_times) do
			if section > self.start_level then
				love.graphics.printf(formatTime(time), section_70_x, 40 + 20 * section, 90, "left")
			end
		end
		
		local current_x
		if table.getn(self.section_times) < table.getn(self.section_70_times) then
			current_x = section_x
		else
			current_x = section_70_x
		end

		if not self.clear then love.graphics.printf(formatTime(self.frames - self.section_start_time), current_x, 40 + 20 * current_section, 90, "left") end
		
		if(self.coolregret_timer > 0) then
			love.graphics.setColor(1, 1, self.coolregret_timer % 2, 1)
			love.graphics.printf(self.coolregret_message, 64, 400, 160, "center")
			self.coolregret_timer = self.coolregret_timer - 1
			love.graphics.setColor(1, 1, 1, 1)
		end
		love.graphics.setFont(font_3x5_3)

		if self.all_clears > 0 then
			love.graphics.setColor(self.colorMap(math.min(self.all_clears, 4)))
			love.graphics.printf("AC", 240, 260, 40, "left")
		end
		if self.medal_RE > 0 then
			love.graphics.setColor(self.colorMap(self.medal_RE))
			love.graphics.printf("RE", 300, 260, 40, "left")
		end
		love.graphics.setColor(1, 1, 1, 1)

		love.graphics.printf(self.score, 240, 220, 90, "left")
		if self.roll_frames > 6600 then love.graphics.setColor(1, 0.5, 0, 1)
		elseif self.clear then love.graphics.setColor(0, 1, 0, 1) end
		love.graphics.printf(self:getLetterGrade(), 240, 140, 90, "left")
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.rectangle("fill", 229, 164, 92, 12)
		love.graphics.setColor(1, 1, 0, 1)
		love.graphics.rectangle("fill", 230, 165, 90 * (self.grade_points / gradescorereq), 10)
		love.graphics.setColor(1, 1, 1, 1)
		-- love.graphics.printf(math.floor(self.grade_points + 0.5), text_x, 270, 90, "right")
		-- love.graphics.printf(math.floor(gradescorereq + 0.5), text_x, 290, 90, "right")
		love.graphics.printf(self.level, text_x, 340, 50, "right")
		love.graphics.printf(self:getSectionEndLevel(), text_x, 370, 50, "right")
		self:PPSCounter()
		if sg >= 5 then
			love.graphics.printf("SG: "..self.SGnames[sg], 240, 450, 180, "left")
		end

		love.graphics.setFont(font_8x11)
		if self.clear then
			love.graphics.printf(formatTime(6600-self.roll_frames), 64, 420, 160, "center")
		else
			love.graphics.printf(formatTime(self.frames), 64, 420, 160, "center")
		end
		love.graphics.setFont(font_3x5_2)
		-- if self.piece ~= nil then self.LockDelayTicks = self.piece.lock_delay end
		if self.frames < 1 then
			return
		elseif self.LockDelayResets < 0 then
			love.graphics.printf("Resets: gravity only", text_x, 430, 250, "left")
		elseif self.LockDelayMaxResets < 1 then
			love.graphics.printf("Resets: "..self.LockDelayResets.."/null", text_x, 430, 250, "left")
		elseif self.LockDelayMaxRotResets > 0 then
			love.graphics.printf(string.format("Resets: %d/%dm, %d/%dr", self.LockDelayMaxResets-self.LockDelayResets, self.LockDelayMaxResets, self.LockDelayMaxRotResets-self.LockDelayRotResets, self.LockDelayMaxRotResets), text_x, 430, 250, "left")
		else
			love.graphics.printf("Resets: "..self.LockDelayMaxResets-self.LockDelayResets .."/"..self.LockDelayMaxResets, text_x, 430, 250, "left")
		end
		love.graphics.printf("Lock: "..self:framesToDynamicTime(self.LockDelayTiming-self.LockDelayTicks, 60) .." /"..self:framesToDynamicTime(self.LockDelayTiming, 60), text_x, 410, 250, "left")
	end
end
function ChallengerGame:setNextOpacity()
	if self.in_menu then
		love.graphics.setColor(1, 1, 1, 0)
	else
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function ChallengerGame:getHighscoreData()
	return {
		grade = self:getAggregateGrade(),
		level = self.level,
		frames = self.frames,
	}
end

function ChallengerGame:onGameOver()
	switchBGM(nil)
	bgm.credit_roll.gm3:stop()
	local isTASCrazy = false
	if self.LineDelayTiming < 0.1 and self.ARELineTiming < 0.1 and self.ARETiming < 0.1 and self.LineDelayTiming < 0.1 and self.TilesPerFrame > 999999 then
		isTASCrazy = true
	end
	if self.game_over_frames > self.grid.height*2 + 15 then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setFont(font_3x5_4)

		
		if isTASCrazy then
			local isReplayTAS_SignatureDetected = false
			if scene.replay then
				isReplayTAS_SignatureDetected = scene.replay["toolassisted"]
			end
			love.graphics.printf("LOL", 60, 120, 160, "center")
			if not (TAS_mode or isReplayTAS_SignatureDetected) then
				love.graphics.setFont(font_3x5_2)
				love.graphics.printf("Tetro48's TAS isn't used", 60, 150, 160, "center")
			end
			return
		elseif self.configType == 2 then
			love.graphics.printf("MODIFIED.", 60, 120, 160, "center")
			return
		elseif self.completed then
			love.graphics.printf("SUCCESS!", 60, 120, 160, "center")
			return
		end
		love.graphics.printf("GAME OVER", 60, 120, 160, "center")
		if (self:getSection() == self.instant_gravity_sections and self.TilesPerFrame >= 20) or self.lineFreezingMechanic or self.big_mode then
			love.graphics.setFont(font_3x5_2)
			love.graphics.printf(string.format("SWITCHES:\nICY LINES: %s\nINITIAL 20G: %s\nBIG PIECES: %s", self.boolToString(self.lineFreezingMechanic), self.boolToString((self:getSection() == self.instant_gravity_sections and self.TilesPerFrame >= 20)), self.boolToString(self.big_mode))
			, 64, 160, 160, "center")
		end
	end
end
function ChallengerGame:drawMenuSection(text, value, selection, show_arrows)
	if show_arrows == nil then show_arrows = true end
	love.graphics.setFont(font_3x5_2)
	if(selectedSegment == selection) then
		love.graphics.setColor(1, 1, 0, 1)
	end
	love.graphics.printf(text, 65, 100 + 15 * selection, 160, "left")

	love.graphics.setColor(1, 1, 1, 1)
	if show_arrows then
		love.graphics.polygon("fill", 225,104 + 15 * selection,225,114 + 15 * selection,230,109 + 15 * selection)
		love.graphics.polygon("fill", 65,104 + 15 * selection,65,114 + 15 * selection,60,109 + 15 * selection)
	end
	love.graphics.printf(value, 60, 100 + 15 * selection, 160, "right")
end

function ChallengerGame:drawMenuDescription(text, selection)
	if(selectedSegment == selection) then
		love.graphics.setFont(font_3x5_2)
		love.graphics.printf(text, 5, 420, 580, "left")
	end

end
function ChallengerGame.boolToString(bool)
	if bool then return "ON" else return "OFF" end
end
local speed_indicators = {[0] = "PPH", "PPM", "PPS", "PPmS", "PPμS", "nil", "nil", "nil"}
function ChallengerGame:PPSCounter()
	love.graphics.setFont(font_3x5_2)
	love.graphics.printf(speed_indicators[self:framesToScaleIndex(self.ARETiming*2, 2)], 5, 400, 40, "left")
	love.graphics.setFont(font_3x5_3)
	love.graphics.printf(math.abs(self:value_scale(avgpps, 1/scales[self:framesToScaleIndex(self.ARETiming*2, 3)], self:framesToScaleIndex(self.ARETiming*2, 3) - 1)), 5, 415, 90, "left")
end
function ChallengerGame:drawFrame()
	love.graphics.draw(misc_graphics["frame"], 48, 64)
end
function ChallengerGame:drawLineClearAnimation()
	--nothing
end
function ChallengerGame:drawNextQueue(ruleset)
	local colourscheme
	if table.equalvalues(
		self.used_randomizer.possible_pieces,
		{"I", "J", "L", "O", "S", "T", "Z"}
	) then
		colourscheme = ({ruleset.colourscheme, ColourSchemes.Arika, ColourSchemes.TTC})[config.gamesettings.piece_colour]
	else
		colourscheme = ruleset.colourscheme
	end
	function drawPiece(piece, skin, offsets, pos_x, pos_y)
		for index, offset in pairs(offsets) do
			local x = offset.x + ruleset:getDrawOffset(piece, rotation).x + ruleset.spawn_positions[piece].x
			local y = offset.y + ruleset:getDrawOffset(piece, rotation).y + 4.7
			love.graphics.draw(blocks[skin][colourscheme[piece]], pos_x+x*16, pos_y+y*16)
		end
	end
	for i = 1, self.next_queue_length do
		self:setNextOpacity(i)
		local next_piece = self.next_queue[i].shape
		local skin = self.next_queue[i].skin
		local rotation = self.next_queue[i].orientation
		if config.side_next then -- next at side
			drawPiece(next_piece, skin, ruleset.block_offsets[next_piece][rotation], 192, -16+i*48)
		else -- next at top
			if i > 4 then
				drawPiece(next_piece, skin, ruleset.block_offsets[next_piece][rotation], 304, -224+i*48)
			else
				drawPiece(next_piece, skin, ruleset.block_offsets[next_piece][rotation], -16+i*80, -32)
			end
		end
	end
	if self.hold_queue ~= nil and self.enable_hold then
		self:setHoldOpacity()
		drawPiece(
			self.hold_queue.shape, 
			self.hold_queue.skin, 
			ruleset.block_offsets[self.hold_queue.shape][self.hold_queue.orientation],
			-16, -32
		)
	end
	return false
end
function ChallengerGame:drawCustom()
	for key, particle_system in pairs(self.particle_systems) do
		love.graphics.draw(particle_system, 0, 0)
	end
	if self.lineFreezingMechanic then
		love.graphics.setColor(0.2, 0.2, 0.9, 0.5)
		if(self:getFrozenLines() ~= nil) then if(self:getFrozenLines() > 0) then
			love.graphics.rectangle(
			"fill", 64, 400 - 16 * (self:getFrozenLines()),
			16 * self.grid.width, 16 * (self:getFrozenLines())
			)
		end end
	end

	love.graphics.setColor(1, 1, 1, 1)
	if self.in_menu then
		-- they are there to avoid 2 functions at 2 places.
		if self.configType > 0 then
			self:drawMenuSection("Level", self.endingLevel <= self.start_level*self.section_size and "ROLL" or self.start_level*self.section_size, 0)
			self:drawMenuDescription("Starting level.", 0)
		end
		love.graphics.printf("Description", 5, 400, 160, "left")
		if self.configType == 2 then
			self:drawMenuSection("Lock Delay", self:framesToDynamicTime(self:frameScaleInSections(self.LockDelayTiming), 60), 1)
			self:drawMenuSection("ARE", self:framesToDynamicTime(self:frameScaleInSections(self.ARETiming), 60), 2)
			self:drawMenuSection("Line ARE", self:framesToDynamicTime(self:frameScaleInSections(self.ARELineTiming), 60), 3)
			self:drawMenuSection("Line Delay", self:framesToDynamicTime(self:frameScaleInSections(self.LineDelayTiming), 60), 4)
			self:drawMenuSection("Percentage", self.percentage * 100 .. "%", 5)
			self:drawMenuSection("Ending Level",  self.endingLevel, 6)
			self:drawMenuSection("Section Size",  self.section_size, 7)
			self:drawMenuSection("20G", self.boolToString(self.TilesPerFrame >= 20), 8)
			self:drawMenuSection("Icy Lines", self.boolToString(self.lineFreezingMechanic), 9)
			self:drawMenuSection("Big Pieces", self.boolToString(self.big_mode), 10)

			-- description

			self:drawMenuDescription("Amount of time before autolocking on ground.", 1)
			self:drawMenuDescription("Amount of time before spawning a piece normally.", 2)
			self:drawMenuDescription("Amount of time before spawning a piece after lines were dropped.", 3)
			self:drawMenuDescription("Amount of time before dropping lines.", 4)
			self:drawMenuDescription("After passing 20g section, sets timings to be ".. self.percentage * 100 .." % of the original, for example: Lock delay: "..self:framesToDynamicTime(self.LockDelayTiming, 60).." * ".. self.percentage.. " = ".. self:framesToDynamicTime(self.LockDelayTiming * self.percentage, 60), 5)
			self:drawMenuDescription("How many levels you need to go up before completing visible part.", 6)
			self:drawMenuDescription("Section size. Breaks balance more and more further you go off 100.", 7)
			self:drawMenuDescription("Gravity switch. This effectively adds 400 levels, can be used.", 8)
			self:drawMenuDescription("Icy lines switch. Any lines within blue rectangle won't be cleared", 9)
			self:drawMenuDescription("Big mode switch. On: Pieces doubles in size.", 10)
		elseif self.configType == 1 then
			self:drawMenuSection("20G", self.boolToString(self.TilesPerFrame >= 20), 1)
			self:drawMenuSection("Icy Lines", self.boolToString(self.lineFreezingMechanic), 2)
			self:drawMenuSection("Big Pieces", self.boolToString(self.big_mode), 3)
			self:drawMenuSection("Adv. Config", "", 4, false)

			-- description

			self:drawMenuDescription("Gravity switch. This effectively adds 400 levels when on, can be used.", 1)
			self:drawMenuDescription("Icy lines switch. Any lines within blue rectangle won't be cleared", 2)
			self:drawMenuDescription("Big mode switch. On: Pieces doubles in size.", 3)
			self:drawMenuDescription("Advanced configuration. Don't go there if you don't know what are those settings.", 4)
		else
			self:drawMenuSection("Template", self.SelectedTemplateName, 0)
			self:drawMenuSection("Basic Config", "", 1, false)

			-- description

			self:drawMenuDescription("Template Selection. You can choose between different templates the developer prepared for.", 0)
			self:drawMenuDescription("Basic configuration. Feel free to change the switches.", 1)
		end
		love.graphics.setFont(font_3x5_2)
		if self.configType ~= 2 and selectedSegment == 4 then
			love.graphics.printf("Press rotation to go advanced", 64, 360, 160, "center")
		elseif attemptsSinceStart > 4 then
			love.graphics.printf("Press rotation to sta- wait, played ".. attemptsSinceStart - 1 .. " times since launch???", 55, 350, 170, "center")
		else
			love.graphics.printf("Press rotation to start", 64, 360, 160, "center")
		end
	end
	self:drawCursor(self:getScaledCursorPos(love.mouse.getX(), love.mouse.getY()))
end

function ChallengerGame:getSectionEndLevel()
	if self.level >= self.endingLevel or (self:getSection() + 1) * self.section_size > self.endingLevel then return self.endingLevel
	else return (self:getSection() + 1) * self.section_size end
end

function ChallengerGame:getBackground()
    if self.level >= self.section_size * 20 then return 19
	else return math.floor(self.level / self.section_size) end
end

return ChallengerGame