-- luacheck: globals CreateFrame UIParent UISpecialFrames GameTooltip
-- Fake WoW frames for the week-3 UI specs. A fake records what the window logic depends
-- on (shown state, parent, anchors, scripts and hooks, text, scale, size, mouse-over) and
-- turns every other method into a recorded no-op: f.calls[name] = { args }.
--   Fake.Install()            sets CreateFrame, UIParent, UISpecialFrames, GameTooltip
--   Fake.Uninstall()          clears those globals again (call it in after_each)
--   Fake.New(kind, parent)    a fake frame
--   Fake.Fire(f, script, ...) run f's script and then its HookScript hooks
--   Fake.Strict(f)            from now on log EVERY method call on f, modelled or not
--                             (ruling W3-2): f.log = { { name = "SetParent", args = { ... } }, ... }
-- Show and Hide fire OnShow / OnHide like the client (only on a real change).
local Fake = {}

local methods = {}

function Fake.Fire(f, name, ...)
	local s = f.scripts[name]
	if s then
		s(f, ...)
	end
	for _, h in ipairs(f.hooks[name] or {}) do
		h(f, ...)
	end
end

function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.Show(self)
	if not self.shown then
		self.shown = true
		Fake.Fire(self, "OnShow")
	end
end
function methods.Hide(self)
	if self.shown then
		self.shown = false
		Fake.Fire(self, "OnHide")
	end
end
function methods.SetShown(self, v)
	if v then
		self:Show()
	else
		self:Hide()
	end
end
function methods.SetParent(self, p) self.parent = p end
function methods.GetParent(self) return self.parent end
function methods.SetScale(self, s) self.scale = s end
function methods.GetScale(self) return self.scale end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetWidth(self) return self.w end
function methods.GetHeight(self) return self.h end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetPoint(self, ...)
	local p = { ... }
	self.points[#self.points + 1] = p
	if p[3] == "BOTTOMLEFT" and p[1] == "TOPLEFT" then
		self.left, self.top = p[4], p[5]
	end
end
function methods.SetAllPoints(self, other) self.allPoints = other end
function methods.GetNumPoints(self) return #self.points end
function methods.GetPoint(self, i)
	local p = self.points[i]
	if p then
		return p[1], p[2], p[3], p[4], p[5]
	end
end
function methods.GetLeft(self) return self.left end
function methods.GetTop(self) return self.top end
function methods.SetScript(self, n, fn) self.scripts[n] = fn end
function methods.GetScript(self, n) return self.scripts[n] end
function methods.HookScript(self, n, fn)
	self.hooks[n] = self.hooks[n] or {}
	table.insert(self.hooks[n], fn)
end
function methods.SetText(self, s) self.text = s end
function methods.GetText(self) return self.text end
function methods.IsMouseOver(self) return self.mouseOver == true end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.GetAlpha(self) return self.alpha end
function methods.SetID(self, id) self.id = id end
function methods.GetID(self) return self.id end
function methods.SetVerticalScroll(self, v) self.vscroll = v end
function methods.GetVerticalScroll(self) return self.vscroll end
function methods.CreateFontString(self) return Fake.New("FontString", self) end
function methods.CreateTexture(self) return Fake.New("Texture", self) end

function Fake.New(kind, parent)
	local f = { kind = kind, parent = parent, shown = true, scale = 1, w = 0, h = 0, vscroll = 0, alpha = 1,
		points = {}, scripts = {}, hooks = {}, calls = {} }
	return setmetatable(f, {
		__index = function(_, name)
			return methods[name] or function(self, ...)
				self.calls[name] = { ... }
			end
		end,
	})
end

-- Strict mode (ruling W3-2): every method call, including the modelled ones (Show, Hide,
-- SetScript, SetAlpha, SetScale, ...), is appended to f.log in call order before it runs.
-- Plain fields (f.TabSystem, f.tabs, ...) are not methods and are not logged.
function Fake.Strict(f)
	f.log = {}
	local mt = getmetatable(f)
	local base = mt.__index
	mt.__index = function(t, name)
		local fn = base(t, name)
		return function(self, ...)
			t.log[#t.log + 1] = { name = name, args = { ... } }
			return fn(self, ...)
		end
	end
	return f
end

-- CreateFrame(kind, name, parent, template): like the client, a new frame starts shown.
function Fake.CreateFrame(kind, name, parent, template)
	local f = Fake.New(kind, parent)
	f.name, f.template = name, template
	Fake.created[#Fake.created + 1] = f
	if name then
		Fake.named[name] = f
	end
	return f
end

function Fake.Install()
	Fake.created, Fake.named = {}, {}
	CreateFrame = Fake.CreateFrame
	UIParent = Fake.New("Frame")
	UIParent.shown, UIParent.h = true, 1000
	UISpecialFrames = {}
	GameTooltip = Fake.New("GameTooltip")
	return Fake
end

function Fake.Uninstall()
	UIParent, UISpecialFrames, GameTooltip = nil, nil, nil
end

return Fake
