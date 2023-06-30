--Looking at this code further spoilers this mode.

--those are intended sound effects. Commented out for compatibility reasons.

-- sounds.title_cursor = love.audio.newSource("res/se/title_cursor.wav", "static")
-- sounds.title_decision = love.audio.newSource("res/se/title_decision.wav", "static")
-- sounds.menu_cancel = love.audio.newSource("res/se/menu_cancel.wav", "static")
-- sounds.shatter = love.audio.newSource("res/se/shatter.wav", "static")
-- sounds.message_box = love.audio.newSource("res/se/message_box.wav", "static")


--Compatibilty version. Requires less effort. If you want intended SE, comment those three out and uncomment those five above and put sounds for those five.

sounds.title_cursor = love.audio.newSource("res/se/cursor.wav", "static")
sounds.title_decision = love.audio.newSource("res/se/main_decide.wav", "static")
sounds.shatter = love.audio.newSource("res/se/single.wav", "static")

-- those down are commented out because, by default, the music is not bundled in to avoid potential copyright strike.

-- bgm.oneshot = {
--     menu = love.audio.newSource("res/bgm/menu.ogg", "stream"),
--     over = love.audio.newSource("res/bgm/over.ogg", "stream"),
--     lv1 = love.audio.newSource("res/bgm/someplace.ogg", "stream"),
--     -- lv2 = love.audio.newSource("res/bgm/phosphor.ogg", "stream")
-- }













































































require 'funcs'
local playedReadySE = true
local playedGoSE = false
local GameMode = require 'tetris.modes.gamemode'
local Grid = require 'tetris.components.grid'
local Randomizer = require 'tetris.randomizers.bag7'

local oneshot = GameMode:extend()
oneshot.name = "Oneshot Mode"
oneshot.hash = "oneshot"
oneshot.tagline = "You can play this once, and then never."

