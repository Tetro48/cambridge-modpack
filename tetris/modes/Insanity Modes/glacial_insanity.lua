require 'funcs'

local GameMode = require 'tetris.modes.gamemode'
local Piece = require 'tetris.components.piece'

local History6RollsRandomizer = require 'tetris.randomizers.history_6rolls_35bag'

local GlacialInsanity = GameMode:extend()

GlacialInsanity.name = "Glacial Insanity"
GlacialInsanity.hash = "GlacialInsanity"
GlacialInsanity.description = "The ultimate challenge of determination against ice. Note: The ice do not act the same as in Survival A4."
GlacialInsanity.tags = {"Insanity", "Freezing Blocks", "Near-impossible"}


if loadSound then
	loadSound("res/se/warn_garbage.wav", "warn_garbage")
end

if loadBGM then
	loadBGM("res/bgm/track11.mp3", 11)
end
if loadBGMsFromTable then
	loadBGMsFromTable("gm4_master_head", {
		"res/bgm/gm4_master_lv1_head.ogg",
		"res/bgm/gm4_master_lv2_head.ogg",
		"res/bgm/gm4_master_lv3_head.ogg",
		"res/bgm/gm4_master_lv4_head.ogg",
		[6] = "res/bgm/gm4_master_end_head.ogg"
	})

	loadBGMsFromTable("gm4_master_body", {
		"res/bgm/gm4_master_lv1_body.ogg",
		"res/bgm/gm4_master_lv2_body.ogg",
		"res/bgm/gm4_master_lv3_body.ogg",
		"res/bgm/gm4_master_lv4_body.ogg",
		"res/bgm/gm4_master_lv5.ogg",
		"res/bgm/gm4_master_end_body.ogg",
	})
end

local Grid = require 'tetris.components.grid'
local PikiiGrid = Grid:extend()
local empty = Grid(1,1).grid[1][1]

function PikiiGrid:new(width, height)
	PikiiGrid.super.new(self, width, height)
	self.pikii_height = 25
	self.pikii_rows = {}
	self.pikii_bypass = false
end

function PikiiGrid:isRowFull(row)
	if(self.pikii_rows[row]) then return false end
	local any_frozen = false
	for x = 1, self.width do
		any_frozen = any_frozen or self.grid[row][x].frozen
	end
	return not any_frozen and PikiiGrid.super.isRowFull(self, row)
end

function PikiiGrid:getClearedRowCount()
	local count = 0
	local cleared_row_table = {}
	for row = 1, self.height do
		if self:isRowFull(row) then
			count = count + 1
			if(row >= self.pikii_height and not self.pikii_bypass) then
				self.pikii_rows[row] = true
			else
				table.insert(cleared_row_table, row)
			end
		elseif(not self.pikii_rows[row]) then
			-- check frozen blocks
			local is_full = true
			for x = 1, self.width do
				if(self.grid[row][x] == empty) then
					is_full = false
					break
				end
			end
			if(is_full) then
				-- mikii clear
				for x = 1, self.width do
					if(not self.grid[row][x].frozen) then
						self.grid[row][x] = empty
						self.grid_age[row][x] = 0
					end
				end
				count = count + 1
			end
		end
	end
	self.pikii_bypass = false
	return count, cleared_row_table
end


function PikiiGrid:clearBottomRows(num)
	if num <= 0 then return end
	if num >= self.height then self:clear() return end
	for above_row = self.height, num + 1, -1 do
		self.grid[above_row] = self.grid[above_row - num]
		self.grid_age[above_row] = self.grid_age[above_row - num]
		self.grid[above_row - num] = {}
		self.grid_age[above_row - num] = {}
		self:clearSpecificRow(above_row-num)
	end
end


