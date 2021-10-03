script_name("HMNP");
script_author("Elaboro | github.com/Elaboro");

local gameKeys = require 'game.keys';
local hook = require 'lib.samp.events';
local inicfg = require 'inicfg';
require 'lib.moonloader';
require 'lib.sampfuncs';

local g_to_close_dialog = false;
local g_reclose_dialog = false;

function main()
	if(not isSampfuncsLoaded() or not isSampLoaded()) then return end
	while (not isSampAvailable()) do wait(100); end
	
	loadSettings();
	showStartText();
	
	lua_thread.create(threadCloseDialogFix);
	lua_thread.create(threadShowStatisticsFishing);
	
	sampRegisterChatCommand("hmnp", CMDDialogMenu);
	threadDialogMenu = lua_thread.create_suspended(dialogMenuSuspended);
	
	wait(-1);
end

local HMNPSettings = inicfg.load({
	auto_fishing = {
		AUTO_FISHING_ENABLED = true,
		SOUND_OF_BELL_ENABLED = false,
		FISH_WEIGHT_ALLOWED = 5,
		COUNT_CAUGHT_FISH_ALL_TIME = 0,
		COUNT_WEIGHT_FISH_ALL_TIME = 0,
		COUNT_MONEY_FISH_ALL_TIME = 0
	},
	auto_sell_fish = {
		AUTO_SELL_FISH_ENABLED = true
	}
}, "HMNPSettings");

local AUTO_FISHING_ENABLED = nil;
local SOUND_OF_BELL_ENABLED = nil;
local FISH_WEIGHT_ALLOWED = nil;
local AUTO_SELL_FISH_ENABLED = nil;

local COUNT_CAUGHT_FISH_ALL_TIME = nil;
local COUNT_WEIGHT_FISH_ALL_TIME = nil;
local COUNT_MONEY_FISH_ALL_TIME = nil;

function loadSettings()
	AUTO_FISHING_ENABLED = HMNPSettings.auto_fishing.AUTO_FISHING_ENABLED;
	SOUND_OF_BELL_ENABLED = HMNPSettings.auto_fishing.SOUND_OF_BELL_ENABLED;
	FISH_WEIGHT_ALLOWED = HMNPSettings.auto_fishing.FISH_WEIGHT_ALLOWED;
	AUTO_SELL_FISH_ENABLED = HMNPSettings.auto_sell_fish.AUTO_SELL_FISH_ENABLED;
	
	COUNT_CAUGHT_FISH_ALL_TIME = HMNPSettings.auto_fishing.COUNT_CAUGHT_FISH_ALL_TIME;
	COUNT_WEIGHT_FISH_ALL_TIME = HMNPSettings.auto_fishing.COUNT_WEIGHT_FISH_ALL_TIME;
	COUNT_MONEY_FISH_ALL_TIME = HMNPSettings.auto_fishing.COUNT_MONEY_FISH_ALL_TIME;
	
	inicfg.save(HMNPSettings, "HMNPSettings");
end

function showStartText()
	local name = thisScript().name;
	local authors = table.concat(thisScript().authors, "");
	local start_text = string.format(
		"Название скрипта: {FF4500}%s{FFFFFF}. "..
		"Автор скрипта: {FF4500}%s{FFFFFF}.",
		name, authors
	);
	sampAddChatMessage(start_text, 0xFFFFFF);
	
	sampAddChatMessage("Меню: {FF4500}/hmnp{FFFFFF}.", 0xFFFFFF);
end

local font_flag = require('moonloader').font_flag
local my_font = renderCreateFont('Arial', 12, font_flag.BOLD + font_flag.SHADOW)

