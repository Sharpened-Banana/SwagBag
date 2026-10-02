-- SwagBag lint config. Addon code is Lua 5.1 (WoW). WoW API names are listed
-- explicitly so a typo in an API name is a lint error, not a runtime error.
std = "lua51"
max_line_length = 140
codes = true

-- Globals SwagBag may WRITE.
globals = {
	"SwagBagDB", "SwagBagCharDB", "SLASH_SWAGBAG1", "SlashCmdList", "StaticPopupDialogs",
}

-- WoW globals SwagBag may READ.
read_globals = {
	"C_AddOns", "C_Bank", "C_Container", "C_Item", "C_Timer", "C_ToyBox", "Enum", "ItemLocation",
	"CreateFrame", "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "ChatFontNormal",
	"GetTime", "debugprofilestop", "debugstack", "date", "GetBuildInfo", "GetLocale",
	"InCombatLockdown", "issecretvalue", "hooksecurefunc", "IsControlKeyDown", "ToggleBag",
	"NUM_CONTAINER_FRAMES", "ContainerFrameCombinedBags",
	"SetItemButtonTexture", "SetItemButtonCount", "SetItemButtonQuality", "SetItemButtonDesaturated",
	"StaticPopup_Show", "YES", "NO",
	"GetCursorInfo", "ClearCursor", "GameTooltip",
	"GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemInfo", "GetGuildBankItemLink", "QueryGuildBankTab",
	"GetCurrentGuildBankTab", "AutoStoreGuildBankItem", "PickupGuildBankItem", "GetGuildInfo", "GetRealmName",
	"IsModifiedClick", "HandleModifiedItemClick", "time", "UnitName", "UnitClass", "UnitLevel",
	"C_ChallengeMode", "C_PlayerInfo", "GetInventoryItemLink",
	"C_RestrictedActions", "C_PartyInfo", "C_Spell", "C_NewItems", "C_CurrencyInfo",
}

files["spec/"] = {
	std = "+busted",
	globals = {
		"CreateFrame", "SwagBagDB", "SwagBagCharDB", "hooksecurefunc", "NUM_CONTAINER_FRAMES",
		"ContainerFrame1", "ContainerFrame2", "ContainerFrameCombinedBags", "ToggleBag",
	},
}
files["spec/runner.lua"] = {
	globals = { "describe", "it", "before_each", "after_each", "assert" },
}
files["scripts/"] = { std = "lua51" }