function PikiiGrid:draw()
	if(self.pikii_height <= self.height) then
		love.graphics.setLineWidth(2)
		love.graphics.setColor(1, 1, 1)
		love.graphics.line(64, self.pikii_height * 16, 64 + 16 * self.width, self.pikii_height * 16)
		love.graphics.setLineWidth(1)
		love.graphics.setColor(0, 0.05 + math.sin(os.clock() * 2) * 0.05, 0.2)
		love.graphics.rectangle("fill", 64, (self.pikii_height) * 16, 16 * self.width, 16 * (self.height - self.pikii_height + 1))
	end
	for y = 5, self.height do
		for x = 1, self.width do
			if blocks[self.grid[y][x].skin] and blocks[self.grid[y][x].skin][self.grid[y][x].colour] then
				if self.grid_age[y][x] < 2 then
					love.graphics.setColor(1, 1, 1, 1)
					drawImage(blocks[self.grid[y][x].skin]["F"], 48+x*16, y*16, 0, 16, 16)
				elseif self.grid[y][x].frozen then
					love.graphics.setColor(1, 1, 1, 1)
					drawImage(blocks["2tie"]["I"] or blocks[self.grid[y][x].skin]["F"], 48+x*16, y*16, 0, 16, 16)
				else
					if self.grid[y][x].colour == "X" then
						love.graphics.setColor(0, 0, 0, 0)
					elseif self.grid[y][x].skin == "bone" then
						love.graphics.setColor(1, 1, 1, 1)
					else
						if(self.pikii_rows[y]) then
							local k = (math.sin((os.clock() * 20 + y)) + 1) / 10
							love.graphics.setColor(0.7 + k, 0.7 + k, 0.9 + k / 2, 1)
						elseif(y >= self.pikii_height) then
							love.graphics.setColor(0.5, 0.5, 0.8, 1)
						else
							love.graphics.setColor(0.5, 0.5, 0.5, 1)
						end
					end
					drawImage(blocks[self.grid[y][x].skin][self.grid[y][x].colour], 48+x*16, y*16, 0, 16, 16)
				end
				if self.grid[y][x].skin ~= "bone" and self.grid[y][x].colour ~= "X" then
					love.graphics.setColor(0.8, 0.8, 0.8, 1)
					love.graphics.setLineWidth(1)
					if y > 5 and self.grid[y-1][x] == empty or self.grid[y-1][x].colour == "X" then
						love.graphics.line(48.0+x*16, -0.5+y*16, 64.0+x*16, -0.5+y*16)
					end
					if y < self.height and self.grid[y+1][x] == empty or
					(y + 1 <= self.height and self.grid[y+1][x].colour == "X") then
						love.graphics.line(48.0+x*16, 16.5+y*16, 64.0+x*16, 16.5+y*16)
					end
					if x > 1 and self.grid[y][x-1] == empty then
						love.graphics.line(47.5+x*16, -0.0+y*16, 47.5+x*16, 16.0+y*16)
					end
					if x < self.width and self.grid[y][x+1] == empty then
						love.graphics.line(64.5+x*16, -0.0+y*16, 64.5+x*16, 16.0+y*16)
					end
				end
			end
		end
	end
end

function PikiiGrid:clearPikii()
	local to_clear = {}
	for row, _ in pairs(self.pikii_rows) do
		table.insert(to_clear, row)
	end
	self.pikii_rows = {}
	table.sort(to_clear)
	-- Bypass the regular clearing functions entirely
	for _, row in ipairs(to_clear) do
		for above_row = row, 2, -1 do
			self.grid[above_row] = self.grid[above_row - 1]
			self.grid_age[above_row] = self.grid_age[above_row - 1]
		end
		self.grid[1] = {}
		self.grid_age[1] = {}
		for i = 1, self.width do
			self.grid[1][i] = empty
			self.grid_age[1][i] = 0
		end
	end
end

function PikiiGrid:initMikii()
	for y = 1, self.height do
		for x = 1, self.width do
			if(self.grid[y][x] ~= empty) then
				self.grid[y][x].mikii_immune = true
			end
		end
	end
end

function PikiiGrid:thawMikii()
	for y = 1, self.height do
		for x = 1, self.width do
			local block = self.grid[y][x]
			if (block and block ~= empty) then
				block.frozen = false
				block.mikii_immune = true
			end
		end
	end
end

function PikiiGrid:updateMikii(delay)
	for y = 1, self.height do
		for x = 1, self.width do
			local block = self.grid[y][x]
			if(block and block ~= empty) then
				if block.mikii_immune then
					self.grid_age[y][x] = 2
				end
				if not block.mikii_immune and not block.frozen and self.grid_age[y][x] >= delay then
					block.frozen = true
				end
			end
		end
	end
end


