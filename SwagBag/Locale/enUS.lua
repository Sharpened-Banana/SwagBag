-- SwagBag UI strings (P8: every user-visible string lives here and nowhere else).
-- Missing keys fall back to the key itself, so a typo shows up as e.g. "SAFE_ON_BAGZ"
-- in game instead of an error. spec/locale_spec.lua checks that every key used in
-- SwagBag/ is defined here.
local _, SB = ...

local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
SB.L = L

-- General
L.LOADED = "v%s loaded. Type /swagbag help for commands."
L.UNKNOWN_COMMAND = "Unknown command \"%s\". Type /swagbag help for the list."
L.CMD_DONE = "Done."
L.CMD_FAILED = "That command hit an error. It was recorded; type /swagbag report."
L.NO_SETTINGS_YET = "There is no settings window yet. Type /swagbag help for commands."

-- Help
L.HELP_HEADER = "Commands:"
L.HELP_LINE = "/swagbag %s - %s"
L.HELP_HELP = "show this list"
L.HELP_SAFE = "safe [on|off|bags|bank]: show or switch Safe Mode (Blizzard bags)"
L.HELP_REPORT = "open a copyable report to paste into Claude Code"
L.HELP_CHECK = "run all feature checks and print PASS/FAIL"
L.HELP_RESET = "reset all SwagBag settings (asks first, keeps a backup)"
L.HELP_DEBUG = "debug error [bags|bank]: inject a test error to prove Safe Mode; debug v1: V1 test strip"
L.HELP_SEARCH = "search <text>: search the open bag window and print the match count"

-- Safe Mode
L.SAFE_STATE_OFF = "off"
L.SAFE_STATE_ON = "on (%s, %s)"
L.SAFE_REASON_MANUAL = "manual"
L.SAFE_REASON_AUTO = "auto"
L.SAFE_REASON_CHECK = "failed check"
L.SAFE_REASON_SCHEMA = "newer settings"
L.SAFE_STATUS = "Safe Mode: bags=%s bank=%s"
L.SAFE_NOW_ON = "Safe Mode is ON for %s: Blizzard's frames are used. Type /swagbag safe off to switch back."
L.SAFE_NOW_OFF = "Safe Mode is OFF for %s: SwagBag handles them again."
L.SAFE_ALREADY_ON = "Safe Mode was already ON for %s."
L.SAFE_ALREADY_OFF = "Safe Mode was already OFF for %s."
L.SAFE_USAGE = "Use /swagbag safe on, off, bags or bank."
L.WINDOW_BAGS = "bags"
L.WINDOW_BANK = "bank"

-- Errors
L.ERROR_SWITCHED = "SwagBag hit an error and switched to Blizzard bags. Type /swagbag report."
L.ERROR_STILL_FAILING = "Still failing - stay in Safe Mode and send the report (/swagbag report)."
L.DEBUG_ERROR_TEXT = "SwagBag test error (injected by /swagbag debug error)"
L.DEBUG_ERROR_DONE = "Injected a test error into the %s path."
L.DEBUG_USAGE = "Use /swagbag debug error [bags|bank] or /swagbag debug v1."

-- Settings / schema
L.NEWER_SCHEMA = "Settings are from a newer version; update the addon or type /swagbag reset. Running in Safe Mode."
L.MIGRATION_FAILED = "Could not upgrade your settings; they were backed up and reset to defaults. Type /swagbag report."
L.RESET_CONFIRM = "Reset ALL SwagBag settings? A backup copy is kept."
L.RESET_ASKED = "Confirm the reset in the dialog."
L.RESET_DONE = "Settings were reset (a backup was kept). Type /reload to finish."

-- Checks
L.CHECK_PRESENT = "present"
L.CHECK_MISSING = "missing"
L.CHECK_EXPECTED = "expected %s, got %s"
L.CHECK_PASS_LINE = "|cff44ff44PASS|r %s"
L.CHECK_FAIL_LINE = "|cffff4444FAIL|r %s (%s)%s"
L.CHECK_OPTIONAL = " [optional]"
L.CHECK_SUMMARY = "Checks: %d passed, %d failed (%d required)."

-- Report
L.REPORT_TITLE = "SwagBag report - press Ctrl+C to copy, Esc to close"
L.REPORT_OPENED = "Report opened. Press Ctrl+C to copy it, then paste it into Claude Code."
L.REPORT_HEADER = "SwagBag %s | WoW %s (%s) | %s | %s"
L.REPORT_SAFE = "Safe Mode: bags=%s bank=%s"
L.REPORT_FAILED_CHECKS = "Failed checks: %s"
L.REPORT_NONE = "none"
L.REPORT_ERRORS = "Errors (last %d):"
L.REPORT_ERROR_LINE = " %s [%s%s] %s: %s"
L.REPORT_IN_COMBAT = ", in combat"
L.REPORT_BLOCKED = "Blocked actions: %s"
L.REPORT_BLOCKED_ITEM = "%s at %s%s"
L.REPORT_ADDONS = "Bag-related addons: %s"
L.REPORT_NOT_LOADED = "%s (not loaded)"
L.REPORT_SETTINGS = "Settings hash: %s  Schema: %d  Buttons: %d (%d ms)"

-- Bags window
L.BAGS_TITLE = "SwagBag"
L.BAGS_SCALE = "SwagBag %d%%"

-- Search
L.SEARCH_RESULT = "Search \"%s\": %d of %d slots match (%.1f ms)."
L.SEARCH_CLEARED = "Search cleared."
L.SEARCH_OPEN_FIRST = "Open your bags first (press B), then search again."
L.SEARCH_ERROR = "Search error: %s"

-- Query errors
L.QUERY_ERR_AFTER = "Expected %s after \"%s\" at character %d"
L.QUERY_ERR_FOUND = "Expected %s but found %s at character %d"
L.QUERY_EXPECT_VALUE = "a value"
L.QUERY_EXPECT_NUMBER = "a number"
L.QUERY_EXPECT_RPAREN = "a closing )"
L.QUERY_EXPECT_QUOTE = "a closing \""
L.QUERY_EXPECT_KEYWORD = "a known keyword"
L.QUERY_EXPECT_NUMERIC = "a keyword that takes a number (ilvl, level, count, stack, gear, tab)"
L.QUERY_EXPECT_OPERATOR = "& or |"
L.QUERY_EXPECT_SHALLOWER = "fewer nested ( and ! (at most 100 levels)"
L.QUERY_EXPECT_AND_BEFORE_COMPARISON = "& or | before a multi-word phrase and a comparison"
L.QUERY_FOUND_END = "the end of the search"

-- In-game check V1 (optional)
L.V1_TITLE = "SwagBag V1 test: right-click these in combat"
L.V1_SHOWN = "V1 strip shown with %d usable items. Enter combat, right-click them 3 times, then /swagbag report."
L.V1_HIDDEN = "V1 strip hidden."
L.V1_COMBAT = "Open the V1 strip out of combat; it can only be filled then."
