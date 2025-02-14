local default_gamemode = require 'tetris.modes.gamemode'

--Any modes extending the config must put self.super.functionName(self, ...)
local framework = default_gamemode:extend()
framework.name = "Config Framework"
framework.tagline = "The framework to set up built-in mode config."
framework.hash = "cfgfw"
framework.tags = {"Configurable"}

local loaded_vars = false
local wipe_menu_config

---This shouldn't be read or written directly on it, only used for Lua Language Server annotations.
---@class config_template Configuration Template
---@field format string|nil|fun(value):string Value formatter
---@field setting_title string Name of a setting
---@field internal_variable_name any Internal variable to modify by key reference
---@field description string|nil
---@field increment_type "integer"|"float"|nil Default value type: Integer
---@field low_limit number|nil Sets a low boundary
---@field high_limit number|nil Sets a high boundary
---@field default number|boolean Default value.
---@field arrows boolean|nil Show arrows or not.
local config_template = {
	setting_title = "",
	internal_variable_name = "",
	description = "",
	low_limit = 0,
	high_limit = 0,
	default = 0,
	arrows = true
}


function framework:new(secrets)

	loaded_vars = false
	self.save_replay = false
	default_gamemode.new(self, secrets)
	self.menu_DAS = 12
	self.menu_DAS_ticks = { up = 0, down = 0, left = 0, right = 0 }
	self.menu_DAS_accumulant = { left = 0, right = 0 }
	--This must have index of 0 pointing to some value, otherwise won't work and probably crash.
	self.menu_ARR_table = { [0] = 8, 6, 5, 4, 3, 2, 2, 2, 1 }
	--[[
	Notice: Bool vars will ignore limits!
	Configuration Object Template:
	{
		default = default value,
		setting_title = "setting title",
		internal_variable_name = "internal variable name",
		description = "description",
		low_limit = <integer>,
		high_limit = <integer>,
		increment_type = "integer"/"float",
		arrows = <boolean>
	}
	]]
	---@type config_template[]
	self.config_settings = {
		{
			default = 1,
			setting_title = "example 1",
			internal_variable_name = "example1",
		},
		{
			default = false,
			setting_title = "example 2",
			internal_variable_name = "examplebool"
		},
		{
			default = 1,
			setting_title = "example 3",
			internal_variable_name = "example3",
			description = "Some description test"
		},
		{
			default = 1,
			setting_title = "example 4",
			internal_variable_name = "example3",
			description = "Some variable collision test"
		},
		{
			default = 1,
			setting_title = "example 5",
			internal_variable_name = "example5",
			description = "Some low limit of -5 test",
			low_limit = -5
		},
		{
			default = 1,
			setting_title = "example 6",
			internal_variable_name = "example6",
			description = "Some high limit of 300 test",
			high_limit = 300
		},
		{
			default = 1,
			setting_title = "example 7",
			internal_variable_name = "example7",
			description = "Some limit range from -33 to 36 test",
			low_limit = -33,
			high_limit = 36
		},
		{
			default = 1,
			setting_title = "example 8",
			internal_variable_name = "example8",
			description = "Arrowless",
			arrows = false
		},
		{
			default = 1,
			setting_title = "example 9",
			internal_variable_name = "example9",
			description = "format deez values",
			format = "value->%d"
		},
		{
			default = 1,
			setting_title = "example 10",
			internal_variable_name = "example10",
			description = "Shows off some formatting functionality (get it?). Example formatting: FizzBuzz.",
			low_limit = 1,
			format = function (value)
				if value % 3 == 0 and value % 5 == 0 then
				  return "FizzBuzz"
				elseif value % 3 == 0 then
				  return "Fizz"
				elseif value % 5 == 0 then
				  return "Buzz"
				else
				  return value
				end
			end,
		},
		{
			default = 1.0,
			setting_title = "example 11",
			internal_variable_name = "example11",
			increment_type = "float",
			description = "Floating point increment, yay! Hold Shift to decrease increment by 100x.",
			format = "%.2f",
		}
	}
	self.selection = 1
	self.ready_frames = 1
	self.menu_sections_per_page = 16
	self.in_menu = true
	self.replay_frames = 1
	wipe_menu_config = secrets.hold or false
end

function framework:onStart()

end

function framework:putMissingVars()
	for index, config_obj in ipairs(self.config_settings) do
		if self[config_obj.internal_variable_name] == nil then
			self[config_obj.internal_variable_name] = 0
		end
	end
end

