local GameMode = require "tetris.modes.gamemode"
local History6RollsRandomizer = require "tetris.randomizers.history_6rolls_35bag"

--end time is about 9h at est. 1pps
local LongEndurance = GameMode:extend()
LongEndurance.name = "Long Endurance"
LongEndurance.hash = "LongEndurance"
LongEndurance.tagline = "A Desert Bus-esque endurance mode where you can also save the game state by exiting. It auto-pauses when resuming from loading game state, as to not instantly game over."
LongEndurance.tags = {"Endurance", "Includes Save Data"}
--Amount of lines to get to the next level
LongEndurance.level_milestones = {
	--Starter game
	40, 100, 175, 300,
	--Early game
	450, 600, 800, 1000,
	1250, 1500, 1750, 2000,
	--Mid game
	2300, 2600, 3000, 3450, 3900,
	4400, 5000, 5750, 6500,
	--Late game
	7250, 8000, 9000, 10000, 11250, 1/0
}
local playedReadySE = false
local playedGoSE = false

local binser = require "libs.binser"

function LongEndurance:new(secret, ...)
	if secret.generic_1 and secret.generic_3 and secret.generic_4 and not secret.generic_2 then
		self.wipe_save = true
		secret.generic_1 = nil
		secret.generic_2 = nil
		secret.generic_3 = nil
		secret.generic_4 = nil
	end
	self.super.new(self, secret, ...)
	self.next_queue_length = 4
	self.additive_gravity = false
	self.lock_drop = true
	self.lock_hard_drop = true
	self.enable_hold = false
	playedReadySE = false
	playedGoSE = false
	self.ready_frames = 60
	self.ending_lines = 11250;

	self.visual_rng = love.math.newRandomGenerator(os.time())

	self.falling_text_table = {}

	self.replay_mode = scene.title == "Replay" or scene.title == "Replays"
	if not (config.mode_states and config.mode_states.long_endurance) or self.replay_mode then
		self.first_init = true
		config.mode_states = config.mode_states or {}
		config.mode_states.long_endurance = config.mode_states.long_endurance or {}
	end
	self.randomizer = History6RollsRandomizer()
end

local function expDecay(a, b, decay, dt)
	return b+(a-b)*math.exp(-decay*dt)
end

function LongEndurance:getSaveData()
	local id = self.ruleset.name .. self.ruleset.hash
	if config.mode_states.long_endurance[id] then
		local cfg_game_data = config.mode_states.long_endurance[id]
		config.mode_states.long_endurance[id] = nil
		return cfg_game_data
	end
	if love.filesystem.getInfo("saves/long_endurance-"..id..".sav", "file") then
		local contents = love.filesystem.read("saves/long_endurance-"..id..".sav")
		return binser.d(contents)[1]
	end
end

