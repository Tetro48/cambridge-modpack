require 'funcs'

local GameMode = require 'tetris.modes.gamemode'
local Piece = require 'tetris.components.piece'

local History6RollsRandomizer = require 'tetris.randomizers.history_6rolls_35bag'

local PhantomicInsanity = GameMode:extend()

PhantomicInsanity.name = "Phantomic Insanity"
PhantomicInsanity.hash = "PhantomicInsanity"
PhantomicInsanity.tagline = "The blocks are never seen and never heard! How far can you go in this?"
PhantomicInsanity.tags = {"Insanity", "Invisible", "Near-impossible"}


function PhantomicInsanity:new()
	PhantomicInsanity.super:new()
	-- switchBGMLoop(10)
	self.grade = 0
	self.garbage = 0
	self.clear = false
	self.completed = false
	self.roll_frames = 0
	self.combo = 1
	self.roll_points = 0

	local random_number = love.math.newRandomGenerator(os.time()):random(0, 100)
	if random_number < 20 then
		self.rpc_details = "Can't hear next pieces"
	elseif random_number < 40 then
		self.rpc_details = "Has difficulty seeing"
	elseif random_number < 70 then
		self.rpc_details = "Just insane"
	else
		self.rpc_details = "Trying to memorize"
	end
	
	self.SGnames = {
		"S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9",
		"M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9",
		"GM"
	}

	self.randomizer = History6RollsRandomizer()

	self.lock_drop = true
	self.lock_hard_drop = true
	self.enable_hold = true
	self.next_queue_length = 1

	self.coolregret_message = ""
	self.coolregret_timer = 0
	self.coolregrets = { [0] = 0 }
end

function PhantomicInsanity:getARE()
	return 6
end

function PhantomicInsanity:getLineARE()
	return 5
end

function PhantomicInsanity:getDasLimit()
	return 5
end

function PhantomicInsanity:getLineClearDelay()
	return 4
end

function PhantomicInsanity:getLockDelay()
	return 8
end

function PhantomicInsanity:getGravity()
	return 999
end

function PhantomicInsanity:getGarbageLimit()
	return 6
end

function PhantomicInsanity:getSkin()
	return "bone"
end

function PhantomicInsanity:hitTorikan(old_level, new_level)
	if old_level < 300 and new_level >= 300 and self.frames > frameTime(1,35) then
		self.level = 300
		return true
	end
	if old_level < 500 and new_level >= 500 and self.frames > frameTime(2,40) then
		self.level = 500
		return true
	end
	if old_level < 800 and new_level >= 800 and self.frames > frameTime(4,08) then
		self.level = 800
		return true
	end
	if old_level < 1000 and new_level >= 1000 and self.frames > frameTime(5,00) then
		self.level = 1000
		return true
	end
	return false
end

function PhantomicInsanity:advanceOneFrame()
	if self.clear then
		self.roll_frames = self.roll_frames + 1
		if self.roll_frames < 0 then
			if self.roll_frames + 1 == 0 then
				switchBGM("credit_roll", "gm3")
				return true
			end
			return false
		elseif self.roll_frames > 3238 then
			switchBGM(nil)
			self.roll_points = self.level >= 1300 and self.roll_points + 150 or self.roll_points
			self.grade = self.grade + math.floor(self.roll_points / 100)
			self.completed = true
		end
	elseif self.ready_frames == 0 then
		self.frames = self.frames + 1
	end
	return true
end

function PhantomicInsanity:whilePieceActive()
end

function PhantomicInsanity:onPieceEnter()
	if (self.level % 100 ~= 99) and not self.clear and self.frames ~= 0 then
		self.level = self.level + 1
	end
end

local cleared_row_levels = {1, 2, 4, 6}
local torikan_roll_points = {10, 20, 30, 100}
local big_roll_points = {10, 20, 100, 200}

function PhantomicInsanity:onLineClear(cleared_row_count)
	if not self.clear then
		local new_level = self.level + cleared_row_levels[cleared_row_count]
		self:updateSectionTimes(self.level, new_level)
		if new_level >= 1300 or self:hitTorikan(self.level, new_level) then
			if new_level >= 1300 then
				self.level = 1300
				self.big_mode = true
			end
			self.clear = true
			self.grid:clear()
			self.roll_frames = -150
		else
			self.level = math.min(new_level, 1300)
		end
		self:advanceBottomRow(-cleared_row_count)
	else
		if self.big_mode then self.roll_points = self.roll_points + big_roll_points[cleared_row_count / 2]
		else self.roll_points = self.roll_points + torikan_roll_points[cleared_row_count] end
		if self.roll_points >= 100 then
			self.roll_points = self.roll_points - 100
			self.grade = self.grade + 1
		end
	end
end

function PhantomicInsanity:onPieceLock(piece, cleared_row_count)
	self.super:onPieceLock()
	if cleared_row_count == 0 then self:advanceBottomRow(1) end
end


function PhantomicInsanity:updateScore(level, drop_bonus, cleared_lines)
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


