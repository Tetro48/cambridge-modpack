require 'funcs'

local function findPhantomicInsanityMode()
	for key, value in pairs(game_modes) do
		if value.hash == "PhantomicInsanity" then
			return value
		end
	end
	if pcall(require, "tetris.modes.Insanity Modes.phantomic_insanity") == true then
		return require "tetris.modes.Insanity Modes.phantomic_insanity"
	end
	if pcall(require, "tetris.modes.phantomic_insanity") == true then
		return require "tetris.modes.phantomic_insanity"
	end
end

local PhantomicInsanity = findPhantomicInsanityMode()

local FadingInsanity = PhantomicInsanity:extend()

FadingInsanity.name = "Fading Insanity"
FadingInsanity.hash = "FadingInsanity"
FadingInsanity.tagline = "A modified tolerable version of Phantomic Insanity"
FadingInsanity.tags = {"Insanity", "Fading", "Insanely difficult"}


function FadingInsanity:new(secret_inputs)
	FadingInsanity.super.new(self, secret_inputs)
	self.next_queue_window = 60
	self.hold_age = 0
	self.lock_flash = false
	if secret_inputs.hold then
		self.lock_flash = true
		self.rpc_details = "Trying to glance lock flash borders"
	end
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

function FadingInsanity:setNextOpacity(i)
	love.graphics.setColor(1, 1, 1, math.min(self.next_queue_window / 6, 1))
end

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

	local text_x = config["side_next"] and 320 or 240
	
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