function threadShowStatisticsFishing()
	COUNT_CAUGHT_FISH_CURRENT_HOUR = 0;
	COUNT_WEIGHT_FISH_CURRENT_HOUR = 0;
	COUNT_MONEY_FISH_CURRENT_HOUR = 0;
	
	COUNT_CAUGHT_FISH_PREVIOUS_HOUR = 0;
	COUNT_WEIGHT_FISH_PREVIOUS_HOUR = 0;
	COUNT_MONEY_FISH_PREVIOUS_HOUR = 0;
	
	COUNT_CAUGHT_FISH_ALL_TIME = 0;
	COUNT_WEIGHT_FISH_ALL_TIME = 0;
	COUNT_MONEY_FISH_ALL_TIME = 0;

	while true do
		wait(7);
		local stats_text = "За текущий час поймано {008000}".. COUNT_CAUGHT_FISH_CURRENT_HOUR .."{FFFFFF} рыб(ы), "..
		"весом {008000}".. COUNT_WEIGHT_FISH_CURRENT_HOUR .."{FFFFFF} кг и "..
		"продано за {008000}$".. COUNT_MONEY_FISH_CURRENT_HOUR .."{FFFFFF}.\n" ..
		"За предыдущий час поймано {008000}".. COUNT_CAUGHT_FISH_PREVIOUS_HOUR .."{FFFFFF} рыб(ы), "..
		"весом {008000}".. COUNT_WEIGHT_FISH_PREVIOUS_HOUR .."{FFFFFF} кг и "..
		"продано за {008000}$".. COUNT_MONEY_FISH_PREVIOUS_HOUR .."{FFFFFF}.\n" ..
		"За всё время поймано {008000}".. COUNT_CAUGHT_FISH_ALL_TIME .."{FFFFFF} рыб(ы), "..
		"весом {008000}".. COUNT_WEIGHT_FISH_ALL_TIME .."{FFFFFF} кг "..
		"и продано за {008000}$".. COUNT_MONEY_FISH_ALL_TIME .."{FFFFFF}.";
		
		renderFontDrawText(my_font, stats_text, 420, 1010, 0xFFFFFFFF);
	end
end

function hook.onPlaySound(soundId, position)
	if(AUTO_FISHING_ENABLED == true) then 
		lua_thread.create(threadFishingPlaySound, soundId, position);
		if(soundId == 6401) then return SOUND_OF_BELL_ENABLED; end
	end
end

function hook.onServerMessage(color, text)
	if(AUTO_FISHING_ENABLED == true) then
		lua_thread.create(threadFishingServerMessage, color, text);
	end
end

function hook.onShowDialog(dialogId, style, title, button1, button2, text)
	if(AUTO_FISHING_ENABLED == true) then
		lua_thread.create(threadFishingShowDialog, dialogId, style, title, button1, button2, text);
	end
	
	if(AUTO_SELL_FISH_ENABLED == true) then
		lua_thread.create(threadSellFishShowDialog, dialogId, style, title, button1, button2, text);
	end
end

function hook.onSetInterior(interior)
	if(AUTO_SELL_FISH_ENABLED == true) then
		lua_thread.create(threadSellFishInInterior, interior);
	end
end

function onQuitGame()
	saveHMNPSettings();
end

function saveHMNPSettings()
	print("Saving settings...");
	inicfg.save(HMNPSettings, "HMNPSettings");
	print("Done.");
end

local DIALOG_STYLE = {
	MSGBOX = 0,
	INPUT = 1,
	LIST = 2,
	PASSWORD = 3,
	TABLIST = 4,
	TABLIST_HEADERS = 5
}

local DIALOG_BUTTON = {
	NO = "",
	ENTER = "Ввод",
	SELECT = "Выбрать",
	CANCEL = "Отмена",
	NEXT = "Далее",
	BACK = "Назад"
}

local STATUS_ON = "{008000}вкл";
local STATUS_OFF = "{FF0000}выкл";
local TURN_ON = "Включить";
local TURN_OFF = "Выключить";

function CMDDialogMenu()
	threadDialogMenu:run();
end

function dialogMenuSuspended()
	local result = true;
	local dialogName = "DialogMainMenu";
	
	while(result == true) do
		wait(0);
		result, dialogName = showDialog(dialogName);
	end
end

function showDialog(dialogName)
	local result = false;
	result, dialogName = DIALOG_TABLE[dialogName]();
	return result, dialogName;
end

function localShowDialog(caption, text, button1, button2, style)
	local result = false;
	local button = nil;
	local list = nil;
	local input = nil;
	sampShowDialog(10000, caption, text, button1, button2, style);
	while not result do
		wait(70);
		result, button, list, input = sampHasDialogRespond(10000);
	end
	return result, button, list, input;
end