function GlacialInsanity:new(...)
	GlacialInsanity.super.new(self, ...)
	self.grid = PikiiGrid(10, 24)
	self.grade = 0
	self.last_pikii_row_count = 0
	self:playBGMLevel(-1)

	self.grid.pikii_height = 15

	self.medals = {
		quads = 0;
		pikii = 0;
	}
	self.ice_accum = 0
	self.ice_warning = 0
	self.clear = false
	self.completed = false
	self.roll_frames = 0
	self.combo = 1
	self.roll_points = 0

	local random_number = love.math.newRandomGenerator(os.time()):random(0, 100)
	if random_number < 20 then
		self.rpc_details = "Can't hear next pieces"
	elseif random_number < 40 then
		self.rpc_details = "Has difficulty with ice"
	elseif random_number < 70 then
		self.rpc_details = "Just insane"
	else
		self.rpc_details = "Trying to defrost"
	end
	
	self.SGnames = {
		"S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9",
		"M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9",
		"GM"
	}

	self.display_frames = 0

	self.randomizer = History6RollsRandomizer()

	self.lock_drop = true
	self.lock_hard_drop = true
	self.enable_hold = true
	self.next_queue_length = 3

	self.coolregret_message = ""
	self.coolregret_timer = 0
	self.coolregrets = { [0] = 0 }
end

function GlacialInsanity:initialize(ruleset)
	GameMode.initialize(self, ruleset)
	self.backstep_info = {
		{
			grid = {};
			next_queue = copy(self.next_queue);
			frames = 0;
			level = self.level;
			held_shape = nil;
		}
	}
end

function GlacialInsanity:getARE()
	return 6
end

function GlacialInsanity:getLineARE()
	return 5
end

function GlacialInsanity:getDasLimit()
	return 5
end

function GlacialInsanity:getLineClearDelay()
	return 4
end

function GlacialInsanity:getLockDelay()
	if self.level < 100 then
		return 16
	elseif self.level < 200 then
		return 13
	elseif self.level < 300 then
		return 11
	elseif self.level < 400 then
		return 9
	elseif self.level < 500 then
		return 8
	elseif self.level < 1200 then
		return 21
	elseif self.level < 2000 then
		return 15
	elseif self.level < 2400 then
		return 12
	end
	return 8
end

function GlacialInsanity:getGravity()
	return 999
end

function GlacialInsanity:getGarbageLimit()
	return math.max(2, math.ceil((self.medals.pikii * 2 + self.medals.quads) / 20))
end

function GlacialInsanity:getSkin()
	return "bone"
end

function GlacialInsanity:hitTorikan(old_level, new_level)
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

function GlacialInsanity:advanceOneFrame()
	if self.clear then
		if self.ready_frames == 0 or self.roll_frames == -1 then
			self.roll_frames = self.roll_frames + 1
		end
		if self.roll_frames < 0 then
			if self.roll_frames + 1 == -1530 then
				if bgm["gm4_master_body"] and bgm["gm4_master_body"][6] and bgm["gm4_master_head"] and bgm["gm4_master_head"][6] then
					self:playBGMLevel(6)
				else
					switchBGM("credit_roll", "gm3")
				end
				return true
			end
			if self.roll_frames + 1 == -1230 then
				self:applyBackstep()
			elseif self.roll_frames + 1 < 0 and self.roll_frames + 1 > -1230 then
				self:applyBackstep(math.max(0, self.frames - (math.min(self.frames, frameTime(1, 5)) * self.easeInSine((self.roll_frames+1230)/1230))))
			end
			if self.roll_frames + 1 == 0 then
				self:applyBackstep()
				self.ready_frames = 100
			end
			if self.lcd == 0 then
				return false
			end
		elseif self.roll_frames > frameTime(1, 5) then
			switchBGM(nil)
			self:playBGMLevel(-1)
			self.roll_points = self.level >= 3000 and self.roll_points + 150 or self.roll_points
			self.grade = self.grade + math.floor(self.roll_points / 100)
			self.completed = true
		end
	elseif self.ready_frames == 1 then
		if bgm[11] and self.hash == "GlacialInsanity" then
			switchBGMLoop(11)
		elseif bgm["gm4_master_body"] and bgm["gm4_master_body"][3] and bgm["gm4_master_head"] and bgm["gm4_master_head"][3] then
			self:playBGMLevel(3)
			self.gm4_music_mode = true
		else
			switchBGMLoop(10)
		end
	elseif self.ready_frames == 0 then
		self.frames = self.frames + 1
		self.display_frames = self.display_frames + 1
	end
	return true
end

function GlacialInsanity:initializeOrHold(inputs, ruleset)
	self.backstep_piece_shape = self.next_queue[1].shape
	self:addBackstep()
	self.super.initializeOrHold(self, inputs, ruleset)
end

