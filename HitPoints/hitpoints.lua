--[[
* MIT License
* 
* Copyright (c) 2023 tirem [github.com/tirem]
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
]]--
---------------------------------------------------------------------------
-- Credit to Atom0s, Thorny, and Heals for being a huge help on Discord! --
---------------------------------------------------------------------------

addon.name      = 'HitPoints';
addon.author    = 'Tirem';
addon.version   = '2.0';
addon.desc      = 'Displays information bars about the target and engaged enemies.';
addon.link      = 'https://github.com/tirem/hitpoints'

require('common');
require('helpers');
local imgui = require('imgui');
local settings = require('settings');
local engaged = require('engaged');
local target = require('target');
--local target = require('target');

-- Initialize our status lib and begin tracking by packet
gStatusLib = require('libs/status/status');

local user_settings = 
T{
	noBookendRounding = 4,
	lockPositions = false,
	showBookends = false;

	statusIconTheme = 'XIView';

	showTargetBar = true,
	targetBarScaleX = 1,
	targetBarScaleY = 1,
	targetBarFontOffset = 0,
	targetBarIconScale = 1,
	showEnemyId = false;
	alwaysShowHealthPercent = false,
	targetBarNumStatusPerRow = 16,

	showEnemyList = true,
	enemyListScaleX = 1,
	enemyListScaleY = 1,
	enemyListFontScale = 1,
	enemyListIconScale = 1,
	enemyListMaxEntries = 8,
	enemyListMaxIcons = 7,

	healthBarFlashEnabled = true,
};

local user_settings_container = 
T{
	userSettings = user_settings;
};

local defaultUserSettings = deep_copy_table(user_settings);
local config = settings.load(user_settings_container);
gConfig = config.userSettings;

local function ResetSettings()
	gConfig = deep_copy_table(defaultUserSettings);
	UpdateSettings();
end

function UpdateSettings()
    -- Save the current settings..
    settings.save();

	engaged.UpdateSettings(gConfig);
	target.UpdateSettings(gConfig);
end;

gShowConfig = {false};