function DialogMainMenu()
	local result = false;
	local dialogName = "empty";
	
	local dCaption = "Меню";
	local dText = nil;
	local dButton1 = DIALOG_BUTTON.SELECT;
	local dButton2 = DIALOG_BUTTON.CANCEL;
	local dStyle = DIALOG_STYLE.TABLIST_HEADERS;
	
	local statusAutoFishing = nil;
	local statusAutoSellFish = nil;
	
	if(AUTO_FISHING_ENABLED == false) then
		statusAutoFishing = STATUS_OFF;
	else
		statusAutoFishing = STATUS_ON;
	end
	
	if(AUTO_SELL_FISH_ENABLED == false) then
		statusAutoSellFish = STATUS_OFF;
	else
		statusAutoSellFish = STATUS_ON;
	end
	
	dText = "Название\tСтатус\n"..
	"Автоматическая рыбалка\t".. statusAutoFishing .."\n"..
	"Автоматическая продажа рыбы\t".. statusAutoSellFish .."\n";
	
	local button, list, input = nil;
	_, button, list, input = localShowDialog(dCaption, dText, dButton1, dButton2, dStyle);
	if(button == 0) then
		return result, dialogName;
	end
	
	if(button == 1 and list == 0) then
		result = true;
		dialogName = "DialogAutoFishing";
	end
	
	if(button == 1 and list == 1) then
		result = true;
		dialogName = "DialogAutoSellFish";
	end
	
	return result, dialogName;
end

function DialogAutoSellFish()
	local result = false;
	local dialogName = "empty";
	
	local dCaption = "Автоматическая продажа рыбы";
	local dText = nil;
	local dButton1 = DIALOG_BUTTON.SELECT;
	local dButton2 = DIALOG_BUTTON.BACK;
	local dStyle = DIALOG_STYLE.LIST;
	
	if(AUTO_SELL_FISH_ENABLED == false) then
		dText = TURN_ON;
	else
		dText = TURN_OFF;
	end
	
	local button, list, input = nil;
	_, button, list, input = localShowDialog(dCaption, dText, dButton1, dButton2, dStyle);
	if(button == 0) then
		result = true;
		dialogName = "DialogMainMenu";
		return result, dialogName;
	end
	
	if(button == 1 and list == 0) then
		if(AUTO_SELL_FISH_ENABLED == false) then
			AUTO_SELL_FISH_ENABLED = true;
		else
			AUTO_SELL_FISH_ENABLED = false;
		end
		HMNPSettings.auto_sell_fish.AUTO_SELL_FISH_ENABLED = AUTO_SELL_FISH_ENABLED;
		inicfg.save(HMNPSettings, "HMNPSettings");
		result = true;
		dialogName = "DialogAutoSellFish";
	end
	
	return result, dialogName;
end

function DialogAutoFishing()
	local result = false;
	local dialogName = "empty";
	
	local dCaption = "Автоматическая рыбалка";
	local dText = nil;
	local dButton1 = DIALOG_BUTTON.SELECT;
	local dButton2 = DIALOG_BUTTON.BACK;
	local dStyle = DIALOG_STYLE.TABLIST_HEADERS;
	
	local txtAutoFishing = nil;
	local statusAutoFishing = nil;
	local statusSoundBell = nil;
	local modeAutoFishing = nil;
	
	if(AUTO_FISHING_ENABLED == false) then
		txtAutoFishing = TURN_ON;
		statusAutoFishing = STATUS_OFF;
	else
		txtAutoFishing = TURN_OFF;
		statusAutoFishing = STATUS_ON;
	end
	
	if(SOUND_OF_BELL_ENABLED == false) then
		statusSoundBell = STATUS_ON;
	else
		statusSoundBell = STATUS_OFF;
	end
	
	modeAutoFishing = "< " .. tostring(FISH_WEIGHT_ALLOWED) .. " кг";
	
	dText = "Название\tСтатус\n"..
	txtAutoFishing .."\t".. statusAutoFishing .."\n"..
	"Без звука колокольчика\t".. statusSoundBell .."\n"..
	"Настроить выброс рыбы\t".. modeAutoFishing .."\n";
	
	local button, list, input = nil;
	_, button, list, input = localShowDialog(dCaption, dText, dButton1, dButton2, dStyle);
	if(button == 0) then
		result = true;
		dialogName = "DialogMainMenu";
		return result, dialogName;
	end
	
	if(button == 1 and list == 0) then
		if(AUTO_FISHING_ENABLED == true) then
			AUTO_FISHING_ENABLED = false;
		else
			AUTO_FISHING_ENABLED = true;
		end
		HMNPSettings.auto_fishing.AUTO_FISHING_ENABLED = AUTO_FISHING_ENABLED;
		inicfg.save(HMNPSettings, "HMNPSettings");
		result = true;
		dialogName = "DialogAutoFishing";
	end
	
	if(button == 1 and list == 1) then
		if(SOUND_OF_BELL_ENABLED == true)then
			SOUND_OF_BELL_ENABLED = false;
		else
			SOUND_OF_BELL_ENABLED = true;
		end
		HMNPSettings.auto_fishing.SOUND_OF_BELL_ENABLED = SOUND_OF_BELL_ENABLED;
		inicfg.save(HMNPSettings, "HMNPSettings");
		result = true;
		dialogName = "DialogAutoFishing";
	end
	
	if(button == 1 and list == 2) then
		result = true;
		dialogName = "DialogSettingModeFishing";
	end
	
	return result, dialogName;