function LongEndurance:initialize(ruleset)
	self.ruleset = ruleset
	local game_state = self:getSaveData()
	if not (self.replay_mode or self.first_init) and game_state and not self.wipe_save then
		self.game_state = game_state
		if self.game_state.piece then
			self.disable_piece_sound = true
			self:initializeNextPiece({}, ruleset, self.game_state.piece, false)
			self.piece.position = self.game_state.piece_state.position
			self.piece.gravity = self.game_state.piece_state.gravity
			self.piece.lock_delay = self.game_state.piece_state.lock_delay
			self.piece.rotation = self.game_state.piece_state.rotation
			self.disable_piece_sound = false
		end
		self.lines = self.game_state.lines
		self.grid.grid = self.game_state.grid_data
		self.replay_inputs = self.game_state.replay_inputs
		self.next_queue = self.game_state.next_queue
		self.ready_frames = 0
		if self.game_state.delays then
			self.are = self.game_state.delays.are
			self.lcd = self.game_state.delays.lcd
			self.das = self.game_state.delays.das
		else
			self.save_replay = config.gamesettings.save_replay == 1 and self.game_state.replay_inputs and self.game_state.replay_inputs.inputs and self.game_state.replay_inputs.inputs[1]
			self.game_over = true
		end
		self.ready_frames = self.game_state.ready_frames or 0
		if scene.title ~= "Game" then
			playSE("go")
		else
			playSE("error")
		end
		love.math.setRandomSeed(self.game_state.rng.low_seed, self.game_state.rng.high_seed)
		love.math.setRandomState(self.game_state.rng.current_state)
		self.frames = self.game_state.time
		for y, row in pairs(self.grid.grid) do
			for x, block in pairs(row) do
				self.grid.grid_age[y][x] = 999
				if self.grid.grid[y][x].colour == "" then
					self.grid:clearBlock(y-1, x-1)
				end
			end
		end
		self.randomizer.history = self.game_state.rng.history
		self.randomizer.pool = self.game_state.rng.pool
		self.randomizer.droughts = self.game_state.rng.droughts
		self.randomizer.first = false
	else
		self.game_state =  {
			level = 0;
			lines = 0;
			score = 0;
			grid_data = self.grid.grid;
			replay_inputs = self.replay_inputs;
			next_queue = self.next_queue;
			rng = {
				low_seed = self.random_low;
				high_seed = self.random_high;
				initial_state = self.random_state;
				current_state = self.random_state;
				history = self.randomizer.history;
				pool = self.randomizer.pool;
				droughts = self.randomizer.droughts;
			};
		}
	end
	-- generate next queue
	self.used_randomizer = (
		table.equalvalues(
			table.keys(ruleset.colourscheme),
			self.randomizer.possible_pieces
		) and
		self.randomizer or BagRandomizer(table.keys(ruleset.colourscheme))
	)
	if self.game_state and self.game_state.next_queue and #self.game_state.next_queue == 0 then
		for i = 1, math.max(self.next_queue_length, 1) do
			table.insert(self.next_queue, self:getNextPiece(ruleset))
		end
	end
	self.lock_on_soft_drop = ({ruleset.softdrop_lock, self.instant_soft_drop, false, true })[config.gamesettings.manlock]
	self.lock_on_hard_drop = ({ruleset.harddrop_lock, self.instant_hard_drop, true,  false})[config.gamesettings.manlock]
end

function LongEndurance:playNextSound(ruleset)
	if not self.disable_piece_sound then
		playSE("blocks", ruleset.next_sounds[self.next_queue[1].shape])
	end
end


function LongEndurance:onPieceLock(piece, cleared_row_count)
	if cleared_row_count > 0 then
		local score_increment = (({1, 3, 7, 15, 20})[cleared_row_count] or -10) * (self.game_state.level + 1)
		if self.lines + cleared_row_count >= self.level_milestones[self.game_state.level + 1] then
			score_increment = (({1, 3, 7, 15, 20})[cleared_row_count] or -10) * (self.game_state.level + 2)
		end
		table.insert(self.falling_text_table, {
			text = string.format("(%s%d)", score_increment > 0 and "+" or "", score_increment);
			x = 64 + piece.position.x * 16;
			y = -16 + piece.position.y * 16;
			r = 0;
			scale = 0.1;
			delay = 30;
			vy = -3;
			vx = self.visual_rng:random(-16, 16) / 4;
			vr = self.visual_rng:random(-16, 16) / 400;
		})
	end
end

function LongEndurance:advanceOneFrame(inputs, ruleset)
	for key, txt in pairs(self.falling_text_table) do
		txt.scale = expDecay(txt.scale, 1, 30, 1/60)
		if txt.delay <= 0 then
			txt.x = txt.x + txt.vx
			txt.y = txt.y + txt.vy
			txt.r = txt.r + txt.vr
			txt.vx = txt.vx * 0.95
			txt.vy = txt.vy + 0.2
			if txt.y > 999 then
				self.falling_text_table[key] = nil
			end
		else
			txt.delay = txt.delay - 1
		end
	end
	if self.ready_frames == 0 then
		self.frames = self.frames + 1
	end
	if not self.pause_stats_loaded and not self.replay_mode then
		self.pause_stats_loaded = true
		self.pause_time = self.game_state.pause_time or 0
		self.pause_count = self.game_state.pause_count or 0
	end
	self.game_state.time = self.frames
end