function framework:drawMenuSection(text, value, selection, shown_selection, show_left_arrows, show_right_arrows)
	if show_left_arrows == nil then show_left_arrows = true end
	if show_right_arrows == nil then show_right_arrows = true end
	if value == nil then return end
	love.graphics.setFont(font_3x5_2)
	if self.selection == selection then
		love.graphics.setColor(1, 1, 0, 1)
	end
	love.graphics.printf(text, 65, 85 + 15 * shown_selection, 160, "left")

	love.graphics.setColor(1, 1, 1, 1)
	if show_right_arrows then
		love.graphics.polygon("fill", 225, 89 + 15 * shown_selection, 225, 99 + 15 * shown_selection, 230, 94 + 15 * shown_selection)
	end
	if show_left_arrows then
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

function framework.boolToString(bool)
	if bool then return "ON" else return "OFF" end
end

function framework:loadVariables()
	if loaded_vars then return end
	loaded_vars = true
	for key, value in pairs(self.config_settings) do
		--hard to read and understand
		value.setting_title = value.setting_title or value[1]
		value.internal_variable_name = value.internal_variable_name or value[2]
		value.description = value.description or value[3]
		value.low_limit = value.low_limit or value[4]
		value.high_limit = value.high_limit or value[5]
		if value.arrows == nil then value.arrows = value[6] end
		if value.increment_type == nil then
			value.increment_type = "integer"
		end
		if config.mode_config then
			if config.mode_config[self.hash] then
				if config.mode_config[self.hash][value.internal_variable_name] ~= nil then
					self[value.internal_variable_name] = config.mode_config[self.hash][value.internal_variable_name]
				end
			end
		end
		if type(value.default) == "boolean" and type(self[value.internal_variable_name]) ~= "boolean" then
			self[value.internal_variable_name] = value.default
		end
		if self[value.internal_variable_name] == nil or wipe_menu_config then
			self[value.internal_variable_name] = value.default ~= nil and value.default or 1
		end
	end
end

function framework:update(inputs, ruleset)
	if self.in_menu then
		local maxSelection = #self.config_settings
		self:loadVariables()
		if scene.replay ~= nil then
			if self.replay_frames == 1 then
				for key, value in pairs(scene.replay.inputs[1].variables) do
					self[key] = value
				end
			end
			self.replay_frames = self.replay_frames + 1
			if self.replay_frames % 15 == 14 and self.selection < maxSelection then
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
		end
		if self:menuDASInput(inputs["down"], "down") then
			if self.selection > maxSelection - 1 then
				self.selection = 1
			else
				self.selection = self.selection + 1
			end
		end
		local config_obj = self.config_settings[self.selection]
		local var = self[config_obj.internal_variable_name]
		if type(var) == "boolean" then
			if self:menuDASInput(inputs["left"], "left") or self:menuDASInput(inputs["right"], "right") then
				self[config_obj.internal_variable_name] = not self[config_obj.internal_variable_name]
			end
		else
			self[config_obj.internal_variable_name] = self:menuIncrement(inputs, var,
			love.keyboard.isScancodeDown("lshift", "rshift") and config_obj.increment_type == "float" and 0.01 or 1, config_obj.increment_type == "integer",
				config_obj.low_limit, config_obj.high_limit)
		end
		if ((inputs["rotate_left"] and not self.prev_inputs["rotate_left"]) or (inputs["rotate_left2"] and not self.prev_inputs["rotate_left2"])
			or (inputs["rotate_right"] and not self.prev_inputs["rotate_right"]) or (inputs["rotate_right2"] and not self.prev_inputs["rotate_right"])
			or (inputs["rotate_180"] and not self.prev_inputs["rotate_180"])) then
			self.in_menu = false
			self.ready_frames = 100
			self.save_replay = config.gamesettings.save_replay == 1 and not scene.replay
			local local_config_vars = {}
			for key, value in pairs(self.config_settings) do
				local_config_vars[value.internal_variable_name] = self[value.internal_variable_name]
			end
			if self.save_replay then
				local new_inputs = {}
				new_inputs["inputs"] = {}
				new_inputs["variables"] = local_config_vars
				new_inputs["frames"] = #self.config_settings * 15 + 60
				self.replay_inputs[1] = new_inputs
			end
			self:onStart()
			config.mode_config = config.mode_config or {}
			config.mode_config[self.hash] = local_config_vars
			saveConfig()
		end
		return
	end
	default_gamemode.update(self, inputs, ruleset)
end

