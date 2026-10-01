-- =====================================================================
-- THROWAWAY SPIKE CODE  -  SwagBagSpikes / SpikeAPI.lua
-- Spike H (adapted): API-presence dump + conflicting-addon detection.
-- Runs automatically at login. Read-only.
-- =====================================================================
local _, ns = ...

ns.RegisterSpike("API", "API presence dump + conflicting addons", "H (adapted)",
	"Which C_* APIs / Blizzard frames SwagBag can rely on in this build; whether other bag addons contaminated the run")

local REQUIRED = {
	"C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "C_Container.GetContainerItemID",
	"C_Container.SortBags", "C_Container.SortBank", "C_Container.UseContainerItem", "C_Container.PickupContainerItem",
	"C_Bank.FetchPurchasedBankTabIDs", "C_Bank.FetchViewableBankTypes", "C_Bank.CanUseBank", "C_Bank.IsItemAllowedInBankType",
	"C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemSpell", "C_Item.GetCurrentItemLevel", "C_Item.IsBound",
	"C_AddOns.IsAddOnLoaded", "C_Spell.GetSpellName", "C_TooltipInfo.GetBagItem",
	"GetAddOnMemoryUsage", "UpdateAddOnMemoryUsage", "GetMouseFoci", "debugprofilestop", "InCombatLockdown", "hooksecurefunc",
	"ContainerFrameCombinedBags", "BankFrame", "BankFrame.GetActiveBankType", "BankFrame.BankPanel", "BankFrame.TabSystem",
	"ToggleAllBags", "OpenAllBags", "CloseAllBags", "ToggleBackpack",
	"ContainerFrameItemButtonMixin", "SetItemButtonTexture", "SetItemButtonCount", "SetItemButtonQuality",
	"ItemLocation.CreateFromBagAndSlot",
}

local OPTIONAL = {
	"C_Container.SortBankBags", "C_Container.SortAccountBankBags", "C_Container.SortReagentBankBags",
	"C_ChallengeMode.IsChallengeModeActive", "C_ChallengeMode.GetActiveChallengeMapID", "C_ChallengeMode.GetActiveKeystoneInfo",
	"C_PartyInfo.IsChallengeModeActive", "C_RestrictedActions.IsAddOnRestrictionActive", "C_RestrictedActions.GetAddOnRestrictionState",
	"C_PlayerInteractionManager.IsInteractingWithNpcOfType", "C_Map.GetBestMapForUnit",
	"GetProfessions", "GetProfessionInfo", "IsFishingLoot", "GetLootSourceInfo", "GetInstanceInfo", "IsInInstance", "UnitChannelInfo",
	"issecretvalue", "C_Bank.AutoDepositItemsIntoBank", "ContainerFrameSettingsManager", "UISpecialFrames",
	"ContainerFrameItemButtonMixin.SetBagID", "BankFrame.SetTab", "PlayerInteractionFrameManager", "RegisterPlayerInteraction",
	"Auctionator.API.v1.GetAuctionPriceByItemLink", "TSM_API.GetCustomPriceValue", "Syndicator.API",
}

-- Old global functions removed/deprecated; expected nil on 12.1.5.
local LEGACY = {
	"GetItemInfo", "GetItemInfoInstant", "GetContainerItemInfo", "GetContainerNumSlots", "GetItemCount", "GetItemSpell",
	"UseContainerItem", "GetAddOnMetadata", "IsAddOnLoaded", "GetContainerItemLink", "SortBags", "SortBankBags",
}

local BAG_ADDONS = {
	"Baganator", "Bagnon", "BetterBags", "AdiBags", "ArkInventory", "Inventorian", "LiteBag", "Bagforge", "Combuctor",
	"ElvUI", "EllesmereUIBags", "EnhanceQoLBags", "Narcissus_BagFilter", "TradeSkillMaster", "Sorted", "cargBags_Nivaya",
	"NDui", "GW2_UI", "TitanBag", "BagSync", "Syndicator", "DataStore_Containers", "WarbandNexus",
}

local function Presence(list)
	local out, missing = {}, {}
	for _, path in ipairs(list) do
		local v = ns.Resolve(path)
		out[path] = v == nil and "MISSING" or type(v)
		if v == nil then table.insert(missing, path) end
	end
	return out, missing
end

local function EnumDump(name)
	local e = Enum and Enum[name]
	if type(e) ~= "table" then return "MISSING" end
	local t = {}
	for k, v in pairs(e) do t[k] = v end
	return t
end

local function Run()
	local req, missingReq = Presence(REQUIRED)
	local opt = Presence(OPTIONAL)
	local legacy = Presence(LEGACY)
	ns.Data("API", "required", req)
	ns.Data("API", "optional", opt)
	ns.Data("API", "legacyGlobals", legacy)
	ns.Data("API", "enums", {
		BagIndex = EnumDump("BagIndex"), BankType = EnumDump("BankType"),
		AddOnRestrictionType = EnumDump("AddOnRestrictionType"),
		PlayerInteractionType_Banker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker,
		PlayerInteractionType_AccountBanker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.AccountBanker,
		PlayerInteractionType_CharacterBanker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.CharacterBanker,
	})
	local okCv, combined = pcall(function() return C_CVar.GetCVar("combinedBags") end)
	ns.Data("API", "cvar_combinedBags", okCv and combined or "?")

	local loaded = {}
	local frameReplacers = {}
	for _, name in ipairs(BAG_ADDONS) do
		local ok, isLoaded = pcall(C_AddOns.IsAddOnLoaded, name)
		if ok and isLoaded then
			loaded[#loaded + 1] = name
			if name ~= "Syndicator" and name ~= "DataStore_Containers" and name ~= "BagSync" and name ~= "TitanBag" and name ~= "WarbandNexus" then
				frameReplacers[#frameReplacers + 1] = name
			end
		end
	end
	-- ElvUI only matters if its bag module is on
	local elvBags
	pcall(function()
		local E = ElvUI and ElvUI[1]
		elvBags = E and E.private and E.private.bags and E.private.bags.enable
	end)
	ns.Data("API", "bagRelatedAddonsLoaded", loaded)
	ns.Data("API", "elvuiBagModuleEnabled", elvBags)

	local okA, numAddons = pcall(C_AddOns.GetNumAddOns)
	local enabledCount = 0
	if okA then
		for i = 1, numAddons do
			local ok, isLoaded = pcall(C_AddOns.IsAddOnLoaded, i)
			if ok and isLoaded then enabledCount = enabledCount + 1 end
		end
	end
	ns.Data("API", "addonsLoadedCount", enabledCount)

	ns.Check("API", "requiredApisPresent", #missingReq == 0, { missing = missingReq })
	local contaminated = #frameReplacers > 0
	ns.Check("API", "noOtherBagFrameAddons", not contaminated, { loaded = frameReplacers })
	if contaminated then
		ns.Print("|cffff4444WARNING:|r other bag/bank addons are loaded (" .. table.concat(frameReplacers, ", ")
			.. "). Safe-Mode and bank results may be wrong. See README step 2 (disable them for this character).")
	end
	ns.Summary("API", ("missing required: %d; other bag addons loaded: %s"):format(#missingReq,
		#frameReplacers > 0 and table.concat(frameReplacers, ",") or "none"))
end

ns.OnLogin(function() ns.Try("API.Run", Run) end)
ns.Command("api", "re-run the API presence dump (spike H)", function() Run() ns.Print("API dump done") end)
ns.commands.h = ns.commands.api
