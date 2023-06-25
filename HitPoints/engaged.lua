require('common');
require('helpers');
local imgui = require('imgui');
local progressbar = require('libs/progressbar');

-- TODO: Calculate these instead of manually setting them
local bgAlpha = 0.4;
local bgRadius = 3;
local engaged = {};

local debugBuffIds = T{};
for i = 1, 32 do
	local buff = nil
	table.insert(debugBuffIds, math.random(1, 631))
end

-- settings for enemy list
local defaultEngagedSettings = 
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

local engagedSettings = deep_copy_table(defaultEngagedSettings);

engaged.UpdateSettings = function(userSettings)
	engagedSettings = deep_copy_table(defaultEngagedSettings);
	engagedSettings.barWidth = round(defaultEngagedSettings.barWidth * userSettings.enemyListScaleX);
	engagedSettings.barHeight = round(defaultEngagedSettings.barHeight * userSettings.enemyListScaleY);
	engagedSettings.textScale = defaultEngagedSettings.textScale * userSettings.enemyListFontScale;
	engagedSettings.iconSize = round(defaultEngagedSettings.iconSize * userSettings.enemyListIconScale);
end

local function GetIsValidMob(mobIdx)
	-- Check if we are valid, are above 0 hp, and are rendered, or just in config mode to show whatever
	if (gShowConfig[1]) then return true end
    local renderflags = AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(mobIdx);
    if bit.band(renderflags, 0x200) ~= 0x200 or bit.band(renderflags, 0x4000) ~= 0 then
        return false;
    end
	return true;
end

engaged.DrawWindow = function()

	imgui.SetNextWindowSize({ engagedSettings.barWidth, -1, }, ImGuiCond_Always);
	-- Draw the main target window
	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);
	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end
	if (imgui.Begin('HitPoints - Engaged', true, windowFlags)) then
		imgui.SetWindowFontScale(engagedSettings.textScale);
		local winStartX, _ = imgui.GetWindowPos();
		local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
		local targetIndex;
		local subTargetIndex;
		local subTargetActive = false;
		if (playerTarget ~= nil) then
			subTargetActive = GetSubTargetActive();
			targetIndex, subTargetIndex = statusHelpers.GetTargets();
			if (subTargetActive) then
				local tempTarget = targetIndex;
				targetIndex = subTargetIndex;
				subTargetIndex = tempTarget;
			end
		end
		
		local numTargets = 0;

		-- Get our enemies
		local engagedEnemies = gStatusLib.GetRelevantEnemies();

		-- Add ALL the targets if we are in gShowConfig mode
		if gShowConfig[1] then
			engagedEnemies = T{};
			for i = 0,1024 do
				table.insert(engagedEnemies, 1);
			end
		end

		for k,v in pairs(engagedEnemies) do
			local ent = GetEntity(k);
			if (v ~= nil and ent ~= nil and GetIsValidMob(k)) then
				-- Obtain and prepare target information..
				local targetNameText = ent.Name;
				if (targetNameText ~= nil) then

					local color = GetColorOfTargetRGBA(ent, k);
					imgui.Dummy({0,engagedSettings.entrySpacing});
					local rectLength = imgui.GetColumnWidth() + imgui.GetStyle().FramePadding.x;
					
					-- draw background to entry
					local winX, winY  = imgui.GetCursorScreenPos();

					-- Figure out sizing on the background
					local cornerOffset = engagedSettings.bgTopPadding;
					local _, yDist = imgui.CalcTextSize(targetNameText);
					if (yDist > engagedSettings.barHeight) then
						yDist = yDist + yDist;
					else
						yDist = yDist + engagedSettings.barHeight;
					end

					draw_rect({winX + cornerOffset , winY + cornerOffset}, {winX + rectLength, winY + yDist + engagedSettings.bgPadding}, {0,0,0,bgAlpha}, bgRadius, true);

					-- Draw outlines for our target and subtarget
					if (subTargetIndex ~= nil and k == subTargetIndex) then
						draw_rect({winX + cornerOffset, winY + cornerOffset}, {winX + rectLength - 1, winY + yDist + engagedSettings.bgPadding}, {.5,.5,1,1}, bgRadius, false);
					elseif (targetIndex ~= nil and k == targetIndex) then
						draw_rect({winX + cornerOffset, winY + cornerOffset}, {winX + rectLength - 1, winY + yDist + engagedSettings.bgPadding}, {1,1,1,1}, bgRadius, false);
					end

					-- Display the targets information..
					imgui.TextColored(color, targetNameText);
					local percentText  = ('%.f'):fmt(ent.HPPercent);
					local x, _  = imgui.CalcTextSize(percentText);
					local fauxX, _  = imgui.CalcTextSize('100');

					-- Draw buffs and debuffs
					local buffIds = gStatusLib.GetStatusIdsByIndex(k);
					if (gShowConfig[1]) then
						buffIds = debugBuffIds;
					end
					if (buffIds ~= nil and #buffIds > 0) then
						imgui.SetNextWindowPos({winStartX + engagedSettings.barWidth + engagedSettings.debuffOffsetX, winY + engagedSettings.debuffOffsetY});
						if (imgui.Begin('HitPoints - EngagedStatus'..k, true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoSavedSettings))) then
							imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {1, 1});
							DrawStatusIcons(buffIds, engagedSettings.iconSize, gConfig.enemyListMaxIcons, 1);
							imgui.PopStyleVar(1);
						end 
						imgui.End();
					end

					imgui.SetCursorPosX(imgui.GetCursorPosX() + fauxX - x);
					imgui.Text(percentText);
					imgui.SameLine();
					imgui.SetCursorPosX(imgui.GetCursorPosX() - 3);
					-- imgui.ProgressBar(ent.HPPercent / 100, { -1, settings.barHeight}, '');
					progressbar.ProgressBar({{ent.HPPercent / 100, {'#e16c6c', '#fb9494'}}}, {-1, engagedSettings.barHeight}, {decorate = gConfig.showBookends});
					imgui.SameLine();

					imgui.Separator();

					numTargets = numTargets + 1;
					if (numTargets >= gConfig.enemyListMaxEntries) then
						break;
					end
				end
			end
		end
	end
	imgui.End();
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb_engaged', function ()

	if (gConfig.showEnemyList) then
		engaged.DrawWindow();
	end
end);


return engaged;