function LongEndurance:processDelays(inputs, ruleset, drop_speed)
	if self.ready_frames > 0 then
		self:checkBufferedInputs(inputs)
		if not playedReadySE then
			playedReadySE = true
			playSEOnce("ready")
		end
		self.ready_frames = self.ready_frames - 1
		if self.ready_frames == 30 and not playedGoSE then
			playedGoSE = true
			playSEOnce("go")
		end
		if self.ready_frames == 0 and not self.piece then
			self:initializeOrHold(inputs, ruleset)
		end
	elseif self.lcd > 0 then
		self:checkBufferedInputs(inputs)
		self.lcd = self.lcd - 1
		self:areCancel(inputs, ruleset)
		if self.lcd == 0 then
			local cleared_row_count = self.grid:getClearedRowCount()
			self.grid:clearClearedRows()
			self:afterLineClear(cleared_row_count)
			playSE("fall")
			if self.are == 0 then
				self:initializeOrHold(inputs, ruleset)
			end
		end
	elseif self.are > 0 then
		self:checkBufferedInputs(inputs)
		self.are = self.are - 1
		self:areCancel(inputs, ruleset)
		if self.are == 0 then
			self:initializeOrHold(inputs, ruleset)
		end
	end
end

function LongEndurance:drawReadyGo()
	-- ready/go graphics
	love.graphics.setColor(1, 1, 1, 1)

	if self.ready_frames <= 60 and self.ready_frames > 32 then
		love.graphics.draw(misc_graphics["ready"], 144 - 50, 240 - 14)
	elseif self.ready_frames <= 30 and self.ready_frames > 2 then
		love.graphics.draw(misc_graphics["go"], 144 - 27, 240 - 14)
	end
end

function LongEndurance:onLineClear(lines)
	self.lines = self.lines + lines
	self.game_state.lines = self.lines
	if self.lines >= self.level_milestones[self.game_state.level + 1] then
		self.game_state.level = self.game_state.level + 1
		playSE("levelup")
	end
	self.game_state.score = self.game_state.score + (({1, 3, 7, 15, 20})[lines] or -10) * (self.game_state.level + 1)
	if self.lines >= self.ending_lines then
		self.completed = true
	end
end

---@param frames number
function LongEndurance.formatTime(frames)
	-- returns a hh:mm:ss representation of the time in frames given 
	if frames < 0 then return formatTime(0) end
	local hour, min, sec
	hour = math.floor(frames/3600/60)
	min  = math.floor(frames/3600) % 60
	sec  = math.floor(frames/60) % 60
	local str = string.format("%02d:%02d:%02d", hour, min, sec)
	return str
end

function LongEndurance:saveReplay()
	local binser = require "libs.binser"
	-- Save replay.
	local replay = {}
	replay["cambridge_version"] = version
	replay["highscore_data"] = self:getHighscoreData()
	replay["ruleset_override"] = self.ruleset_override
	replay["properties"] = self.replay_properties
	replay["toolassisted"] = self.toolassisted
	replay["ineligible"] = self.ineligible or self.ruleset.ineligible
	replay["inputs"] = self.replay_inputs
	replay["random_low"] = self.game_state.rng.low_seed
	replay["random_high"] = self.game_state.rng.high_seed
	replay["random_state"] = self.game_state.rng.initial_state
	replay["mode"] = self.name
	replay["ruleset"] = self.ruleset.name
	replay["mode_hash"] = self.hash
	replay["ruleset_hash"] = self.ruleset.hash
	replay["sha256_table"] = scene.sha_tbl
	replay["timer"] = self.frames
	replay["score"] = self.score
	replay["level"] = self.game_state.level
	replay["lines"] = self.lines
	replay["gamesettings"] = config.gamesettings
	replay["secret_inputs"] = self.secret_inputs
	replay["delayed_auto_shift"] = config.das
	replay["auto_repeat_rate"] = config.arr
	replay["das_cut_delay"] = config.dcd
	replay["timestamp"] = os.time()
	replay["pause_count"] = self.pause_count
	replay["pause_time"] = self.pause_time
	replay["pause_timestamps"] = self.pause_timestamps
	if love.filesystem.getInfo("replays") == nil then
		love.filesystem.createDirectory("replays")
	end
	local init_name
	if config.gamesettings.replay_name == 2 then
		init_name = string.format("replays/%s.crp", os.date("%Y-%m-%d_%H-%M-%S"))
	else
		init_name = string.format("replays/%s - %s - %s.crp", self.name, self.ruleset.name, os.date("%Y-%m-%d_%H-%M-%S"))
	end
	local replay_name = init_name
	local replay_number = 0
	while true do
		if love.filesystem.getInfo(replay_name, "file") then
			replay_number = replay_number + 1
			replay_name = string.format("%s (%d)", init_name, replay_number)
		else
			break
		end
	end
	love.filesystem.write(replay_name, binser.serialize(replay))
	if loaded_replays and insertReplay and sortReplays then
		insertReplay(replay)
		sortReplays()
	end
