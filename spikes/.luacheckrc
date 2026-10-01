-- THROWAWAY SPIKE lint config. WoW API globals are not listed, so
-- "accessing undefined global" (113) is ignored; writes to globals are
-- still reported unless whitelisted below.
std = "lua51"
max_line_length = false
ignore = { "113", "212", "542" }
globals = { "SwagBagSpikesDB", "SLASH_SWAGBAGSPIKES1", "SLASH_SWAGBAGSPIKES2", "SlashCmdList", "UISpecialFrames" }
