require('common');
require('helpers');
local imgui = require('imgui');
local progressbar = require('libs/progressbar');
local ffi = require("ffi");
local texts = require('libs/gdifonts/include');

local debugBuffIds = T{};
for i = 1, 32 do
	local buff = nil
	table.insert(debugBuffIds, math.random(1, 631))
end

-- settings for the targetbar
local defaultTargetSettings =
T{
	-- Damage interpolation
	hitInterpolationDecayPercentPerSecond = 200,
	hitDelayDuration = 0.3,
	hitFlashDuration = 0.3,

	-- Everything else
	barWidth = 500,
	barHeight = 18,
	totBarHeight = 14,
	totBarOffset = -1,
	textScale = 1.2,
	cornerOffset = 5,
	nameXOffset = 12,
	nameYOffset = 9,
	iconSize = 26,
	arrowSize = 30,
	nameTextYOffset = 3,
	nameTextXOffset = 3,
	percentTextXOffset = 15,
	distTextXOffset = -3,
	name_font_settings = 
	{
		box_height = 0,
		box_width = 0,
		font_alignment = texts.Alignment.Left;
		font_color = 0xFFFFFFFF,
		font_family = 'Consolas',
		font_flags = texts.FontFlags.Bold,
		font_height = 17,
		gradient_color = 0x00000000,
		gradient_style = 0,
		outline_color = 0xFF000000,
		outline_width = 3,
	
		position_x = 0,
		position_y = 0,
		text = '',
	};
	totName_font_settings = 
	{
		box_height = 0,
		box_width = 0,
		font_alignment = texts.Alignment.Left;
		font_color = 0xFFFFFFFF,
		font_family = 'Consolas',
		font_flags = texts.FontFlags.Bold,
		font_height = 16,
		gradient_color = 0x00000000,
		gradient_style = 0,
		outline_color = 0xFF000000,
		outline_width = 3,
	
		position_x = 0,
		position_y = 0,
		text = '',
	};
	distance_font_settings = 
	{
		box_height = 0,
		box_width = 0,
		font_alignment = texts.Alignment.Right;
		font_color = 0xFFFFFFFF,
		font_family = 'Consolas',
		font_flags = texts.FontFlags.Bold,
		font_height = 15,
		gradient_color = 0x00000000,
		gradient_style = 0,
		outline_color = 0xFF000000,
		outline_width = 3,
	
		position_x = 0,
		position_y = 0,
		text = '',
	};
	percent_font_settings = 
	{
		box_height = 0,
		box_width = 0,
		font_alignment = texts.Alignment.Right;
		font_color = 0xFFFFFFFF,
		font_family = 'Consolas',
		font_flags = texts.FontFlags.Bold,
		font_height = 15,
		gradient_color = 0x00000000,
		gradient_style = 0,
		outline_color = 0xFF000000,
		outline_width = 3,
	
		position_x = 0,
		position_y = 0,
		text = '',
	};
};

local targetSettings = deep_copy_table(defaultTargetSettings);

local initialized = false;

local arrowTexture;
local percentText;
local nameText;
local totNameText;
local distText;
local target = {
	interpolation = {}
};

target.UpdateTextVisibility = function(visible)
	percentText:set_visible(visible);
	nameText:set_visible(visible);
	totNameText:set_visible(visible);
	distText:set_visible(visible);
end

local _HXUI_DEV_DEBUG_INTERPOLATION = false;
local _HXUI_DEV_DEBUG_INTERPOLATION_DELAY = 1;
local _HXUI_DEV_DEBUG_HP_PERCENT_PERSISTENT = 100;
local _HXUI_DEV_DAMAGE_SET_TIMES = {};

target.Initialize = function(settings)
    percentText = texts:create_object(settings.percent_font_settings, false);
	nameText = texts:create_object(settings.name_font_settings, false);
	totNameText = texts:create_object(settings.totName_font_settings, false);
	distText = texts:create_object(settings.distance_font_settings, false);
	arrowTexture = 	LoadTexture("arrow");
	initialized = true;
end

target.UpdateFonts = function(settings)
    percentText:set_font_height(settings.percent_font_settings.font_height);
	nameText:set_font_height(settings.name_font_settings.font_height);
	distText:set_font_height(settings.distance_font_settings.font_height);
	totNameText:set_font_height(settings.totName_font_settings.font_height);