function GlacialInsanity:applyBackstep(frames)
	local backstep_data = table.remove(self.backstep_info)
	if type(frames) == "number" and backstep_data.frames < frames then
		table.insert(self.backstep_info, backstep_data)
		return
	end
	self.display_frames = backstep_data.frames;
	self.grid:applyMap(backstep_data.grid)
	for y, row in pairs(self.grid.grid_age) do
		for x, block in pairs(row) do
			row[x] = 1
		end
	end
	self.level = backstep_data.level;
	self.next_queue = backstep_data.next_queue;
	self.hold_queue = backstep_data.held_shape and {
		skin = self:getSkin(),
		shape = backstep_data.held_shape,
		orientation = backstep_data.held_orientation,
	} or nil
	self.next_queue[2].orientation = self.ruleset:getDefaultOrientation(self.next_queue[2].shape)
	playSE("cursor")
end

function GlacialInsanity:addBackstep()
	local extracted_grid = {}
	for y, row in pairs(self.grid.grid) do
		extracted_grid[y] = {}
		for x, block in pairs(row) do
			extracted_grid[y][x] = block ~= empty and copy(block) or empty
		end
	end
	table.insert(self.backstep_info, {
		grid = extracted_grid;
		next_queue = copy(self.next_queue);
		frames = self.frames;
		level = self.level;
		held_shape = self.hold_queue and self.hold_queue.shape or nil;
		held_orientation = self.hold_queue and self.hold_queue.orientation or nil;
	})
end

function GlacialInsanity:whilePieceActive()
end

function GlacialInsanity:onPieceEnter()
	if (self.level % 100 ~= 99) and self.frames ~= 0 then
		self.level = self.level + 1
	end
	if self.gm4_music_mode and self.level > 470 and self.level < 500 then
		switchBGM(nil)
		self:playBGMLevel(-1)
	end
end

local cleared_row_levels = {1, 2, 4, 6}
local torikan_roll_points = {10, 20, 30, 100}
local big_roll_points = {10, 20, 100, 200}

function GlacialInsanity:onLineClear(cleared_row_count)
	if not self.clear then
		local new_level = self.level + (cleared_row_levels[cleared_row_count] or 1) + math.floor((self.medals.pikii / 25) + (self.medals.quads / 10))
		self:updateSectionTimes(self.level, new_level)
		if self:hitTorikan(self.level, new_level) then
			self.game_over = true
		elseif new_level >= 3000 then
			self.level = 3000
			self.clear = true
			self.roll_frames = -1710
			self.piece = nil
			switchBGM(nil)
			self:playBGMLevel(-1)
		else
			self.level = math.min(new_level, 3000)
		end
		self:advanceBottomRow(-cleared_row_count / 8)
	else
		self.level = self.level + (cleared_row_levels[cleared_row_count] or 1) + math.floor((self.medals.pikii / 25) + (self.medals.quads / 10))
		if self.big_mode then self.roll_points = self.roll_points + big_roll_points[cleared_row_count / 2]
		else self.roll_points = self.roll_points + (torikan_roll_points[cleared_row_count] or 100) end
		if self.roll_points >= 100 then
			self.roll_points = self.roll_points - 100
			self.grade = self.grade + 1
		end
	end
end

function GlacialInsanity:onPieceLock(piece, cleared_row_count)
	self.super:onPieceLock()
	if cleared_row_count == 0 then self:advanceBottomRow(1) end
	if cleared_row_count == 3 then
		if self.level >= 500 then
			self.grid:clearBottomRows(1)
		end
	elseif cleared_row_count >= 4 then
		self.medals.quads = self.medals.quads + 1
		if self.level >= 500 then
			self.grid:clearBottomRows(2)
		end
	end
	local pikii_row_count = 0
	for _, _ in pairs(self.grid.pikii_rows) do
		pikii_row_count = pikii_row_count + 1
	end
	local pikii_clears = (pikii_row_count - self.last_pikii_row_count)
	self.last_pikii_row_count = pikii_row_count
	self.medals.pikii = self.medals.pikii + pikii_clears
end


function GlacialInsanity:updateScore(level, drop_bonus, cleared_lines)
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


function GlacialInsanity:clearPikii()
	-- fix cleared row table
	local pikii_rows_below = {}
	local pikii_count = 0
	for y = self.grid.height, 1, -1 do
		pikii_rows_below[y] = pikii_count
		pikii_count = pikii_count + (self.grid.pikii_rows[y] and 1 or 0)
	end
	-- Fix line clear animation
	local block_table = {}
	for y, row in pairs(self.cleared_block_table) do
		block_table[y + pikii_rows_below[y]] = row
	end
	self.cleared_block_table = block_table
	self.grid:clearPikii()

	self.last_pikii_row_count = 0
	self.grid.pikii_bypass = true