end

function DialogSettingModeFishing()
	local result = false;
	local dialogName = "empty";
	
	local dCaption = "Настройка выброса рыбы";
	local dText = nil;
	local dButton1 = DIALOG_BUTTON.SELECT;
	local dButton2 = DIALOG_BUTTON.BACK;
	local dStyle = DIALOG_STYLE.LIST;
	
	dText = 
	"Выбрасывать меньше 5 килограмм\n"..
	"Выбрасывать меньше 6 килограмм\n"..
	"Ручная настройка";
	
	local button, list, input = nil;
	_, button, list, input = localShowDialog(dCaption, dText, dButton1, dButton2, dStyle);
	if(button == 0) then
		result = true;
		dialogName = "DialogAutoFishing";
		return result, dialogName;
	end
	
	if(button == 1 and list == 0) then
		FISH_WEIGHT_ALLOWED = 5;
		result = true;
		dialogName = "DialogAutoFishing";
	end
	
	if(button == 1 and list == 1) then
		FISH_WEIGHT_ALLOWED = 6;
		result = true;
		dialogName = "DialogAutoFishing";
	end
	
	if(button == 1 and list == 2) then
		result = true;
		dialogName = "DialogManualSettingDismissFish";
	end
	
	HMNPSettings.auto_fishing.FISH_WEIGHT_ALLOWED = FISH_WEIGHT_ALLOWED;
	inicfg.save(HMNPSettings, "HMNPSettings");
	
	return result, dialogName;
end

function DialogManualSettingDismissFish()
	local result = false;
	local dialogName = "empty";
	
	local dCaption = "Ручная настройка выброса рыбы";
	local dText = nil;
	local dButton1 = DIALOG_BUTTON.ENTER;
	local dButton2 = DIALOG_BUTTON.CANCEL;
	local dStyle = DIALOG_STYLE.INPUT;
	
	dText = 
	"Возможно выбрасывать рыбу меньше 1-20 кг.\n"..
	"Введите число от 1 до 20:\n";
	
	local button, list, input = nil;
	_, button, list, input = localShowDialog(dCaption, dText, dButton1, dButton2, dStyle);
	if(button == 0) then
		result = true;
		dialogName = "DialogSettingModeFishing";
		return result, dialogName;
	end
	
	if(button == 1) then
		local strLen = string.len(input);
		if(strLen == 0 or strLen > 2) then
			result = true;
			dialogName = "DialogManualSettingDismissFish";
		else
			local kg = nil;
			if(tonumber(string.match(input, '%d+')) == nil) then
				kg = 0;
			else
				kg = tonumber(string.match(input, '%d+'));
			end
			
			if(kg >= 1 and kg <= 20) then
				FISH_WEIGHT_ALLOWED = kg;
				HMNPSettings.auto_fishing.FISH_WEIGHT_ALLOWED = FISH_WEIGHT_ALLOWED;
				inicfg.save(HMNPSettings, "HMNPSettings");
				result = true;
				dialogName = "DialogAutoFishing";
			else
				result = true;
				dialogName = "DialogManualSettingDismissFish";
			end
		end
	end
	
	return result, dialogName;