-- Legacy DAS
function framework:menuDASInput(input, input_string)
	local result = false
	if (input) then
		self.menu_DAS_ticks[input_string] = self.menu_DAS_ticks[input_string] + 1
	else
		self.menu_DAS_ticks[input_string] = 0
	end
	if (self.prev_inputs[input_string] == false or
		(self.menu_DAS_ticks[input_string] >= self.menu_DAS and self.menu_DAS_ticks[input_string] % self:getMenuARR(self.menu_DAS_ticks[input_string]) == 0) or
		self.menu_DAS_ticks[input_string] == 1) and input then
		result = true
		playSE("cursor")
	end
	return result
end

function framework:configIncrementWithDAS(input, input_string, is_integer)
	if (input) then
		self.menu_DAS_ticks[input_string] = self.menu_DAS_ticks[input_string] + 1
	else
		self.menu_DAS_ticks[input_string] = 0
		self.menu_DAS_accumulant[input_string] = 0
	end
	if (self.prev_inputs[input_string] == false or
		(self.menu_DAS_ticks[input_string] >= self.menu_DAS) or
		self.menu_DAS_ticks[input_string] == 1) and input then
		if self.menu_DAS_ticks[input_string] == 1 then
			playSE("cursor")
			return 1
		end
		local increment = math.max(((self.menu_DAS_ticks[input_string] + 15 - self.menu_DAS) ^ 1.2) / 360,
		                           love.keyboard.isScancodeDown("lctrl", "rctrl") and 0 or 1/4)
		if not is_integer then
			if (self.menu_DAS_ticks[input_string] - self.menu_DAS) % 3 == 0 then
				playSE("cursor")
			end
			return increment
		else
			self.menu_DAS_accumulant[input_string] = self.menu_DAS_accumulant[input_string] + increment
			if (increment < 1/3 and self.menu_DAS_accumulant[input_string] > 1) or
			   (self.menu_DAS_ticks[input_string] - self.menu_DAS) % 3 == 0 and increment >= 1/3 then
				playSE("cursor")
			end
			if self.menu_DAS_accumulant[input_string] > 1 then
				local increment_return = math.floor(self.menu_DAS_accumulant[input_string])
				self.menu_DAS_accumulant[input_string] = self.menu_DAS_accumulant[input_string] % 1
				return increment_return
			end
		end
	end
	return 0
end

function framework:menuIncrement(inputs, current_value, increase_by, is_integer, low_limit, high_limit)
	current_value = current_value + self:configIncrementWithDAS(inputs["right"], "right", is_integer) * increase_by
	current_value = current_value - self:configIncrementWithDAS(inputs["left"], "left", is_integer) * increase_by
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

function framework:drawConfigMenu()
	if not self.in_menu then return end
	scene.paused = false
	for i, config_obj in ipairs(self.config_settings) do
		i = i - 1
		if math.floor(i / self.menu_sections_per_page) == math.floor((self.selection - 1) / self.menu_sections_per_page) then
			local var = self[config_obj.internal_variable_name]
			local show_left_arrows, show_right_arrows = not config_obj.low_limit or var > config_obj.low_limit, not config_obj.high_limit or var < config_obj.high_limit
			local out_value = var
			if type(config_obj.format) == "function" then
				out_value = config_obj.format(var)
			elseif type(config_obj.format) == "string" then
				out_value = config_obj.format:format(var)
			elseif type(var) == "boolean" then
				out_value = self.boolToString(var)
				show_left_arrows, show_right_arrows = true, true
			end
			if config_obj.arrows == false then
				show_left_arrows, show_right_arrows = false, false
			end
			self:drawMenuSection(config_obj.setting_title, out_value, i + 1, i % self.menu_sections_per_page + 1,
			show_left_arrows, show_right_arrows)
		end
	end
	if #self.config_settings > self.menu_sections_per_page then
		love.graphics.printf(
			string.format("Page %d/%d", math.floor((self.selection - 1) / self.menu_sections_per_page) + 1,
				math.floor((#self.config_settings - 1) / self.menu_sections_per_page) + 1), 60, 85, 160, "right")
	end
	if self.config_settings[self.selection].description ~= nil then
		self:drawMenuDescription(self.config_settings[self.selection].description)
		love.graphics.printf("Description", 5, 400, 160, "left")
	end
	love.graphics.setFont(font_3x5_2)
	love.graphics.printf("Try rotating to start", 64, 360, 160, "center")
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
	else
		self:drawConfigMenu()
	end
	self:drawCustom()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font_3x5_2)
	if (config.visualsettings and config.visualsettings.display_gamemode == 1) or config.gamesettings.display_gamemode == 1 then
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
