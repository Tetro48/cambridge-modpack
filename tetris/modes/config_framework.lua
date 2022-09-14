local default_gamemode = require 'tetris.modes.gamemode'

--Any modes extending the config must put self.super:functionName()
local framework = default_gamemode:extend()
framework.name = "Config Framework"
framework.tagline = "The framework to set up built-in mode config."
framework.hash = "cfgfw"

local local_replay_vars = {}
local loaded_vars = false

function framework:new(secrets)
	-- Notice: Bool vars will ignore limits!
	-- How to set up one configurable section:
	-- {
	--    {"shown_name", "variable_name", "description", low_limit: int, high_limit: int, show_arrows: bool},
	-- }
	-- self.variable_name = default

	loaded_vars = false
	self.save_replay = false
	self.super:new(secrets)
	self.menu_DAS = 12
	self.menu_DAS_ticks = { ["up"] = 0, ["down"] = 0, ["left"] = 0, ["right"] = 0 }
	--This must have index of 0 pointing to some value, otherwise won't work and probably crash.
	self.menu_ARR_table = { [0] = 8, 6, 5, 4, 3, 2, 2, 2, 1 }
	self.config_settings = {
		{ default = 1, "example 1", "example1" },
		{ default = false, "example 2", "examplebool" },
		{ default = 1, "example 3", "example3", "Some description test" },
		{ default = 1, "example 4", "example3", "Some variable collision test" },
		{ default = 1, "example 5", "example5", "Some low limit of -5 test", -5 },
		{ default = 1, "example 6", "example6", "Some high limit of 300 test", nil, 300 },
		{ default = 1, "example 7", "example7", "Some limit range from -33 to 36 test", -33, 36 },
		{ default = 1, "example 8", "example8", "Arrowless", nil, nil, false },
	}
	self.selection = 1
	self.ready_frames = 1
	self.in_menu = true
	self.replay_frames = 1
	self.wipe_menu_config = secrets.hold or false
end

function framework:onStart()
	
end

function framework:putMissingVars()
	for index, config_obj in ipairs(self.config_settings) do
		if self[config_obj[2]] == nil then
			self[config_obj[2]] = 0
		end
	end
end

function framework:drawMenuSection(text, value, selection, shown_selection, show_arrows)
	if show_arrows == nil then show_arrows = true end
	if value == nil then return end
	love.graphics.setFont(font_3x5_2)
	if self.selection == selection then
		love.graphics.setColor(1, 1, 0, 1)
	end
	love.graphics.printf(text, 65, 85 + 15 * shown_selection, 160, "left")

	love.graphics.setColor(1, 1, 1, 1)
	if show_arrows then
		love.graphics.polygon("fill", 225, 89 + 15 * shown_selection, 225, 99 + 15 * shown_selection, 230, 94 + 15 * shown_selection)
		love.graphics.polygon("fill", 63, 89 + 15 * shown_selection, 63, 99 + 15 * shown_selection, 58, 94 + 15 * shown_selection)
	end
	love.graphics.printf(value, 60, 85 + 15 * shown_selection, 160, "right")
end

function framework:drawMenuDescription(text, selection)
	if (self.selection == selection or selection == nil) then
		love.graphics.setFont(font_3x5_2)
		love.graphics.printf(text, 5, 420, 580, "left")
	end

end

function framework:boolToString(bool)
	if bool then return "ON" else return "OFF" end
end

function framework:loadVariables()
	if loaded_vars then return end
	loaded_vars = true
	for key, value in pairs(self.config_settings) do
		--hard to read and understand
		if config.mode_config then
			if config.mode_config[self.hash] then
				if config.mode_config[self.hash][value[2]] ~= nil then
					self[value[2]] = config.mode_config[self.hash][value[2]]
				end
			end
		end
		if self[value[2]] == nil then
			self[value[2]] = value.default or 1
		end
		if self.wipe_menu_config then
			if value.default ~= nil then
				self[value[2]] = value.default
			else
				self[value[2]] = self[value[2]] or 1
			end
		end
	end
end