end

DIALOG_TABLE = {
	["DialogMainMenu"] = DialogMainMenu,
	["DialogAutoFishing"] = DialogAutoFishing,
	["DialogAutoSellFish"] = DialogAutoSellFish,
	["DialogSettingModeFishing"] = DialogSettingModeFishing,
	["DialogManualSettingDismissFish"] = DialogManualSettingDismissFish,
}

function threadSellFishInInterior(interior)
	wait(0);
	if(interior == 1) then
		wait(1500);
		sampProcessChatInput("/sell fish");
	end
end

function threadSellFishShowDialog(dialogId, style, title, button1, button2, text)
	if(string.find(title, "^{FFFFFF}Продажа рыбы$")) then
		sampSendDialogResponse(dialogId, 1, 8, "");
		g_to_close_dialog = true;
	end
end

g_auto_dismiss_fish = false;
g_bell_tinkled = 0;
g_count_fish = 0;
g_fish = {0, 0, 0, 0, 0, 0, 0, 0};
g_caught_fish_id = 0;

function threadFishingPlaySound(soundId, position)
	wait(0);
	if(isDoublePlayedSoundBell(soundId)) then
		pullOutFishingRod();
		castFishingRod();
	end
end

function isDoublePlayedSoundBell(soundId)
	local result = false;
	if(soundId ~= 6401) then 
		return result;
	end
	if(g_bell_tinkled == 0) then
		g_bell_tinkled = 1;
		return result;
	end
	result = true;
	g_bell_tinkled = 0;
	return result;
end

function pullOutFishingRod()
	wait(70);
	setGameKeyState(gameKeys.player.WALK, 255);
end

function castFishingRod()
	wait(1000);
	setGameKeyState(gameKeys.player.WALK, 255);
end

function threadFishingServerMessage(color, text)
	wait(0);	-- If don't use wait(0) then will crash GTA reason in function sampProcessChatInput.
	if(string.find(text, "^Рыба продана за %$%d+.$")) then
		local cMoney = tonumber(string.match(text, '%d+'));
		local cFish = 0;
		local cFishKg = 0;
		for i = 1, #g_fish do
			if(g_fish[i] ~= 0) then
				cFishKg = cFishKg + g_fish[i];
				cFish = cFish + 1;
			end
		end
		
		COUNT_CAUGHT_FISH_CURRENT_HOUR = COUNT_CAUGHT_FISH_CURRENT_HOUR + cFish;
		COUNT_WEIGHT_FISH_CURRENT_HOUR = COUNT_WEIGHT_FISH_CURRENT_HOUR + cFishKg;
		COUNT_MONEY_FISH_CURRENT_HOUR = COUNT_MONEY_FISH_CURRENT_HOUR + cMoney;
		
		COUNT_CAUGHT_FISH_ALL_TIME = COUNT_CAUGHT_FISH_ALL_TIME + cFish;
		COUNT_WEIGHT_FISH_ALL_TIME = COUNT_WEIGHT_FISH_ALL_TIME + cFishKg;
		COUNT_MONEY_FISH_ALL_TIME = COUNT_MONEY_FISH_ALL_TIME + cMoney;
		
		HMNPSettings.auto_fishing.COUNT_CAUGHT_FISH_ALL_TIME = COUNT_CAUGHT_FISH_ALL_TIME;
		HMNPSettings.auto_fishing.COUNT_WEIGHT_FISH_ALL_TIME = COUNT_WEIGHT_FISH_ALL_TIME;
		HMNPSettings.auto_fishing.COUNT_MONEY_FISH_ALL_TIME = COUNT_MONEY_FISH_ALL_TIME;
		inicfg.save(HMNPSettings, "HMNPSettings");
	
		g_fish = {0, 0, 0, 0, 0, 0, 0, 0};
		g_count_fish = 0;
		g_bell_tinkled = 0;
	end
	
	if(string.find(text, "^Лотерея%$ Через 2 минуты начинаем розыгрыш, набери ..%S+ .%S+ .%S+ . %S+.... Разыгрывается %S+.$")) then
		COUNT_CAUGHT_FISH_PREVIOUS_HOUR = COUNT_CAUGHT_FISH_CURRENT_HOUR;
		COUNT_WEIGHT_FISH_PREVIOUS_HOUR = COUNT_WEIGHT_FISH_CURRENT_HOUR;
		COUNT_MONEY_FISH_PREVIOUS_HOUR = COUNT_MONEY_FISH_CURRENT_HOUR;
		
		COUNT_CAUGHT_FISH_CURRENT_HOUR = 0;
		COUNT_WEIGHT_FISH_CURRENT_HOUR = 0;
		COUNT_MONEY_FISH_CURRENT_HOUR = 0;
	end
	
	if(string.find(text, "^Твой улов: %S+ | Вес: %d+ кг.$")) then 
		local kgFish = tonumber(string.match(text, '%d+'));
		if(kgFish < FISH_WEIGHT_ALLOWED) then
			findIdCaughtFish();
			saveChatInputText();
			g_auto_dismiss_fish = true;
			sampProcessChatInput("/fishes");
		else
			setCaughtKgFish(kgFish);
		end
	end