end
function LongEndurance:onExit()
	if not self.replay_mode then
		-- self:addReplayInput({})
		self.game_state.rng.current_state = love.math.getRandomState()
		if type(self.piece) == "table" and not self.piece.locked then
			self.game_state.piece = {
				skin = self.piece.skin,
				shape = self.piece.shape,
				orientation = self.ruleset:getDefaultOrientation(self.piece.shape),
			}
			self.game_state.piece_state = {
				position = self.piece.position,
				gravity = self.piece.gravity,
				lock_delay = self.piece.lock_delay,
				rotation = self.piece.rotation,
			}
		else
			self.game_state.piece = nil
			self.game_state.piece_state = nil
		end
		self.game_state.pause_count = self.pause_count
		self.game_state.pause_time = self.pause_time
		self.game_state.delays = {are = self.are, lcd = self.lcd, das = self.das}
		self.game_state.ready_frames = self.ready_frames
		local id = self.ruleset.name .. self.ruleset.hash
		if self.game_over or self.completed then
			--wipe the data at game over
			love.filesystem.remove("saves/long_endurance-"..id..".sav")
		else
			if not love.filesystem.getInfo("saves", "directory") then
				love.filesystem.createDirectory("saves")
			end
			love.filesystem.write("saves/long_endurance-"..id..".sav", binser.s(self.game_state))
		end
		saveConfig()
	end
end

function LongEndurance:getARE()
	return 6
end

function LongEndurance:getLineARE()
	return 9
end

function LongEndurance:getLineClearDelay()
	return 21
end

function LongEndurance:getDasLimit()
	return 9
end

function LongEndurance:getARR()
	return 1
end

local hugenum = 1e307
function LongEndurance:getGravity()
	return (
	{0.01, 0.02, 0.05, 0.1,
	 0.2, 0.5, 1, 2,
	 5, 10, 20})[self.game_state.level+1] or hugenum
end

function LongEndurance:getLockDelay()
	return (
	{120, 120, 120, 120,
	 120, 120, 100, 90,
	 75, 60, 50, 42,
	 36, 30, 27, 24, 22,
	 19, 17, 16, 15,
	 13, 12, 10, 9, 8})[self.game_state.level+1]
end

function LongEndurance:getBackground()
	return math.max(0, self.game_state.level-6)
end

function LongEndurance:getHighscoreData()
	return {
		level = self.game_state.level;
		lines = self.lines;
		score = self.game_state.score;
		frames = self.frames;
	}
end

function LongEndurance:drawScoringInfo()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font_3x5_2)

	love.graphics.printf("NEXT", 64, 40, 40, "left")
	
	love.graphics.printf("LEVEL", 240, 120, 40, "left")
	love.graphics.printf("LINES", 240, 200, 40, "left")
	love.graphics.printf("SCORE", 240, 320, 40, "left")
	

	love.graphics.setFont(font_3x5_3)
	love.graphics.printf(self.game_state.level .. "/26", 240, 140, 120, "left")
	love.graphics.printf(self.lines .. "/" .. self.level_milestones[self.game_state.level+1], 240, 220, 160, "left")
	love.graphics.printf(self.game_state.score, 240, 340, 160, "left")

	love.graphics.setFont(font_8x11)
	love.graphics.printf(self.formatTime(self.frames), 64, 420, 160, "center")

	love.graphics.setFont(font_3x5)
	love.graphics.print(
		self.das.direction .. " " ..
		self.das.frames .. " " ..
		strTrueValues(self.prev_inputs) ..
		self.drop_bonus
	)

	love.graphics.setFont(font_3x5_2)
	for key, txt in pairs(self.falling_text_table) do
		love.graphics.printf(txt.text, txt.x, txt.y, 200, "center", txt.r, txt.scale, txt.scale, 100, font_3x5_2:getHeight()/2)
	end
end

return LongEndurance