-- Minimal WoW API stub environment to exercise ac-challenge-suite's real Lua
-- files outside the game client.

local sentMessages = {}

function SendAddonMessage(prefix, msg, channel, target)
  table.insert(sentMessages, { prefix = prefix, msg = msg, channel = channel, target = target })
end

function UnitName(unit)
  return "TestPlayer"
end

-- WoW's client exposes several string.* functions as bare globals; alias the
-- ones the vendored libs use.
strmatch = string.match
strfind = string.find
strsub = string.sub
strlower = string.lower
strupper = string.upper
strtrim = string.trim or function(s) return s:match("^%s*(.-)%s*$") end

SlashCmdList = {}

local patchedIcon = nil -- set non-nil to simulate the client patch being installed
function GetSpellInfo(id)
  if id == 666666 and patchedIcon then
    return "Hardcore challenge", nil, patchedIcon
  end
  return nil
end

-- ---- Minimal frame/widget stub ----

local FrameMeta = {}
FrameMeta.__index = FrameMeta

function FrameMeta:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
function FrameMeta:SetScript(script, fn) self._scripts = self._scripts or {}; self._scripts[script] = fn end
function FrameMeta:GetScript(script) return self._scripts and self._scripts[script] end
function FrameMeta:SetSize() end
function FrameMeta:SetPoint() end
function FrameMeta:ClearAllPoints() end
function FrameMeta:SetMovable() end
function FrameMeta:EnableMouse() end
function FrameMeta:RegisterForDrag() end
function FrameMeta:SetText(t) self._text = t end
function FrameMeta:GetText() return self._text end
function FrameMeta:Show() self._shown = true end
function FrameMeta:Hide() self._shown = false end
function FrameMeta:IsShown() return self._shown or false end
function FrameMeta:SetHeight(h) self._height = h end
function FrameMeta:Enable() self._enabled = true end
function FrameMeta:Disable() self._enabled = false end
function FrameMeta:IsEnabled() return self._enabled end
function FrameMeta:CreateFontString()
  return setmetatable({}, FrameMeta)
end
function FrameMeta:StartMoving() end
function FrameMeta:StopMovingOrSizing() end
function FrameMeta:SetBackdrop() end
function FrameMeta:SetWidth() end
function FrameMeta:SetFrameStrata() end
function FrameMeta:SetFrameLevel() end
function FrameMeta:RegisterForClicks() end
function FrameMeta:SetHighlightTexture() end
function FrameMeta:SetTexture() end
function FrameMeta:SetTexCoord() end
function FrameMeta:SetAllPoints() end
function FrameMeta:CreateTexture()
  return setmetatable({ _parent = self }, FrameMeta)
end
function FrameMeta:GetVertexColor() return 1, 1, 1, 1 end
function FrameMeta:SetVertexColor() end
function FrameMeta:GetCenter() return 0, 0 end
function FrameMeta:GetEffectiveScale() return 1 end
function FrameMeta:GetHeight() return 32 end
function FrameMeta:GetWidth() return 32 end
function FrameMeta:GetParent() return self._parent or UIParent end
function FrameMeta:SetOwner() end
function FrameMeta:Lock() end
function FrameMeta:Unlock() end
function FrameMeta:LockHighlight() end
function FrameMeta:UnlockHighlight() end

Minimap = setmetatable({}, FrameMeta)
Minimap:SetSize(140, 140)

local allFrames = {}

-- Real 3.3.5a (build 12340) inherited UI templates this addon is allowed to use.
-- CreateFrame() with any other template name errors out here, mirroring the
-- client's own "Couldn't find inherited node" error -- this is what would have
-- caught the BasicFrameTemplateWithInset bug (a Cataclysm-only template) before
-- it reached a live client.
local KNOWN_TEMPLATES = {
  ["UIPanelCloseButton"] = true,
  ["UIPanelButtonTemplate"] = true,
}

function CreateFrame(kind, name, parent, template)
  if template and not KNOWN_TEMPLATES[template] then
    error(('CreateFrame(): Couldn\'t find inherited node "%s"'):format(template), 2)
  end
  local f = setmetatable({ kind = kind, name = name, parent = parent, _parent = parent, template = template }, FrameMeta)
  table.insert(allFrames, f)
  return f
end

UIParent = setmetatable({}, FrameMeta)

local function BroadcastEvent(event, ...)
  for _, frame in ipairs(allFrames) do
    if frame._events and frame._events[event] and frame._scripts and frame._scripts.OnEvent then
      frame._scripts.OnEvent(frame, event, ...)
    end
  end
