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
local imgui = require('imgui');
local settings = require('settings');


local default_settings =
T{
	barWidth = 600,
	barHeight = 20,
	totBarHeight = 16,
	totBarOffset = 1,
	textScale = 1.2,
	showBarPercent = true;
}
local config = settings.load(default_settings);

-- TODO: Calculate these instead of manually setting them
local cornerOffset = 5;
local nameXOffset = 12;
local nameYOffset = 26;

local bgAlpha = 0.4;
local bgRadius = 6;

local function update_settings(s)
    if (s ~= nil) then
        configs = s;
    end

    settings.save();
end

settings.register('settings', 'settings_update', update_settings);

local function draw_rect(top_left, bot_right, color, radius)
    local color = imgui.GetColorU32(color);
    local dimensions = {
        { top_left[1], top_left[2] },
        { bot_right[1], bot_right[2] }
    };
    imgui.GetWindowDrawList():AddRectFilled(dimensions[1], dimensions[2], color, radius, ImDrawCornerFlags_All);
end

local function GetColorOfTarget(targetEntity, targetIndex)
    -- Obtain the entity spawn flags..
    local flag = targetEntity.SpawnFlags;
    local color;

    -- Determine the entity type and apply the proper color
    if (bit.band(flag, 0x0001) == 0x0001) then --players
        color = {1,1,1,1};
		local party = AshitaCore:GetMemoryManager():GetParty();
		for i = 0, 17 do
			if (party:GetMemberIsActive(i) == 1) then
				if (party:GetMemberTargetIndex(i) == targetIndex) then
					color = {0,1,1,1};
					break;
				end
			end
		end
    elseif (bit.band(flag, 0x0002) == 0x0002) then --npc
        color = {.4,1,.4,1};
    else --mob
		local entMgr = AshitaCore:GetMemoryManager():GetEntity();
		local claimStatus = entMgr:GetClaimStatus(targetIndex);
		local claimId = bit.band(claimStatus, 0xFFFF);
--		local isClaimed = (bit.band(claimStatus, 0xFFFF0000) ~= 0);

		if (claimId == 0) then
			color = {1,1,.4,1};
		else
			color = {1,.4,1,1};
			local party = AshitaCore:GetMemoryManager():GetParty();
			for i = 0, 17 do
				if (party:GetMemberIsActive(i) == 1) then
					if (party:GetMemberServerId(i) == claimId) then
						color = {1,.4,.4,1};
						break;
					end;
				end
			end
		end
	end
	return color;
end

local function GetIsMob(targetEntity)
    -- Obtain the entity spawn flags..
    local flag = targetEntity.SpawnFlags;
    -- Determine the entity type
	local isMob;
    if (bit.band(flag, 0x0001) == 0x0001 or bit.band(flag, 0x0002) == 0x0002) then --players and npcs
        isMob = false;
    else --mob
		isMob = true;
    end
	return isMob;
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function ()
    -- Obtain the player entity..
    local playerEnt = GetPlayerEntity();
	local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (playerEnt == nil or player == nil) then
        return;
    end
	local currJob = player:GetMainJob();
    if (player.isZoning or currJob == 0) then        
        return;
	end

    -- Obtain the player target entity (account for subtarget)
	local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
	local targetIndex;
	local targetEntity;
	if (playerTarget ~= nil) then
		if (playerTarget:GetIsSubTargetActive() > 0) then
			targetIndex = playerTarget:GetTargetIndex(0);
		else
			targetIndex = playerTarget:GetTargetIndex(0);
		end
		targetEntity = GetEntity(targetIndex);
	end
    if (targetEntity == nil or targetEntity.Name == nil) then
        return;
    end

	local color = GetColorOfTarget(targetEntity, targetIndex);
	local showTargetId = GetIsMob(targetEntity);

    imgui.SetNextWindowSize({ config.barWidth, -1, }, ImGuiCond_Always);
	
	-- Draw the main target window
    if (imgui.Begin('TargetInfo', true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground))) then
		imgui.SetWindowFontScale(config.textScale);
        -- Obtain and prepare target information..
        local dist  = ('%.1f'):fmt(math.sqrt(targetEntity.Distance));
        local x, _  = imgui.CalcTextSize(dist);
		local targetNameText = targetEntity.Name;
		if (showTargetId) then
			targetNameText = targetNameText.." ["..targetIndex.."]";
		end
		local y, _  = imgui.CalcTextSize(targetNameText);

		local winX, winY = imgui.GetWindowPos();
		draw_rect({winX + cornerOffset , winY + cornerOffset}, {winX + y + nameXOffset, winY + nameYOffset}, {0,0,0,bgAlpha}, bgRadius, ImDrawCornerFlags_All);

        -- Display the targets information..
        imgui.TextColored(color, targetNameText);
        imgui.SameLine();
        imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetColumnWidth() - x - imgui.GetStyle().FramePadding.x);
        imgui.Text(dist);

		if (config.showBarPercent == true) then
			imgui.ProgressBar(targetEntity.HPPercent / 100, { -1, config.barHeight});
		else
			imgui.ProgressBar(targetEntity.HPPercent / 100, { -1, config.barHeight}, '');
		end
		
    end
	local winPosX, winPosY = imgui.GetWindowPos();
    imgui.End();
	
	
	-- Obtain our target of target (not always accurate)
	local totEntity;
	local totIndex
	if (targetEntity == playerEnt) then
		totIndex = targetIndex
		totEntity = targetEntity;
	end
	if (totEntity == nil) then
		totIndex = targetEntity.TargetedIndex;
		if (totIndex ~= nil) then
			totEntity = GetEntity(totIndex);
		end
	end
	if (totEntity == nil) then
		return;
	end;
	local targetNameText = totEntity.Name;
	if (targetNameText == nil) then
		return;
	end;
	
	local totColor = GetColorOfTarget(totEntity, totIndex);
	imgui.SetNextWindowPos({winPosX + config.barWidth, winPosY + config.totBarOffset});
    imgui.SetNextWindowSize({ config.barWidth / 3, -1, }, ImGuiCond_Always);
	
	if (imgui.Begin('TargetOfTargetInfo', true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground))) then
        -- Obtain and prepare target information.
		imgui.SetWindowFontScale(config.textScale);
		
		local w, _  = imgui.CalcTextSize(targetNameText);

		local totwinX, totwinY = imgui.GetWindowPos();
		draw_rect({totwinX + cornerOffset, totwinY + cornerOffset}, {totwinX + w + nameXOffset, totwinY + nameYOffset}, {0,0,0,bgAlpha}, bgRadius);

		-- Display the targets information..
		imgui.TextColored(totColor, targetNameText);
		imgui.ProgressBar(totEntity.HPPercent / 100, { -1, config.totBarHeight }, '');
    end
    imgui.End();
end);

ashita.events.register('command', 'command_cb', function (ee)
    -- Parse the command arguments
    local args = ee.command:args();
    if (#args == 0 or args[1] ~= '/targetinfo') then
        return;
    end

    -- Block all targetinfo related commands
    ee.blocked = true;

	-- redirect to config file for the time being
    print('TargetInfo: Please check the config file for available options such as barLength, barHeight, etc.');
    return;
end);