end

function setCaughtKgFish(kgFish)
	findIdCaughtFish();
	g_fish[g_caught_fish_id] = kgFish;
end

function findIdCaughtFish()
	g_caught_fish_id = 0;
	for i = 1, #g_fish do
		if(g_fish[i] == 0) then
			g_caught_fish_id = i;
			break;
		end
	end
end

function threadFishingShowDialog(dialogId, style, title, button1, button2, text)
	wait(0);
	
	if(string.find(title, "^{FFFFFF}Пойманная рыба$")) then
		
		setActualDataFishing(text);
	
		if(g_reclose_dialog == true) then
			g_to_close_dialog = true;
			g_reclose_dialog = false;
			recoverChatInputText();
			return;
		end
		if(g_auto_dismiss_fish ~= true) then return; end
		g_auto_dismiss_fish = false;
		dismissFish(dialogId);
		g_to_close_dialog = true;
		g_reclose_dialog = true;	
	end
end

function setActualDataFishing(text)
	local bracket = false;
	local ch = 1;
	local fish_id = 1;
	local i = 0;
	local n = string.len(text);
	while(i ~= n) do
		i = i + 1;
		ch = string.byte(text, i);
		
		if(ch == 123) then
			bracket = true;
		end
		if(ch == 125) then
			bracket = false;
		end
		
		if(ch == 60 and bracket == false) then
			g_fish[fish_id] = 0;
			fish_id = fish_id + 1;
		end
		
		if(ch >= 48 and ch <= 57 and bracket == false) then
			g_fish[fish_id] = tonumber(string.match(text, "%d+", i-1));
			fish_id = fish_id + 1;
			i = i + 2;
		end
	end
	
	g_count_fish = 0;
	for i = 1, #g_fish do
		if(g_fish[i] ~= 0) then
			g_count_fish = g_count_fish + 1;
		end
	end
	
end

function dismissFish(dialogId)
	if(g_caught_fish_id == 0) then
		sampAddChatMessage("Выброс рыбы начат, но она поймана полностью. Сброс.", 0xFFFFFF);
		return;
	end
	sampSendDialogResponse(dialogId, 1, g_caught_fish_id - 1, "");
	g_fish[g_caught_fish_id] = 0;
end

local CHAT_INPUT_ACTIVE = false;
local CHAT_TEXT_SAVED = "";

function saveChatInputText()
	if(not sampIsChatInputActive()) then return; end
	CHAT_INPUT_ACTIVE = true;
	CHAT_TEXT_SAVED = sampGetChatInputText();
	sampSetChatInputEnabled(false);
end

function recoverChatInputText()
	if(CHAT_INPUT_ACTIVE ~= true) then return; end
	sampSetChatInputEnabled(true);
	sampSetChatInputText(CHAT_TEXT_SAVED);
	CHAT_INPUT_ACTIVE = false;
end

function threadCloseDialogFix()
	wait(0);
	while(true) do
		wait(0);
		if(g_to_close_dialog == true and sampIsDialogActive()) then
			sampCloseCurrentDialogWithButton(0);
			g_to_close_dialog = false;
		end
	end
end