end

target.UpdateSettings = function(userSettings)

	targetSettings = deep_copy_table(defaultTargetSettings);
	targetSettings.barWidth = round(defaultTargetSettings.barWidth * userSettings.targetBarScaleX);
	targetSettings.barHeight = round(defaultTargetSettings.barHeight * userSettings.targetBarScaleY);
	targetSettings.totBarHeight = round(defaultTargetSettings.totBarHeight * userSettings.targetBarScaleY);
	targetSettings.name_font_settings.font_height = math.max(defaultTargetSettings.name_font_settings.font_height + userSettings.targetBarFontOffset, 1);
    targetSettings.totName_font_settings.font_height = math.max(defaultTargetSettings.totName_font_settings.font_height + userSettings.targetBarFontOffset, 1);
	targetSettings.distance_font_settings.font_height = math.max(defaultTargetSettings.distance_font_settings.font_height + userSettings.targetBarFontOffset, 1);
    targetSettings.percent_font_settings.font_height = math.max(defaultTargetSettings.percent_font_settings.font_height + userSettings.targetBarFontOffset, 1);
	targetSettings.iconSize = round(defaultTargetSettings.iconSize * userSettings.targetBarIconScale);
	targetSettings.arrowSize = round(defaultTargetSettings.arrowSize * userSettings.targetBarScaleY);

	if not initialized then
		target.Initialize(targetSettings);
	else
		target.UpdateFonts(targetSettings);
	end
end