end


function GlacialInsanity:updateSectionTimes(old_level, new_level)
	if math.floor(old_level / 100) < math.floor(new_level / 100) then
		local section = math.floor(old_level / 100) + 1
		local section_time = self.frames - self.section_start_time
		table.insert(self.section_times, section_time)
		self:clearPikii()
		if math.floor(new_level / 100) == 5 then
			self.ice_accum = 0
			self.grid.pikii_height = 25
			if self.gm4_music_mode then
				self:playBGMLevel(5)
			end
		end
		self.section_start_time = self.frames
		if section_time <= frameTime(0,18) then
			self.grade = self.grade + 2
			table.insert(self.coolregrets, 2)
			self.coolregret_message = "COOL!!"
			self.coolregret_timer = 300
		elseif section_time <= frameTime(0,35) then
			self.grade = self.grade + 1
			table.insert(self.coolregrets, 1)
		else
			table.insert(self.coolregrets, 0)
			self.coolregret_message = "REGRET!!"
			self.coolregret_timer = 300
		end
	end
end

function GlacialInsanity:advanceBottomRow(dx)
	if self.level >= 500 then
		self.ice_accum = math.max(self.ice_accum + dx, 0)
		if self.ice_accum >= self:getGarbageLimit() - 4 and self.ice_warning < 1 then
			self.ice_warning = 1
			playSE("warn_garbage")
		elseif self.ice_accum >= self:getGarbageLimit() - 2 and self.ice_warning < 2 then
			self.ice_warning = 2
		end
		if self.ice_accum >= self:getGarbageLimit() then
			self.grid:updateMikii(0)
			self.ice_accum = 0
			self.ice_warning = 0
		end
	else
		self.ice_warning = 0
	end
end

GlacialInsanity.rollOpacityFunction = function(age)
	if age > 4 then return 0
	else return 1 - age / 4 end
end

GlacialInsanity.garbageOpacityFunction = function(age)
	if age > 30 then return 0
	else return 1 - age / 30 end
end

-- --The grid is never seen
-- function GlacialInsanity:drawGrid()
-- 	if self.game_over or self.completed then
-- 		self.grid:draw()
-- 	end
-- end

--Next piece sounds are stubbed out
function GlacialInsanity:playNextSound() end

local function getLetterGrade(grade)
	if grade == 0 then
		return "1"
	elseif grade <= 45 then
		return "M" .. tostring(grade)
	else
		return "GM" .. tostring(grade - 45)
	end
end


function GlacialInsanity:setNextOpacity(i)
	love.graphics.setColor(1, 1, 1, 1)
end

--Memory hold.
function GlacialInsanity:setHoldOpacity()
	love.graphics.setColor(1, 1, 1, 1)
end

function GlacialInsanity:sectionColourFunction(section)
	if self.coolregrets[section] == 2 then
		return { 0, 1, 0, 1 }
	elseif self.coolregrets[section] == 0 then
		return { 1, 0, 0, 1 }
	else
		return { 1, 1, 1, 1 }
	end
end

local bgm_level = 0
local was_paused = false

function GlacialInsanity:handleBGM()
	if bgm.gm4_master_head and bgm.gm4_master_head[bgm_level] and bgm.gm4_master_body and bgm.gm4_master_body[bgm_level] then
		---@type love.Source
		local musicObj;
		if not bgm.gm4_master_head[bgm_level]:isPlaying() and not bgm.gm4_master_body[bgm_level]:isPlaying() then
			switchBGMLoop("gm4_master_body", bgm_level)
		end
	end
end

function GlacialInsanity:playBGMLevel(level)
	bgm_level = level
	if bgm.gm4_master_head and bgm.gm4_master_head[level] and bgm.gm4_master_body and bgm.gm4_master_body[level] then
		switchBGM("gm4_master_head", level)
		bgm.gm4_master_head[level]:setLooping(false)
	elseif bgm.gm4_master_body and bgm.gm4_master_body[level] then
		switchBGMLoop("gm4_master_body", level)
	else
		if level == 6 then
			switchBGMLoop("credit_roll", "gm4_endgame")
		end
		switchBGMLoop("gm4_master", level)
	end