function framework:advanceOneFrame(inputs)
	--This code snippet must be placed at the head of Mode:advanceOneFrame(inputs) if you're extending from this framework or else it won't work correctly.
	--[[
	if self.super.advanceOneFrame(self, inputs) == false then
		return false
	end
	]]

	if self.in_menu then
		local maxSelection = #self.config_settings
		self:loadVariables()
		if scene.replay ~= nil and self.selection < maxSelection then
			if self.replay_frames == 1 then
				for key, value in pairs(scene.replay.inputs[1].variables) do
					self[key] = value
				end
			end
			self.replay_frames = self.replay_frames + 1
			if self.replay_frames % 15 == 14 then
				inputs["down"] = true
			else
				inputs["down"] = false
			end
		end
		if self.replay_frames == #self.config_settings * 15 + 60 then
			self.in_menu = false
			self.ready_frames = 100
			self:onStart()
		end
		if self:menuDASInput(inputs["up"], "up") then
			if self.selection < 2 then
				self.selection = maxSelection
			else
				self.selection = self.selection - 1
			end
		elseif self:menuDASInput(inputs["down"], "down") then
			if self.selection > maxSelection - 1 then
				self.selection = 1
			else
				self.selection = self.selection + 1
			end
		end
		local config_obj = self.config_settings[self.selection]
		local var = self[config_obj[2]]
		if var == true or var == false then
			if self:menuDASInput(inputs["left"], "left") or self:menuDASInput(inputs["right"], "right") then
				self[config_obj[2]] = not self[config_obj[2]]
			end
		else
			self[config_obj[2]] = self:menuIncrement(inputs, var, 1, config_obj[4], config_obj[5])
		end
		if ((inputs["rotate_left"] and not self.prev_inputs["rotate_left"]) or (inputs["rotate_left2"] and not self.prev_inputs["rotate_left2"])
			or (inputs["rotate_right"] and not self.prev_inputs["rotate_right"]) or (inputs["rotate_right2"] and not self.prev_inputs["rotate_right"])
			or (inputs["rotate_180"] and not self.prev_inputs["rotate_180"])) then
			self.in_menu = false
			self.ready_frames = 100
			self.save_replay = config.gamesettings.save_replay == 1 and not scene.replay
			if self.save_replay then
				local new_inputs = {}
				new_inputs["inputs"] = {}
				for key, value in pairs(self.config_settings) do
					local_replay_vars[value[2]] = self[value[2]]
				end
				new_inputs["variables"] = local_replay_vars
				new_inputs["frames"] = #self.config_settings * 15 + 60
				self.replay_inputs[#self.replay_inputs + 1] = new_inputs
			end
			self:onStart()
			config.mode_config = config.mode_config or {}
			config.mode_config[self.hash] = local_replay_vars
			saveConfig()
		end
		return false
	elseif self.ready_frames == 0 then
		self.frames = self.frames + 1
	end
end

local menuDAS = 12
local menuDASf = { ["up"] = 0, ["down"] = 0, ["left"] = 0, ["right"] = 0 }
function framework:menuDASInput(input, inputString)
	local result = false
	if (input) then self.menu_DAS_ticks[inputString] = self.menu_DAS_ticks[inputString] + 1
	else
		self.menu_DAS_ticks[inputString] = 0
	end
	if (self.prev_inputs[inputString] == false or
		(self.menu_DAS_ticks[inputString] >= self.menu_DAS and self.menu_DAS_ticks[inputString] % self:getMenuARR(self.menu_DAS_ticks[inputString]) == 0) or
		self.menu_DAS_ticks[inputString] == 1) and input then
		result = true
		playSE("cursor")
	end
	return result
end

function framework:menuIncrement(inputs, current_value, increase_by, low_limit, high_limit)
	local scaled_increase_by
	if self:menuDASInput(inputs["right"], "right") then
		scaled_increase_by = increase_by * math.ceil(self.menu_DAS_ticks["right"] / 90)
		current_value = current_value + scaled_increase_by
	elseif self:menuDASInput(inputs["left"], "left") then
		scaled_increase_by = increase_by * math.ceil(self.menu_DAS_ticks["left"] / 90)
		current_value = current_value - scaled_increase_by
	end
	if low_limit == nil then low_limit = -math.huge end
	if high_limit == nil then high_limit = math.huge end
	if current_value > high_limit then
		return high_limit
	end
	if current_value < low_limit then return low_limit end
	return current_value
end

function framework:getMenuARR(number)
	if number < 60 then
		if (number / 30) > #self.menu_ARR_table then
			return #self.menu_ARR_table
		else
			return self.menu_ARR_table[math.floor(number / 30)]
		end
	end
	return math.ceil(25 / math.sqrt(number))
end

function framework:drawCustom()
	if not self.in_menu then return end
	scene.paused = false
	for i, config_obj in ipairs(self.config_settings) do
		i = i - 1
		if math.floor(i / 15) == math.floor((self.selection - 1) / 15) then
			local var = self[config_obj[2]]
			if var == true or var == false then
				self:drawMenuSection(config_obj[1], self:boolToString(var), i + 1, i % 15 + 1, config_obj[6])
			else
				self:drawMenuSection(config_obj[1], var, i + 1, i % 15 + 1, config_obj[6])
			end
		end
	end
	if #self.config_settings > 15 then
		love.graphics.printf(string.format("Page %d/%d", math.floor((self.selection - 1) / 15) + 1, math.floor((#self.config_settings - 1) / 15) + 1), 60, 85, 160, "right")
	end
	if self.config_settings[self.selection][3] ~= nil then
		self:drawMenuDescription(self.config_settings[self.selection][3])
		love.graphics.printf("Description", 5, 400, 160, "left")
	end
	love.graphics.setFont(font_3x5_2)
	love.graphics.printf("Press rotation to start", 64, 360, 160, "center")
end

function framework:draw(paused)
	self:transformScreen()
	self:drawBackground()
	self:drawFrame()
	self:drawGrid()
	self:drawPiece()
	if self:canDrawLCA() then
		self:drawLineClearAnimation()
	end
	if not self.in_menu then
		self:drawNextQueue(self.ruleset)
		self:drawScoringInfo()
		self:drawReadyGo()
	end
	self:drawCustom()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font_3x5_2)
	if config.visualsettings.display_gamemode == 1 or config.gamesettings.display_gamemode == 1 then
		love.graphics.printf(
			self.name .. " - " .. self.ruleset.name,
			0, 460, 640, "left"
		)
	end

	if paused and not self.in_menu then
		self:drawIfPaused()
	end

	if self.completed then
		self:onGameComplete()
	elseif self.game_over then
		self:onGameOver()
	end
end

return framework