local function DrawConfig()
    if(imgui.Begin(("HitPoints Config"):fmt(addon.version), gShowConfig, bit.bor(ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_AlwaysAutoResize))) then
        if(imgui.Button("Restore Defaults", { 130, 20 })) then
            ResetSettings();
            UpdateSettings();
        end

		-- Use tabs for this config menu
		imgui.BeginTabBar('XivParty Settings Tabs');

        if (imgui.BeginTabItem("General")) then
            if (imgui.Checkbox('Lock HUD Position', { gConfig.lockPositions })) then
                gConfig.lockPositions = not gConfig.lockPositions;
                UpdateSettings();
            end
            -- Status Icon Theme
            local status_theme_paths = gStatusLib.GetIconThemePaths();
            if (status_theme_paths == nil) then
                status_theme_paths = T{'-Default-'};
            else
                table.insert(status_theme_paths, '-Default-');
            end
            if (imgui.BeginCombo('Status Icon Theme', gConfig.statusIconTheme)) then
                for i = 1,#status_theme_paths,1 do
                    local is_selected = i == gConfig.statusIconTheme;

                    if (imgui.Selectable(status_theme_paths[i], is_selected) and status_theme_paths[i] ~= gConfig.statusIconTheme) then
                        gConfig.statusIconTheme = status_theme_paths[i];
                        gStatusLib.ClearIconCache();
                        UpdateSettings();
                    end

                    if (is_selected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end
            imgui.ShowHelp('The folder to pull status icons from. [HXUI\\assets\\status]');

            if (imgui.Checkbox('Show Health Bar Flash Effects', { gConfig.healthBarFlashEnabled })) then
                gConfig.healthBarFlashEnabled = not gConfig.healthBarFlashEnabled;
                UpdateSettings();
            end

			if (imgui.Checkbox('Show Bookends', { gConfig.showBookends })) then
				gConfig.showBookends = not gConfig.showBookends;
				UpdateSettings();
			end
			if (not gConfig.showBookends) then
				local noBookendRounding = { gConfig.noBookendRounding };
				if (imgui.SliderInt('Basic Bar Roundness', noBookendRounding, 0, 10)) then
					gConfig.noBookendRounding = noBookendRounding[1];
					UpdateSettings();
				end
				imgui.ShowHelp('For bars with no bookends, how round they should be.');
			end
			imgui.EndTabItem();
        end
        if (imgui.BeginTabItem("Target")) then
            if (imgui.Checkbox('Enabled', { gConfig.showTargetBar })) then
                gConfig.showTargetBar = not gConfig.showTargetBar;
                UpdateSettings();
            end
            if (imgui.Checkbox('Show Enemy Id', { gConfig.showEnemyId })) then
                gConfig.showEnemyId = not gConfig.showEnemyId;
                UpdateSettings();
            end
            imgui.ShowHelp('Display the internal ID of the monster next to its name.'); 
            if (imgui.Checkbox('Always Show Health Percent', { gConfig.alwaysShowHealthPercent })) then
                gConfig.alwaysShowHealthPercent = not gConfig.alwaysShowHealthPercent;
                UpdateSettings();
            end
            imgui.ShowHelp('Always display the percent of HP remanining regardless if the target is an enemy or not.'); 
            local scaleX = { gConfig.targetBarScaleX };
            if (imgui.SliderFloat('Scale X', scaleX, 0.1, 3.0, '%.1f')) then
                gConfig.targetBarScaleX = scaleX[1];
                UpdateSettings();
            end
            local scaleY = { gConfig.targetBarScaleY };
            if (imgui.SliderFloat('Scale Y', scaleY, 0.1, 3.0, '%.1f')) then
                gConfig.targetBarScaleY = scaleY[1];
                UpdateSettings();
            end
            local fontOffset = { gConfig.targetBarFontOffset };
            if (imgui.SliderInt('Font Scale', fontOffset, -5, 10)) then
                gConfig.targetBarFontOffset = fontOffset[1];
                UpdateSettings();
            end
            local iconScale = { gConfig.targetBarIconScale };
            if (imgui.SliderFloat('Icon Scale', iconScale, 0.1, 3.0, '%.1f')) then
                gConfig.targetBarIconScale = iconScale[1];
                UpdateSettings();
            end
			local numToShow = { gConfig.targetBarNumStatusPerRow };
			if (imgui.SliderInt('Icons Per Row', numToShow, 0, 32)) then
                gConfig.targetBarNumStatusPerRow = numToShow[1];
                UpdateSettings();
            end
			imgui.EndTabItem();
        end
        if (imgui.BeginTabItem("Engaged")) then
            if (imgui.Checkbox('Enabled', { gConfig.showEnemyList })) then
                gConfig.showEnemyList = not gConfig.showEnemyList;
                UpdateSettings();
            end
			local maxEnemies = { gConfig.enemyListMaxEntries };
			if (imgui.SliderInt('Max Enemies', maxEnemies, 1, 20)) then
                gConfig.enemyListMaxEntries = maxEnemies[1];
                UpdateSettings();
            end
            local scaleX = { gConfig.enemyListScaleX };
            if (imgui.SliderFloat('Scale X', scaleX, 0.1, 3.0, '%.1f')) then
                gConfig.enemyListScaleX = scaleX[1];
                UpdateSettings();
            end
            local scaleY = { gConfig.enemyListScaleY };
            if (imgui.SliderFloat('Scale Y', scaleY, 0.1, 3.0, '%.1f')) then
                gConfig.enemyListScaleY = scaleY[1];
                UpdateSettings();
            end
            local fontScale = { gConfig.enemyListFontScale };
            if (imgui.SliderFloat('Font Scale', fontScale, 0.1, 3.0, '%.1f')) then
                gConfig.enemyListFontScale = fontScale[1];
                UpdateSettings();
            end
            local iconScale = { gConfig.enemyListIconScale };
            if (imgui.SliderFloat('Icon Scale', iconScale, 0.1, 3.0, '%.1f')) then
                gConfig.enemyListIconScale = iconScale[1];
                UpdateSettings();
            end
			local numIcons = { gConfig.enemyListMaxIcons };
			if (imgui.SliderInt('Max Icons', numIcons, 0, 32)) then
                gConfig.enemyListMaxIcons = numIcons[1];
                UpdateSettings();
            end
			imgui.EndTabItem();
        end
    end
	imgui.End();
end

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        config = s;
		gConfig = config.userSettings;
		UpdateSettings();
    end
end);

ashita.events.register('load', 'load_cb', function ()
	UpdateSettings();
end);

ashita.events.register('d3d_present', 'present_cb_hitpoints', function ()
	if gShowConfig[1] and not statusHelpers.GetGameInterfaceHidden() then
		DrawConfig();
	end
end);

ashita.events.register('command', 'command_cb', function (e)

	-- Parse the command arguments
	local command_args = e.command:lower():args()
    if table.contains({'/hitpoints', '/hpoints', '/hp'}, command_args[1]) then
		-- Toggle the config menu
		gShowConfig[1] = not gShowConfig[1];
		e.blocked = true;
	end

end);