end

function GlacialInsanity.easeInSine(x)
	return 1 - math.cos((x * math.pi) / 2);
end

function GlacialInsanity:drawScoringInfo()
	-- GlacialInsanity.super.drawScoringInfo(self)

	pitchBGM(1)
	if scene.paused and not was_paused then
		resumeBGM()
	end
	self:handleBGM()
	was_paused = scene.paused
	
	love.graphics.setColor(1, 1, 1, 1)

	local text_x = config["side_next"] and 320 or 240

	love.graphics.setFont(font_3x5_2)
	love.graphics.printf("GRADE", text_x, 120, 40, "left")
	love.graphics.printf("SCORE", text_x, 200, 40, "left")
	love.graphics.printf("QUADS", text_x, 260, 80, "left")
	love.graphics.printf("PIKII", text_x, 280, 80, "left")
	love.graphics.printf("LEVEL", text_x, 320, 80, "left")
	love.graphics.printf(self.medals.quads, text_x, 260, 80, "right")
	love.graphics.printf(self.medals.pikii, text_x, 280, 80, "right")
	love.graphics.printf("LEVEL", text_x, 320, 40, "left")
	local sg = self.grid:checkSecretGrade()
	if sg >= 5 then 
		love.graphics.printf("SECRET GRADE", 240, 430, 180, "left")
	end

	if config["side_next"] then
		love.graphics.printf("NEXT", 240, 56, 40, "left")
	else
		love.graphics.printf("NEXT", 112, 10, 40, "left")
	end
	
	self:drawSectionTimesWithSplits(math.floor(self.level / 100) + 1)

	if(self.coolregret_timer > 0) then
				love.graphics.printf(self.coolregret_message, 64, 400, 160, "center")
				self.coolregret_timer = self.coolregret_timer - 1
		end

	love.graphics.setColor(1, 0, 0, 1)
	if self.ice_warning > 0 then
		love.graphics.printf(string.rep("!", self.ice_warning), font_3x5_4, 64, 80, 160, "center")
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font_3x5_3)
	love.graphics.printf(getLetterGrade(math.floor(self.grade)), text_x, 140, 90, "left")
	love.graphics.printf(self.score, text_x, 220, 120, "left")
	love.graphics.printf(self.level, text_x, 340, 50, "right")
	
	if sg >= 5 then
		love.graphics.printf(self.SGnames[sg], 240, 450, 180, "left")
	end
	love.graphics.setFont(font_8x11)
	if self.clear then
		if self.roll_frames < 0 then
			love.graphics.printf(formatTime(self.display_frames), 64, 420, 160, "center")
		else
			love.graphics.printf(formatTime(math.min(3900 - self.roll_frames, 3900)), 64, 420, 160, "center")
		end
	else
		love.graphics.printf(formatTime(self.frames), 64, 420, 160, "center")
	end
	if self.roll_frames > -1530 and self.roll_frames < -1470 then
		love.graphics.setColor(1, 0, 0, self.easeInSine((self.roll_frames + 1530) / 60))
		love.graphics.printf("END GAME", 204 - (self.roll_frames + 1530), 160, 160, "center", 0, 4 - ((self.roll_frames + 1530)/20), 1, 80)
		love.graphics.printf("END GAME", 84 + (self.roll_frames + 1530), 160, 160, "center", 0, 4 - ((self.roll_frames + 1530)/20), 1, 80)
	elseif self.roll_frames >= -1470 and self.roll_frames < -1230 then
		love.graphics.setColor(1, 1 - (self.roll_frames + 1470) / 30, 1 - (self.roll_frames + 1470) / 30)
		love.graphics.printf("END GAME", 144, 160, 160, "center", 0, 1, 1, 80)
	end
end

-- This was taken from Reddit.
local INVERSION_SHADER = love.graphics.newShader[[
	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords) {
		vec4 col = texture2D( texture, texture_coords );
		return vec4(1-col.r, 1-col.g, 1-col.b, col.a);
	}
]]

function GlacialInsanity:drawBackground()
	local old_shader = love.graphics.getShader()
	love.graphics.setShader(INVERSION_SHADER)
	self.super.drawBackground(self)
	love.graphics.setShader(old_shader)
end

function GlacialInsanity:getBackground()
	return math.floor(self.level / 100)
end

function GlacialInsanity:getHighscoreData()
	return {
		level = self.level,
		frames = self.frames,
		grade = self.grade,
	}
end

return GlacialInsanity