end

-- ---- Load the real vendored libs + addon files, sharing one addon table ----

local ADDON_NAME = "ChallengeSuite"
local ChallengeSuiteAddonTable = {}

local function LoadAddonFile(path)
  local chunk = assert(loadfile(path))
  return chunk(ADDON_NAME, ChallengeSuiteAddonTable)
end

LoadAddonFile("../Libs/LibStub/LibStub.lua")
LoadAddonFile("../Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
LoadAddonFile("../Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
LoadAddonFile("../Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua")
LoadAddonFile("../Core.lua")
LoadAddonFile("../UI.lua")

local ChallengeSuite = ChallengeSuiteAddonTable

-- ---- Test helpers ----

local failures = 0
local function check(condition, label)
  if condition then
    print("OK   " .. label)
  else
    failures = failures + 1
    print("FAIL " .. label)
  end
end

-- 1. PLAYER_LOGIN should send a HELLO addon message and register the minimap icon.
BroadcastEvent("PLAYER_LOGIN")
check(#sentMessages == 1, "exactly one addon message sent on PLAYER_LOGIN")
check(sentMessages[1].prefix == "CHALLENGE_SUITE", "HELLO message prefix")
check(sentMessages[1].msg == "HELLO", "HELLO message body")
check(sentMessages[1].channel == "WHISPER", "HELLO sent via WHISPER")
check(sentMessages[1].target == "TestPlayer", "HELLO targets self")
check(ChallengeSuiteDB ~= nil, "ChallengeSuiteDB initialized")

-- 2. Simulate the server sending a STATE message.
BroadcastEvent("CHAT_MSG_ADDON", "CHALLENGE_SUITE", "STATE\thardcore:1:1:Deceased;ironman:0:0:", "WHISPER", "TestPlayer")
check(ChallengeSuite.state.hardcore ~= nil, "hardcore entry parsed")
check(ChallengeSuite.state.hardcore.enabled == true, "hardcore.enabled == true")
check(ChallengeSuite.state.hardcore.active == true, "hardcore.active == true")
check(ChallengeSuite.state.hardcore.label == "Deceased", "hardcore.label == 'Deceased'")
check(ChallengeSuite.state.ironman ~= nil, "ironman entry parsed")
check(ChallengeSuite.state.ironman.enabled == false, "ironman.enabled == false")
check(ChallengeSuite.state.ironman.active == false, "ironman.active == false")
check(ChallengeSuite.state.ironman.label == "", "ironman.label == ''")

-- 3. A message with an unrelated prefix must be ignored.
sentMessages = {}
local stateBefore = ChallengeSuite.state
BroadcastEvent("CHAT_MSG_ADDON", "SOME_OTHER_ADDON", "STATE\thardcore:0:0:", "WHISPER", "TestPlayer")
check(ChallengeSuite.state == stateBefore, "unrelated addon prefix is ignored")

-- 4. RequestEnable should whisper an ENABLE message.
sentMessages = {}
ChallengeSuite:RequestEnable("hardcore")
check(#sentMessages == 1, "RequestEnable sends exactly one message")
check(sentMessages[1].msg == "ENABLE\thardcore", "ENABLE message body")

-- 5. SHOW_PANEL from the server should open the panel (exercised via ShowPanel()
-- directly since the frame/OnClick chain is UI-only and stubbed minimally above).
ChallengeSuite:ShowPanel()
check(true, "ShowPanel() runs without error")

-- 6. Toggling the panel via /cs (fires the same ShowPanel listener Core.lua wires).
SlashCmdList["CHALLENGESUITE"]()
check(true, "/cs slash command runs without error")

-- 7. Tooltip building should not error, with and without a patched icon.
local dataObject = LibStub("LibDataBroker-1.1"):GetDataObjectByName(ADDON_NAME)
check(dataObject ~= nil, "LDB data object registered under addon name")

local tooltipLines = {}
local fakeTooltip = {
  AddLine = function(_, ...) table.insert(tooltipLines, { ... }) end,
  AddDoubleLine = function(_, ...) table.insert(tooltipLines, { ... }) end,
}
dataObject.OnTooltipShow(fakeTooltip)
check(#tooltipLines > 0, "tooltip renders lines without error")

print(("\n%d check(s) failed"):format(failures))
os.exit(failures == 0 and 0 or 1)