local cool_cutoffs = {
	frameTime(0,22), frameTime(0,22), frameTime(0,22), frameTime(0,22), frameTime(0,22),
	frameTime(0,22), frameTime(0,22), frameTime(0,22), frameTime(0,22), frameTime(0,22),
	frameTime(0,22), frameTime(0,22), frameTime(0,22),
}

local regret_cutoffs = {
	frameTime(0,35), frameTime(0,35), frameTime(0,35), frameTime(0,35), frameTime(0,35),
	frameTime(0,35), frameTime(0,35), frameTime(0,35), frameTime(0,35), frameTime(0,35),
	frameTime(0,35), frameTime(0,35), frameTime(0,35),
}

function PhantomicInsanity:updateSectionTimes(old_level, new_level)
	if math.floor(old_level / 100) < math.floor(new_level / 100) then
		local section = math.floor(old_level / 100) + 1
		local section_time = self.frames - self.section_start_time
		table.insert(self.section_times, section_time)
		self.section_start_time = self.frames
		if section_time <= cool_cutoffs[section] then
			self.grade = self.grade + 2
			table.insert(self.coolregrets, 2)
			self.coolregret_message = "COOL!!"
			self.coolregret_timer = 300
		elseif section_time <= regret_cutoffs[section] then
			self.grade = self.grade + 1
			table.insert(self.coolregrets, 1)
		else
			table.insert(self.coolregrets, 0)
			self.coolregret_message = "REGRET!!"
			self.coolregret_timer = 300
		end
	end
end

function PhantomicInsanity:advanceBottomRow(dx)
	if self.level >= 500 and self.level < 1000 then
		self.garbage = math.max(self.garbage + dx, 0)
		if self.garbage >= self:getGarbageLimit() then
			self.grid:copyBottomRow()
			self.garbage = 0
		end
	end
end

PhantomicInsanity.rollOpacityFunction = function(age)
	if age > 4 then return 0
	else return 1 - age / 4 end
end

PhantomicInsanity.garbageOpacityFunction = function(age)
	if age > 30 then return 0
	else return 1 - age / 30 end
end

--The grid is never seen
function PhantomicInsanity:drawGrid()
	if self.game_over or self.completed or (self.clear and self.level < 1300) then
		self.grid:draw()
	end
end

--Next piece sounds are stubbed out
function PhantomicInsanity:playNextSound() end

local function getLetterGrade(grade)
	if grade == 0 then
		return "1"
	elseif grade <= 18 then
		return "M" .. tostring(grade)
	else
		return "GM" .. tostring(grade - 18)
	end
end


function PhantomicInsanity:setNextOpacity(i)
	love.graphics.setColor(1, 1, 1, 0)
end

--Memory hold.
function PhantomicInsanity:setHoldOpacity()
	love.graphics.setColor(1, 1, 1, 0)
end

function PhantomicInsanity:sectionColourFunction(section)
	if self.coolregrets[section] == 2 then
		return { 0, 1, 0, 1 }
	elseif self.coolregrets[section] == 0 then
		return { 1, 0, 0, 1 }
	else
		return { 1, 1, 1, 1 }
	end
end

function PhantomicInsanity:drawScoringInfo()
	PhantomicInsanity.super.drawScoringInfo(self)

	love.graphics.setColor(1, 1, 1, 1)

	local text_x = config["side_next"] and 320 or 240

	love.graphics.setFont(font_3x5_2)
	love.graphics.printf("GRADE", text_x, 120, 40, "left")
	love.graphics.printf("SCORE", text_x, 200, 40, "left")
	love.graphics.printf("LEVEL", text_x, 320, 40, "left")
	local sg = self.grid:checkSecretGrade()
	if sg >= 5 then 
		love.graphics.printf("SECRET GRADE", 240, 430, 180, "left")
	end

	self:drawSectionTimesWithSplits(math.floor(self.level / 100) + 1)

	if(self.coolregret_timer > 0) then
				love.graphics.printf(self.coolregret_message, 64, 400, 160, "center")
				self.coolregret_timer = self.coolregret_timer - 1
		end

	love.graphics.setFont(font_3x5_3)
	love.graphics.printf(getLetterGrade(math.floor(self.grade)), text_x, 140, 90, "left")
	love.graphics.printf(self.score, text_x, 220, 90, "left")
	love.graphics.printf(self.level, text_x, 340, 50, "right")
	if self.clear then
		love.graphics.printf(self.level, text_x, 370, 50, "right")
	else
		love.graphics.printf(math.floor(self.level / 100 + 1) * 100, text_x, 370, 50, "right")
	end
	
	if sg >= 5 then
		love.graphics.printf(self.SGnames[sg], 240, 450, 180, "left")
	end
end

function PhantomicInsanity:getBackground()
	return math.floor(self.level / 100)
end

function PhantomicInsanity:getHighscoreData()
	return {
		level = self.level,
		frames = self.frames,
		grade = self.grade,
	}
end

return PhantomicInsanity