target.DrawWindow = function(settings)
    -- Obtain the player entity..
    local playerEnt = GetPlayerEntity();
	local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (playerEnt == nil or player == nil) then
		target.UpdateTextVisibility(false);
        return;
    end

    -- Obtain the player target entity (account for subtarget)
	local targetIndex, _ = statusHelpers.GetTargets();
	if (gShowConfig[1]) then
		targetIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
	end
	local targetEntity = GetEntity(targetIndex);

    if (targetEntity == nil or targetEntity.Name == nil) then
		target.UpdateTextVisibility(false);

		target.interpolation.interpolationDamagePercent = 0;

        return;
    end

	local currentTime = os.clock();

	local hppPercent = targetEntity.HPPercent;

	-- Mimic damage taken
	if _HXUI_DEV_DEBUG_INTERPOLATION then
		if _HXUI_DEV_DAMAGE_SET_TIMES[1] and currentTime > _HXUI_DEV_DAMAGE_SET_TIMES[1][1] then
			_HXUI_DEV_DEBUG_HP_PERCENT_PERSISTENT = _HXUI_DEV_DAMAGE_SET_TIMES[1][2];

			table.remove(_HXUI_DEV_DAMAGE_SET_TIMES, 1);
		end

		if #_HXUI_DEV_DAMAGE_SET_TIMES == 0 then
			local previousHitTime = currentTime + 1;
			local previousHp = 100;

			local totalDamageInstances = 10;

			for i = 1, totalDamageInstances do
				local hitDelay = math.random(0.25 * 100, 1.25 * 100) / 100;
				local damageAmount = math.random(1, 20);

				if i > 1 and i < totalDamageInstances then
					previousHp = math.max(previousHp - damageAmount, 0);
				end

				if i < totalDamageInstances then
					previousHitTime = previousHitTime + hitDelay;
				else
					previousHitTime = previousHitTime + _HXUI_DEV_DEBUG_INTERPOLATION_DELAY;
				end

				_HXUI_DEV_DAMAGE_SET_TIMES[i] = {previousHitTime, previousHp};
			end
		end

		hppPercent = _HXUI_DEV_DEBUG_HP_PERCENT_PERSISTENT;
	end

	-- If we change targets, reset the interpolation
	if target.interpolation.currentTargetId ~= targetIndex then
		target.interpolation.currentTargetId = targetIndex;
		target.interpolation.currentHpp = hppPercent;
		target.interpolation.interpolationDamagePercent = 0;
	end

	-- If the target takes damage
	if hppPercent < target.interpolation.currentHpp then
		local previousInterpolationDamagePercent = target.interpolation.interpolationDamagePercent;

		local damageAmount = target.interpolation.currentHpp - hppPercent;

		target.interpolation.interpolationDamagePercent = target.interpolation.interpolationDamagePercent + damageAmount;

		if previousInterpolationDamagePercent > 0 and target.interpolation.lastHitAmount and damageAmount > target.interpolation.lastHitAmount then
			target.interpolation.lastHitTime = currentTime;
			target.interpolation.lastHitAmount = damageAmount;
		elseif previousInterpolationDamagePercent == 0 then
			target.interpolation.lastHitTime = currentTime;
			target.interpolation.lastHitAmount = damageAmount;
		end

		if not target.interpolation.lastHitTime or currentTime > target.interpolation.lastHitTime + (targetSettings.hitFlashDuration * 0.25) then
			target.interpolation.lastHitTime = currentTime;
			target.interpolation.lastHitAmount = damageAmount;
		end

		-- If we previously were interpolating with an empty bar, reset the hit delay effect
		if previousInterpolationDamagePercent == 0 then
			target.interpolation.hitDelayStartTime = currentTime;
		end
	elseif hppPercent > target.interpolation.currentHpp then
		-- If the target heals
		target.interpolation.interpolationDamagePercent = 0;
		target.interpolation.hitDelayStartTime = nil;
	end

	target.interpolation.currentHpp = hppPercent;

	-- Reduce the HP amount to display based on the time passed since last frame
	if target.interpolation.interpolationDamagePercent > 0 and target.interpolation.hitDelayStartTime and currentTime > target.interpolation.hitDelayStartTime + targetSettings.hitDelayDuration then
		if target.interpolation.lastFrameTime then
			local deltaTime = currentTime - target.interpolation.lastFrameTime;

			local animSpeed = 0.1 + (0.9 * (target.interpolation.interpolationDamagePercent / 100));

			-- animSpeed = math.max(targetSettings.hitDelayMinAnimSpeed, animSpeed);

			target.interpolation.interpolationDamagePercent = target.interpolation.interpolationDamagePercent - (targetSettings.hitInterpolationDecayPercentPerSecond * deltaTime * animSpeed);

			-- Clamp our percent to 0
			target.interpolation.interpolationDamagePercent = math.max(0, target.interpolation.interpolationDamagePercent);
		end
	end

	if gConfig.healthBarFlashEnabled then
		if target.interpolation.lastHitTime and currentTime < target.interpolation.lastHitTime + targetSettings.hitFlashDuration then
			local hitFlashTime = currentTime - target.interpolation.lastHitTime;
			local hitFlashTimePercent = hitFlashTime / targetSettings.hitFlashDuration;

			local maxAlphaHitPercent = 20;
			local maxAlpha = math.min(target.interpolation.lastHitAmount, maxAlphaHitPercent) / maxAlphaHitPercent;

			maxAlpha = math.max(maxAlpha * 0.6, 0.4);

			target.interpolation.overlayAlpha = math.pow(1 - hitFlashTimePercent, 2) * maxAlpha;
		end
	end

	target.interpolation.lastFrameTime = currentTime;

	local color = GetColorOfTarget(targetEntity, targetIndex);
	local isMonster = GetIsMob(targetEntity);

	-- Draw the main target window
	local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus);
	if (gConfig.lockPositions) then
		windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
	end
    if (imgui.Begin('HitPoints - Target', true, windowFlags)) then
        
		-- Obtain and prepare target information..
        local dist  = ('%.1f'):fmt(math.sqrt(targetEntity.Distance));
		local targetNameText = targetEntity.Name;
		local targetHpPercent = targetEntity.HPPercent..'%';

		if (gConfig.showEnemyId and (isMonster or gShowConfig[1])) then
			local targetServerId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(targetIndex);
			local targetServerIdHex = string.format('0x%X', targetServerId);

			targetNameText = targetNameText .. " [".. string.sub(targetServerIdHex, -3) .."]";
		end

		local hpGradientStart = '#e26c6c';
		local hpGradientEnd = '#fb9494';

		local hpPercentData = {{targetEntity.HPPercent / 100, {hpGradientStart, hpGradientEnd}}};

		if _HXUI_DEV_DEBUG_INTERPOLATION then
			hpPercentData[1][1] = target.interpolation.currentHpp / 100;
		end

		if target.interpolation.interpolationDamagePercent > 0 then
			local interpolationOverlay;

			if gConfig.healthBarFlashEnabled then
				interpolationOverlay = {
					'#FFFFFF', -- overlay color,
					target.interpolation.overlayAlpha -- overlay alpha,
				};
			end

			table.insert(
				hpPercentData,
				{
					target.interpolation.interpolationDamagePercent / 100, -- interpolation percent
					{'#cf3437', '#c54d4d'},
					interpolationOverlay
				}
			);
		end
		
		local startX, startY = imgui.GetCursorScreenPos();
		progressbar.ProgressBar(hpPercentData, {targetSettings.barWidth, targetSettings.barHeight}, {decorate = gConfig.showBookends});

		nameText:set_position_x(startX + targetSettings.nameTextXOffset);
		nameText:set_position_y(startY - targetSettings.nameTextYOffset - targetSettings.name_font_settings.font_height);
		nameText:set_font_color(color);
		nameText:set_text(targetNameText);
		nameText:set_visible(true);

		distText:set_position_x(startX + targetSettings.distTextXOffset);
		distText:set_position_y(startY - targetSettings.name_font_settings.font_height / 2 + targetSettings.barHeight / 2);
		distText:set_text(tostring(dist));
		distText:set_visible(true);

		if (isMonster or gConfig.alwaysShowHealthPercent) then
			percentText:set_position_x(startX + targetSettings.barWidth - targetSettings.percentTextXOffset);
			percentText:set_position_y(startY - targetSettings.distance_font_settings.font_height);
			percentText:set_text(tostring(targetHpPercent));
			percentText:set_visible(true);
			local hpColor, _ = GetHpColors(targetEntity.HPPercent / 100);
			percentText:set_font_color(hpColor);
		else
			percentText:set_visible(false);
		end

		-- Draw buffs and debuffs
		imgui.SameLine();
		local preBuffX, preBuffY = imgui.GetCursorScreenPos();
		local buffIds = gStatusLib.GetStatusIdsByIndex(targetIndex);
		if (gShowConfig[1]) then
			buffIds = debugBuffIds;
		end
		imgui.NewLine();
		imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, {1, 3});
		DrawStatusIcons(buffIds, targetSettings.iconSize, gConfig.targetBarNumStatusPerRow, 5, targetSettings.barHeight/2);
		imgui.PopStyleVar(1);

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
		if (totEntity ~= nil and totEntity.Name ~= nil) then

			imgui.SetCursorScreenPos({preBuffX, preBuffY});
			local totX, totY = imgui.GetCursorScreenPos();
			local totColor = GetColorOfTarget(totEntity, totIndex);
			imgui.SetCursorScreenPos({totX, totY + targetSettings.barHeight/2 - targetSettings.arrowSize/2});
			imgui.Image(tonumber(ffi.cast("uint32_t", arrowTexture.image)), { targetSettings.arrowSize, targetSettings.arrowSize });
			imgui.SameLine();

			totX, _ = imgui.GetCursorScreenPos();
			imgui.SetCursorScreenPos({totX, totY - (targetSettings.totBarHeight / 2) + (targetSettings.barHeight/2) + targetSettings.totBarOffset});

			local totStartX, totStartY = imgui.GetCursorScreenPos();
			progressbar.ProgressBar({{totEntity.HPPercent / 100, {'#e16c6c', '#fb9494'}}}, {targetSettings.barWidth / 3, targetSettings.totBarHeight}, {decorate = gConfig.showBookends});

			totNameText:set_position_x(totStartX + targetSettings.nameTextXOffset);
			totNameText:set_position_y(totStartY - targetSettings.totName_font_settings.font_height);
			totNameText:set_font_color(totColor);
			totNameText:set_text(totEntity.Name);
			totNameText:set_visible(true);
		else
			totNameText:set_visible(false);
		end
    end
    imgui.End();
end

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb_target', function ()

	if (gConfig.showTargetBar) then
		target.DrawWindow();
	else
		target.UpdateTextVisibility(false);
	end
end);

ashita.events.register('unload', 'unload_cb_target', function ()
    texts:destroy_interface();
end)

return target;