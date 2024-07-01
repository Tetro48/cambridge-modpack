require 'funcs'

local GameMode = require 'tetris.modes.gamemode'
local Piece = require 'tetris.components.piece'

local History6RollsRandomizer = require 'tetris.randomizers.history_6rolls_35bag'

local FadingInsanity = GameMode:extend()

FadingInsanity.name = "Fading Insanity"
FadingInsanity.hash = "FadingInsanity"
FadingInsanity.tagline = "A modified tolerable version of Phantomic Insanity"
FadingInsanity.tags = {"Insanity", "Fading", "Insanely difficult"}


function FadingInsanity:new(secret_inputs)
	FadingInsanity.super:new(secret_inputs)
	-- switchBGMLoop(10)
	self.grade = 0
	self.garbage = 0
	self.clear = false
	self.completed = false
	self.roll_frames = 0
	self.combo = 1
	self.roll_points = 0
	self.next_queue_window = 60
	self.hold_age = 0
	self.lock_flash = false

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

	if secret_inputs.hold then
		self.lock_flash = true
		self.rpc_details = "Trying to glance lock flash borders"
	end
end

function FadingInsanity:getARE()
	return 6
end

function FadingInsanity:getLineARE()
	return 5
end

function FadingInsanity:getDasLimit()
	return 5
end

function FadingInsanity:getLineClearDelay()
	return 4
end

function FadingInsanity:getLockDelay()
	return 8
end

function FadingInsanity:getGravity()
	return 999
end

function FadingInsanity:getGarbageLimit()
	return 6
end

function FadingInsanity:getSkin()
	return "bone"
end

function FadingInsanity:hitTorikan(old_level, new_level)
	if old_level < 300 and new_level >= 300 and self.frames > frameTime(1,35) then
		self.level = 300
		return true
	end
	if old_level < 500 and new_level >= 500 and self.frames > frameTime(2,35) then
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

function FadingInsanity:advanceOneFrame()
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

function FadingInsanity:whilePieceActive()
	self.next_queue_window = self.next_queue_window - 1
	self.hold_age = self.hold_age + 1
end

function FadingInsanity:onPieceEnter()
	self.next_queue_window = 6
	if (self.level % 100 ~= 99) and not self.clear and self.frames ~= 0 then
		self.level = self.level + 1
	end
end

local cleared_row_levels = {1, 2, 4, 6}
local torikan_roll_points = {10, 20, 30, 100}
local big_roll_points = {10, 20, 100, 200}

function FadingInsanity:onLineClear(cleared_row_count)
	if not self.clear then
		local new_level = self.level + cleared_row_levels[cleared_row_count]
		self:updateSectionTimes(self.level, new_level)
		if self:hitTorikan(self.level, new_level) then
			self.game_over = true
		elseif new_level >= 1300 then
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

function FadingInsanity:onPieceLock(piece, cleared_row_count)
	self.super:onPieceLock()
	if cleared_row_count == 0 then self:advanceBottomRow(1) end
end


function FadingInsanity:updateScore(level, drop_bonus, cleared_lines)
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

function FadingInsanity:updateSectionTimes(old_level, new_level)
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

function FadingInsanity:advanceBottomRow(dx)
	if self.level >= 500 and self.level < 1000 then
		self.garbage = math.max(self.garbage + dx, 0)
		if self.garbage >= self:getGarbageLimit() then
			self.grid:copyBottomRow()
			self.garbage = 0
		end
	end
end

function FadingInsanity:onHold()
	self.super:onHold()
	self.hold_age = 0
end

FadingInsanity.rollOpacityFunction = function(age)
	if age > 12 then return 0
	else return 1 - age / 12 end
end


--The grid is never seen
function FadingInsanity:drawGrid()
	if self.game_over or self.completed then
		self.grid:draw()
	else
		self.grid:drawInvisible(self.rollOpacityFunction, self.rollOpacityFunction, self.lock_flash)
	end
end

--Next piece sounds are stubbed out
function FadingInsanity:playNextSound() end

local function getLetterGrade(grade)
	if grade == 0 then
		return "1"
	elseif grade <= 18 then
		return "M" .. tostring(grade)
	else
		return "GM" .. tostring(grade - 18)
	end
end


function FadingInsanity:setNextOpacity(i)
	love.graphics.setColor(1, 1, 1, math.min(self.next_queue_window / 6, 1))
end

--Memory hold.
function FadingInsanity:setHoldOpacity()
	love.graphics.setColor(1, 1, 1, 1-self.hold_age/6)
end

function FadingInsanity:sectionColourFunction(section)
	if self.coolregrets[section] == 2 then
		return { 0, 1, 0, 1 }
	elseif self.coolregrets[section] == 0 then
		return { 1, 0, 0, 1 }
	else
		return { 1, 1, 1, 1 }
	end
end

function FadingInsanity:drawScoringInfo()
	FadingInsanity.super.drawScoringInfo(self)

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
	if self.lock_flash == true then
		love.graphics.setColor(1, 1, 0, 1)
	end
	love.graphics.printf(self.level, text_x, 340, 50, "right")
	if self.clear then
		love.graphics.printf(self.level, text_x, 370, 50, "right")
	else
		love.graphics.printf(math.floor(self.level / 100 + 1) * 100, text_x, 370, 50, "right")
	end
	love.graphics.setColor(1, 1, 1, 1)
	
	if sg >= 5 then
		love.graphics.printf(self.SGnames[sg], 240, 450, 180, "left")
	end
end

function FadingInsanity:getBackground()
	return math.floor(self.level / 100)
end

function FadingInsanity:getHighscoreData()
	return {
		level = self.level,
		frames = self.frames,
		grade = self.grade,
		lock_flash = self.lock_flash
	}
end

return FadingInsanity