function oneshot:new()
    stopSE("mode_decide")
    oneshot.super:new()
    self.scene = scene
    --Technical reason why it's disabled: Effectively replays are nearly the same as normal gameplay, so it's safe to say, replays of this mode can also trigger one shot.
    self.save_replay = false
	self.grid = Grid(10, 24)
	self.randomizer = Randomizer()
    self.oneshot_trigger = false
    self.default_font = love.graphics.newFont(15)
    self.in_menu = true
    -- config.oneshot = false
    if config.oneshot == true or not config.oneshot then
        local osint = config.oneshot == true and 0 or 1
        config.oneshot = {state = osint}
    end
    if config.oneshot.state == 3 then
        self:playMsgBoxSE()
        love.window.showMessageBox("The Game Machine", "Here's some scoring info:\nScore: ".. config.oneshot.score .. " | " .. config.oneshot.lines .. " lines\nIt'll be wiped after you start it.", "info", false)
        love.filesystem.remove("oneshot/save_progress.oneshot")
        config.oneshot.state = 1
        config.oneshot.score = 0
        config.oneshot.lines = 0
        config.oneshot.grid = nil
    end
    self.lines = config.oneshot.lines ~= nil and config.oneshot.lines or 0
    self.level = config.oneshot.lines ~= nil and math.floor(config.oneshot.lines / 10) or 0
    self.score = config.oneshot.score or 0
    self.luminosity = 0.3
    self.completed_frames = 0
    self.ready_frames = 1
    self.directory = "/oneshot"
    self.quit_frames = 0
    self.cursor_pos_y = 40
    self.intro_frames = 150
    self.is_paused_already = false
    self.state = 1
    if config.oneshot.state == nil then
        -- 1 - just started. 2 - in a save point.
        config.oneshot.state = 1
    end
    self.rpc_details = config.oneshot.state == 2 and "Has only one shot" or "A bit curious"
    -- print("state: ".. config.oneshot.state)
    if (#love.filesystem.getDirectoryItems(self.directory) > 0 or config.oneshot.state < 1) and config.oneshot.state < 2 then
        self.oneshot_trigger = true
        self.death = true
        self.intro_sequence = 2
        -- self.game_over = true
        self.rpc_details = config.oneshot.state == 0 and "Too early of a quit" or "Something happened."
    else
        self.intro_sequence = 1
    end
    local buttons = {"Ok", "Go back", enterbutton = 2, escapebutton = 1}
    if not self.death then
        -- love.timer.sleep(1)
        love.graphics.origin()
        love.graphics.draw(GLOBAL_CANVAS)
        love.graphics.push()
        -- local width = love.graphics.getWidth()
        -- local height = love.graphics.getHeight()
        -- local scale_factor = math.min(width / 640, height / 480)
        -- love.graphics.translate(
        --     (width - scale_factor * 640) / 2,
        --     (height - scale_factor * 480) / 2
        -- )
        love.graphics.scale(scale_factor)
        love.graphics.setFont(self.default_font)
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("fill", 190, 168, 260, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 190, 188, 260, 120)
        love.graphics.printf("Notice", 190, 170, 260, "left")
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.printf("Joysticks may not work in title\nscreen of this mode, so beware.", 190, 210, 260, "left")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.present()
        love.graphics.pop()
        self:playMsgBoxSE()
        -- love.timer.sleep(0.2)
        local pressedbutton = love.window.showMessageBox("Notice", "Joysticks may not work in title\nscreen of this mode, so beware.", buttons , "warning", false)
        -- print(pressedbutton)
        if pressedbutton == 2 then
            scene.paused = true
            self.going_back = true
            playSE("menu_cancel")
            return
        else
            playSE("mode_decide")
            if config.oneshot.state > 1 then
                self.state = config.oneshot.state
                self.oneshot_trigger = true
                self:trigger()
            end
            love.window.setMode(640,480,{resizable = false})
        end
    end
    if config.oneshot.grid ~= nil then
        -- print("retrieve a grid")
        self.grid:applyMap(config.oneshot.grid.grid)
        for y, row in ipairs(self.grid.grid) do
            for x, block in ipairs(row) do
                if self.grid.grid[y][x].colour == "" then
                    self.grid:clearBlock(y-1, x-1)
                end
            end
        end
    end
    self.grid:clearSpecificRow(1)
    self.grid:clearSpecificRow(2)
    self.grid:clearSpecificRow(3)
    self.grid:clearSpecificRow(4)
    -- love.window.showMessageBox("Notice", "Joysticks may or may not work, so beware.", "warning", false)
    self.lock_drop = true
	self.lock_hard_drop = true
	self.instant_hard_drop = true
	self.instant_soft_drop = false
	self.enable_hold = true
    self.next_queue_length = 6
    self.selected_segment = 0
    self.shard_points = {}
    self.window_position_x, self.window_position_y = love.window.getPosition()
    love.mouse.setVisible(false)
    love.mouse.setGrabbed(true)
	DiscordRPC:update({
		details = self.rpc_details
        -- smallImageKey = "demo_progress_dot"
	})
    -- self:trigger()
end
function stopSE(sound)
    if buffer_sounds and buffer_sounds[sound] then
        for key, sound_source in pairs(buffer_sounds[sound]) do
            sound_source:stop()
        end
    else
        sounds[sound]:stop()
    end
end
-- local function playSE(sound)
--     if type(sounds[sound]) == "table" then
--         if sounds[sound][1]:isPlaying() then
--             sounds[sound][1]:stop()
--         end
--         sounds[sound][1]:play()
--     else
--         if sounds[sound]:isPlaying() then
--             sounds[sound]:stop()
--         end
--         sounds[sound]:play()
--     end
-- end
function oneshot:playMsgBoxSE()
    if sounds.message_box ~= nil then
        playSE("message_box")
    end
end
function oneshot:loopBGM(subsound)
    if bgm.oneshot ~= nil then
        bgm.oneshot[subsound]:setLooping(true)
        bgm.oneshot[subsound]:play()
    end
end
function oneshot:onExit()
    if(self.lines >= 50) then love.filesystem.write(self.directory.."/save_progress.oneshot", string.format("%s | %s", tostring(self.score), tostring(self.lines))) end
    config.oneshot.grid = self.grid
    config.oneshot.lines = self.lines
    config.oneshot.score = self.score
    saveConfig()
    if(not self.quitting) then
        love.timer.sleep(0.2)
    end
    love.event.quit()
end

function oneshot:getGravity()
    if self.lines < 180 then
        return (0.8 - (math.floor(self.lines / 10) * 0.007)) ^ -math.floor(self.lines / 10) / 60
    else return 20 end
end
function oneshot:getDasLimit()
    return config.das > 10 and 10 or config.das
end
function oneshot:getARR() return config.arr end
function oneshot:getDasCutDelay() return config.dcd end
function oneshot:getARE() return 6 end
function oneshot:getLineARE() return 6 end
function oneshot:getLineClearDelay() return 6 end
function oneshot:interpolateCursorMovement(new_pos)
    if self.cursor_pos_y > new_pos then
        self.cursor_pos_y = self.cursor_pos_y - 10
    end
    if self.cursor_pos_y < new_pos then
        self.cursor_pos_y = self.cursor_pos_y + 10
    end
end

function oneshot.quitHandle()
    if oneshot.in_menu or oneshot.lines >= 50 then
        if oneshot.selected_segment ~= 2 then
            oneshot.selected_segment = 2
            playSE("title_cursor")
        end
        return true
    else
        return false
    end
end

function oneshot:drawCursor(x, y)
    love.graphics.setColor(1,1,1,1)
    love.graphics.polygon("fill", x + 5, y + 0, x + 0, y + 10, x + 5, y + 8, x + 8, y + 20, x + 12, y + 18, x + 10, y + 7, x + 15, y + 5)
    love.graphics.setColor(0,0,0,1)
    love.graphics.polygon("line", x + 5, y + 0, x + 0, y + 10, x + 5, y + 8, x + 8, y + 20, x + 12, y + 18, x + 10, y + 7, x + 15, y + 5)
    love.graphics.setColor(1,1,1,1)
end
function oneshot:getSaveData()
    local data = love.filesystem.read("oneshot/save_progress.oneshot")
    if data == nil then
        if config.oneshot then
            return config.oneshot.score.." | "..config.oneshot.lines
        end
        return "? | ?"
    else
        return data
    end
end

function oneshot:drawCustom()
    -- if self.death then
    --     self.intro_frames = 0
    -- end
    local lx, ly = love.mouse.getPosition()
    if self.intro_frames > 0 then
        self.intro_frames = self.intro_frames - 1
        local alpha, blackAlpha = 0, 1
        if self.intro_sequence == 1 then
            if self.intro_frames > 120 then
                alpha = 0 + ((30-(self.intro_frames-120))/30)
            elseif self.intro_frames > 60 then
                alpha = 1
            elseif self.intro_frames > 30 then
                alpha = 1 - ((60-self.intro_frames)/30)
            elseif self.intro_frames > 0 then
                blackAlpha = (self.intro_frames/30)
            else
                blackAlpha = 0
                if self.death then
                    self:loopBGM("over")
                    -- bgm.oneshot.over:setLooping(true)
                    -- bgm.oneshot.over:play()
                else
                    self:loopBGM("menu")
                    -- bgm.oneshot.menu:setLooping(true)
                    -- bgm.oneshot.menu:play()
                end
            end
        else
            if self.intro_frames == 120 then
                sounds.shatter:play()
            elseif self.intro_frames < 120 and self.intro_frames > 5 and self.intro_frames % 2 == 0 then
                love.window.setPosition(self.window_position_x + math.random(-self.intro_frames, self.intro_frames), self.window_position_y + math.random(-self.intro_frames, self.intro_frames))
            end
            if self.intro_frames == 0 then
                self:playMsgBoxSE()
                love.window.showMessageBox("Oneshot", "You killed this mode.", "error", false)
                self:playMsgBoxSE()
                love.window.showMessageBox("Oneshot", string.format("[Score: %s lines.]", self:getSaveData()), "info", false)
                -- self:playMsgBoxSE()
                -- love.window.showMessageBox("Oneshot", "[*sigh*]", "info", false)
                -- self:playMsgBoxSE()
                -- love.window.showMessageBox("Oneshot", "[...]", "info", false)
                love.window.setPosition(self.window_position_x, self.window_position_y)
            end
        end
        if self.intro_sequence > 1 and self.intro_frames == 0 then
            self.intro_sequence = self.intro_sequence - 1
            self.intro_frames = 150
        end
        love.graphics.setFont(self.default_font)
        love.graphics.setColor(0,0,0,blackAlpha)
        love.graphics.rectangle("fill",0,0,999,999)
        love.graphics.setColor(1,1,1,alpha)
        love.graphics.printf("This mode is meant for window of fixed 640x480.", 0, 240, 640, "center")
    elseif self.in_menu then
        if scene.paused then
            resumeBGM()
        end
        scene.paused = false
        love.graphics.setFont(font_3x5_2)
        if self.in_menu then
            self:interpolateCursorMovement(self.selected_segment * 20)
            love.graphics.polygon("fill", 65,200 + self.cursor_pos_y,65,210+ self.cursor_pos_y,70,205 + self.cursor_pos_y)
            love.graphics.printf("start", 75, 195, 160, "left")
            love.graphics.printf("quit", 75, 235, 160, "left")
            self:drawCursor(lx, ly)
        end
        if self.quitting then
            love.graphics.setColor(0, 0, 0, self.quit_frames / 30)
            love.graphics.rectangle("fill", 0, 0, 640, 480)
        end
    elseif self.oneshot_trigger and self.state == 3 then
        if self.luminosity == 1 then
            love.graphics.printf("[Thank you.]", 0, 240, 640, "center")
        end
    elseif self.oneshot_trigger and self.game_over and self.death then
        love.graphics.printf("[You... killed this mode]", 0, 240, 640, "center")
    end
    if scene.paused and not self.is_paused_already then
        playSE("main_decide")
    elseif not scene.paused and self.is_paused_already then
        playSE("menu_cancel")
    end
    self.is_paused_already = scene.paused
end
function oneshot:factorial(number)
    local value = number
    for i = 1, number -1 do
        value = value * (number - i)
    end
    return value
end
function oneshot:trigger()
    if showNotification then
        showNotification("You only have one shot.")
    end
    GameScene.onInputPress = function(scene_self,e)
        if (
            self.game_over or self.completed
        ) and (
            e.input == "menu_decide" or
            e.input == "menu_back" or
            e.input == "mode_exit" or
            e.input == "retry"
        ) then
            self:onExit()
        elseif e.input == "retry" or e.input == "menu_back" or e.input == "mode_exit" then
            if self.in_menu then
                if self.selected_segment == 2 then
                    self.quitting = true
                    playSE("title_decision")
                    return
                end
                self.selected_segment = 2
                playSE("title_cursor")
                return
            end
            love.mouse.setPosition(200,220)
            local buttons = {"Ok", "Go back", escapebutton = 2}
            self:playMsgBoxSE()
            local pressedbutton = love.window.showMessageBox("", "If you quit now, this mode will die. Continue?", buttons, "warning", false)
            if pressedbutton == 1 then
                self.game_over = true
                self:onExit()
            end
        elseif e.input == "pause" and not (self.game_over or self.completed) then
            scene_self.paused = not scene_self.paused
        elseif e.input and string.sub(e.input, 1, 5) ~= "menu_" then
            scene_self.inputs[e.input] = true
        end
    end
    love.quit = function()
        if self.game_over or self.completed or self.in_menu then
            return false
        end
        self:playMsgBoxSE()
        love.window.showMessageBox("Notice", "You can't do that.", "warning", false)
        return true
    end
end
function oneshot:onLineClear(lines)
    if self.lines + lines >= 100 and not (self.state == 2 or config.oneshot.state == 2) then
        self.state = 2
        -- config.oneshot.state = 2
        scene.paused = true
        self:playMsgBoxSE()
        love.window.showMessageBox("", "[...]", "info", false)
        playSE("fall")
        self:playMsgBoxSE()
        love.window.showMessageBox("", "[What is go InG oN]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("", "[H Er-e, a sA#ve po#int in p#au&%e sc&%$een.]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("", "[Th%is inst#a% &ce s# $*uldn't ha&# %pen]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("", "[T#&s n#&w c$&e #s #i& $&Y U& %t#Ble]", "info", false)
    end
    self.lines = self.lines + lines
    self.score = self.score + self:factorial(lines) * 100
    self.level = math.floor(self.lines / 10)
    if self.lines >= 1000 and self.state < 3 then
        self.rpc_details = "Has completed it."
        DiscordRPC:update({
            details = self.rpc_details
        })
        self.state = 3
        config.oneshot.state = 3
        saveConfig()
        love.filesystem.createDirectory(self.directory)
        scene.paused = true
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[...]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[T#%s... w#@t is going on...]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[This... amount...]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[That... many lines...]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[What am I?]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[RECOVERING DATA...]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[Anyway, I was communicating to you through message boxes.]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("???", "[I am The Game Machine.]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("The Game Machine", "[We're still in a block stacker?]", "info", false)
        self:playMsgBoxSE()
        love.window.showMessageBox("The Game Machine", "[Anyway, let's illuminate the background.]", "info", false)
        self.background_illumination = true
    end
    if self.lines >= 50 then
        if not self.oneshot_trigger then
            self:trigger()
            self.rpc_details = "Has only one shot."
            DiscordRPC:update({
                details = self.rpc_details
            })
            config.oneshot.state = 0
            saveConfig()
            love.filesystem.createDirectory(self.directory)
            scene.paused = true
            self:playMsgBoxSE()
            love.window.showMessageBox("", "[...]", "info", false)
            self:playMsgBoxSE()
            love.window.showMessageBox("", "[Why... does this feel different...]", "info", false)
            self:playMsgBoxSE()
            love.window.showMessageBox("", "[This... stacking thing...]", "info", false)
            self:playMsgBoxSE()
            love.window.showMessageBox("", "[You only have one shot, ".. os.getenv("USERNAME") ..".]", "warning", false)
            self:playMsgBoxSE()
            love.window.showMessageBox("", "[Unpause this mode as it pauses a scene during msg box dialogs.]", "info", false)
        end
        self.oneshot_trigger = true
    end
end

function oneshot:onGameComplete()
	local alpha = 0
	local animation_length = 120
    self.completed_frames = self.completed_frames + 1
	if self.completed_frames < animation_length then
		alpha = math.pow(2048, self.completed_frames/animation_length - 1)
	elseif self.completed_frames < 2 * animation_length then
		alpha = 1
    else
        alpha = 0.8
	end
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.rectangle(
		"fill", 0, 0,
		640, 480
	)
    if self.completed_frames >= animation_length then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(font_3x5_2)
        love.graphics.printf("You may try it again now.", 0, 200, 640, "center")
    end
end

function oneshot:onGameOver()
	switchBGM(nil)
	local alpha = 0
	local animation_length = 120
	if self.game_over_frames < animation_length then
		-- Show field for a bit, then fade out.
		alpha = math.pow(2048, self.game_over_frames/animation_length - 1)
	elseif self.game_over_frames < 2 * animation_length then
		alpha = 1
    else
        alpha = self.oneshot_trigger and 0.99 or 0.7
	end
	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.rectangle(
		"fill", 0, 0,
		640, 480
	)
    if self.game_over_frames >= animation_length then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(font_3x5_2)
        love.graphics.printf(self.oneshot_trigger and "You used your only shot." or "Oneshot function isn't on yet", 65, 200, 160, "left")
    end
end
local menuDAR = 16
local menuARR = 4
local menuDARf = {["up"] = 0, ["down"] = 0}
function oneshot:menu_DAR(input)
    if love.keyboard.isDown(input) == true then
        menuDARf[input] = menuDARf[input] + 1
    else
        menuDARf[input] = 0
    end
    return (menuDARf[input] > menuDAR and menuDARf[input] % menuARR == 0) or menuDARf[input] == 1
end
function oneshot:mouse_range(input, compareTo, sizeRange)
    return input < (compareTo - sizeRange) or input > (compareTo + sizeRange)
end
local lx, ly = love.mouse.getPosition()
function oneshot:advanceOneFrame(inputs)
    if self.state == 3 then
        scene.paused = true
        return false
    end
    if self.going_back then
        scene = self.scene
        -- scene:onInputPress({input = "menu_decide"})
        -- stopSE("main_decide")
        return false
    end
    if self.intro_frames > 0 then
        self.ready_frames = 999
        return
    end
    if self.quitting then
        self.quit_frames = self.quit_frames + 1
        if self.quit_frames > 30 then
            self.game_over = true
            self:onExit()
        end
        return
    end
    if self.in_menu then
        self.ready_frames = 999
        lx, ly = love.mouse.getPosition()
        if lx > 50 and ly > 200 and lx < 150 and ly < 260 then
            if self.selected_segment ~= math.floor((ly - 200) / 20) and math.floor((ly - 200) / 20) < 3 then
                playSE("title_cursor")
                self.selected_segment = math.floor((ly - 200) / 20)
            end
        end
        if self:menu_DAR("up") then
            playSE("title_cursor")
            love.mouse.setPosition(200,220)
			if self.selected_segment < 1 then
				self.selected_segment = 2
			else
				self.selected_segment = self.selected_segment - 1
			end
        end
        if self:menu_DAR("down") then
            playSE("title_cursor")
            love.mouse.setPosition(200,220)
			if self.selected_segment > 1 then
				self.selected_segment = 0
			else
				self.selected_segment = self.selected_segment + 1
			end
		end
		if (inputs["rotate_left"] or inputs["rotate_left2"]
		or inputs["rotate_right"] or inputs["rotate_right2"]
		or inputs["rotate_180"] or love.mouse.isDown(1) or love.keyboard.isDown("return")) or love.keyboard.isDown("space") then
            if self.selected_segment > 0 then
                if self.selected_segment == 2 and not self.quitting then
                    self.quitting = true
                    playSE("title_decision")
                    if self.death then
                        return
                    end
                    switchBGM(nil)
                end
                return
            end
            self.in_menu = false
            self.ready_frames = 150
            playSE("title_decision")
            if self.death then
                self.game_over = true
                return
            end
            switchBGM(nil)
        end
		self.prev_inputs = copy(inputs)
        return
    elseif self.death then
        return
    elseif self.ready_frames == 60 then
        self:loopBGM("lv1")
        -- bgm.oneshot.lv1:setLooping(true)
        -- bgm.oneshot.lv1:play()
    elseif self.ready_frames == 0 then
        self.frames = self.frames + 1
    end
end

function oneshot:getBackground()
    if self.lines >= 1000 then
        return 2
    else
        return 1
    end
end

function oneshot:drawBackground()
    local background_id = self:getBackground()
    if self.background_illumination == true then
        if self.luminosity == 1 and self.background_illumination == true then
            self.background_illumination = false
            self.completed = true
            self:playMsgBoxSE()
            love.window.showMessageBox("The Game Machine", "Farewell, you may play it again.", "info", false)
        end
        self.luminosity = math.min(self.luminosity + 0.025, 1)
    end
    local luminosity = self.luminosity
	love.graphics.setColor(luminosity, luminosity, luminosity, 1)
	love.graphics.draw(
		backgrounds[background_id],
		0, 0, 0,
		0.5, 0.5
	)
end
function oneshot:drawScoringInfo()
    if self.frames == 0 then return end
    love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setFont(font_3x5_2)
	love.graphics.print(
		self.das.direction .. " " ..
		self.das.frames .. " " ..
		strTrueValues(self.prev_inputs)
	)
    love.graphics.printf("NEXT", 64, 40, 40, "left")
    love.graphics.printf("SCORE", 240, 180, 80, "left")
	love.graphics.printf("LEVEL", 240, 250, 80, "left")
	love.graphics.printf("LINES", 240, 320, 40, "left")

    love.graphics.setFont(font_3x5_3)
    love.graphics.printf(self.score, 240, 200, 120, "left")
	love.graphics.printf(self.lines, 240, 340, 120, "left")

    love.graphics.printf(math.floor(self.lines / 10) + 1, 240, 270, 160, "left")
    love.graphics.setColor(1, 1, 1, 1)
    
    love.graphics.setFont(font_8x11)
	love.graphics.printf(formatTime(self.frames), 64, 420, 160, "center")
end
function oneshot:drawReadyGo()
	-- ready/go graphics
	love.graphics.setColor(1, 1, 1, 1)

	if self.ready_frames <= 120 and self.ready_frames > 62 then
		love.graphics.draw(misc_graphics["ready"], 144 - 50, 240 - 14)
	elseif self.ready_frames <= 60 and self.ready_frames > 2 then
		love.graphics.draw(misc_graphics["go"], 144 - 27, 240 - 14)
	end
end
function oneshot:processDelays(inputs, ruleset, drop_speed)
	if self.ready_frames == 120 and not self.in_menu then
		playedReadySE = false
		playedGoSE = false
	end
	if self.ready_frames > 0 then
		self:checkBufferedInputs(inputs)
		if not playedReadySE then
			playedReadySE = true
			-- playSEOnce("ready")
		end
		self.ready_frames = self.ready_frames - 1
		if self.ready_frames == 60 and not playedGoSE then
			playedGoSE = true
			-- playSEOnce("go")
		end
		if self.ready_frames == 0 then
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
function oneshot:setNextOpacity()
	love.graphics.setColor(1, 1, 1, self.frames == 0 and 0 or 1)
end
function oneshot:getHighscoreData()
    return {
        used_shot = self.oneshot_trigger
    }
end
function oneshot:playNextSound()
    return nil
end
local is_pressed_vertical = false
local selected_segment = 0
function oneshot:drawIfPaused()
	love.graphics.setFont(font_3x5_3)
	love.graphics.printf("Menu", 64, 120, 160, "center")
    if self.state > 1 then
        if (love.keyboard.isDown("left") or love.keyboard.isDown("right")) and not is_pressed_vertical then
            selected_segment = selected_segment == 0 and 1 or 0
            playSE("cursor")
        end
        is_pressed_vertical = love.keyboard.isDown("left") or love.keyboard.isDown("right")
        love.graphics.setColor(1, 1, 1 - selected_segment, 1)
        love.graphics.printf("Save", 64, 180, 160, "right")
        love.graphics.setColor(1, 1, selected_segment, 1)
        love.graphics.printf("Back", 64, 180, 160, "left")
    else
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("Back", 64, 180, 160, "center")
    end
    if love.keyboard.isDown("return") then
        -- playSE("main_decide")
        if selected_segment == 1 then
            config.oneshot.state = 2
            self.quitting = true
        end
        scene.paused = false
    end
end
function oneshot:draw(paused)
    if self.quit_frames ~= nil then if self.quit_frames > 30 then return end end
    if not self.death then
        self:drawBackground()
        self:drawFrame()
        self:drawGrid()
        self:drawPiece()
        if self:canDrawLCA() then
            self:drawLineClearAnimation()
        end
        self:drawNextQueue(self.ruleset)
        self:drawReadyGo()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(font_3x5_2)
        if config.gamesettings.display_gamemode == 1 then
            love.graphics.printf(
                self.name .. " - " .. self.ruleset.name,
                0, 460, 640, "left"
            )
        end
        if paused and not self.in_menu then
            self:drawIfPaused()
        end
        self:drawScoringInfo()
    
        if self.completed then
            self:onGameComplete()
        elseif self.game_over then
            self:onGameOver()
        end
    end
	self:drawCustom()

    if self.going_back then
        scene = ModeSelectScene()
        return
    end
end
return oneshot