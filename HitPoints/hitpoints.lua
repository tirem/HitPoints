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

addon.name      = 'targetinfo';
addon.author    = 'Tirem';
addon.version   = '1.0';
addon.desc      = 'Displays information bars about the target.';
addon.link      = 'https://github.com/tirem/targetinfo'

require('common');
imgui = require('imgui');
settings = require('settings');
helpers = require('helpers');
engaged = require('engaged');
target = require('target');
debuffs = require('debuffs');

local user_settings = 
T{
	patchNotesVer = -1,

	noBookendRounding = 4,
	lockPositions = false,

	showTargetBar = true,
	showEnemyList = true,

	statusIconTheme = 'XIView';

	maxEnemyListEntries = 8,

	targetBarScaleX = 1,
	targetBarScaleY = 1,
	targetBarFontOffset = 0,
	targetBarIconScale = 1,
	showTargetBarBookends = true,
	showEnemyId = false;
	alwaysShowHealthPercent = false,

	enemyListScaleX = 1,
	enemyListScaleY = 1,
	enemyListFontScale = 1,
	enemyListIconScale = 1,
	showEnemyListBookends = true,

	healthBarFlashEnabled = true,
};

local user_settings_container = 
T{
	userSettings = user_settings;
};

local default_settings =
T{
	-- settings for the targetbar
	targetBarSettings =
	T{
		-- Damage interpolation
		hitInterpolationDecayPercentPerSecond = 150,
		hitDelayDuration = 0.5,
		hitFlashDuration = 0.4,

		-- Everything else
		barWidth = 500,
		barHeight = 18,
		totBarHeight = 14,
		totBarOffset = -1,
		textScale = 1.2,
		cornerOffset = 5,
		nameXOffset = 12,
		nameYOffset = 9,
		iconSize = 22,
		arrowSize = 30,
		maxIconColumns = 12,
		topTextYOffset = 0,
		topTextXOffset = 5,
		bottomTextYOffset = -3,
		bottomTextXOffset = 15,
		name_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 13,
			color = 0xFFFFFFFF,
			bold = true,
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = false;
		};
		totName_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 12,
			color = 0xFFFFFFFF,
			bold = true,
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = false;
		};
		distance_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
			color = 0xFFFFFFFF,
			bold = true,
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
		percent_font_settings = 
		T{
			visible = true,
			locked = true,
			font_family = 'Consolas',
			font_height = 11,
			color = 0xFFFFFFFF,
			bold = true,
			italic = true;
			color_outline = 0xFF000000,
			draw_flags = 0x10,
			background = 
			T{
				visible = false,
			},
			right_justified = true;
		};
	};

	-- settings for enemy list
	enemyListSettings = 
	T{
		barWidth = 125;
		barHeight = 10;
		textScale = 1;
		entrySpacing = 1;
		bgPadding = 7;
		bgTopPadding = -3;
		maxIcons = 5;
		iconSize = 18;
		debuffOffsetX = -10;
		debuffOffsetY = 0;
	};
};

local defaultUserSettings = deep_copy_table(user_settings);
local config = settings.load(user_settings_container);
gConfig = config.userSettings;

function ResetSettings()
	gConfig = deep_copy_table(defaultUserSettings);
	UpdateSettings();
end

function UpdateSettings()
    -- Save the current settings..
    settings.save();
end;

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        config = s;
		gConfig = config.userSettings;
		UpdateSettings();
    end
end);

-- Get if we are logged in right when the addon loads
bLoggedIn = false;
local playerIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
if playerIndex ~= 0 then
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local flags = entity:GetRenderFlags0(playerIndex);
    if (bit.band(flags, 0x200) == 0x200) and (bit.band(flags, 0x4000) == 0) then
        bLoggedIn = true;
	end
end

--Thanks to Velyn for the event system and interface hidden signatures!
local pGameMenu = ashita.memory.find('FFXiMain.dll', 0, "8B480C85C974??8B510885D274??3B05", 16, 0);
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0);
local pInterfaceHidden = ashita.memory.find('FFXiMain.dll', 0, "8B4424046A016A0050B9????????E8????????F6D81BC040C3", 0, 0);

local function GetMenuName()
    local subPointer = ashita.memory.read_uint32(pGameMenu);
    local subValue = ashita.memory.read_uint32(subPointer);
    if (subValue == 0) then
        return '';
    end
    local menuHeader = ashita.memory.read_uint32(subValue + 4);
    local menuName = ashita.memory.read_string(menuHeader + 0x46, 16);
    return string.gsub(menuName, '\x00', '');
end

local function GetEventSystemActive()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr) == 1);

end

local function GetInterfaceHidden()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pInterfaceHidden + 10);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr + 0xB4) == 1);
end

function GetHidden()

	if (GetEventSystemActive()) then
		return true;
	end

	if (string.match(GetMenuName(), 'map')) then
		return true;
	end

    if (GetInterfaceHidden()) then
        return true;
    end

	if (bLoggedIn == false) then
		return true;
	end
    
    return false;
end

-- Track our packets
ashita.events.register('packet_in', 'packet_in_cb', function (e)
	if (e.id == 0x0028) then
		local actionPacket = ParseActionPacket(e);
		
		if actionPacket then
			engaged.HandleActionPacket(actionPacket);
			debuffs.HandleActionPacket(actionPacket);
		end
	elseif (e.id == 0x00E) then
		local mobUpdatePacket = ParseMobUpdatePacket(e);
		if mobUpdatePacket then
			engaged.HandleMobUpdatePacket(mobUpdatePacket);
		end
	elseif (e.id == 0x00A) then
		engaged.HandleZonePacket(e);
		debuffs.HandleZonePacket(e);
		bLoggedIn = true;
	elseif (e.id == 0x0029) then
		local messagePacket = ParseMessagePacket(e.data);
		if (messagePacket) then
			debuffs.HandleMessagePacket(messagePacket);
		end
	elseif (e.id == 0x00B) then
		bLoggedIn = false;
	elseif (e.id == 0x076) then
		statusHandler.ReadPartyBuffsFromPacket(e);
	end
end);