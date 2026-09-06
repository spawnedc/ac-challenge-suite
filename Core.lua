local ADDON_NAME, ChallengeSuite = ...

local PREFIX = "CHALLENGE_SUITE"

-- ChallengeSuite.state[id] = { enabled = bool, active = bool, label = string }
-- Mirrors the STATE message from mod-challenge-suite's addon protocol.
ChallengeSuite.state = {}

local listeners = {}

-- Simple pub/sub so UI.lua can react to state updates / SHOW_PANEL without Core.lua
-- knowing anything about the UI.
function ChallengeSuite:On(event, fn)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], fn)
end

local function Fire(event, ...)
  for _, fn in ipairs(listeners[event] or {}) do
    fn(...)
  end
end

-- Parses "id:enabled:active:label;id:enabled:active:label;..." (trailing fields
-- may be empty, e.g. "hardcore:1:0:").
local function ParseState(body)
  local state = {}
  for entry in (body or ""):gmatch("[^;]+") do
    local id, enabled, active, label = entry:match("^([^:]*):([^:]*):([^:]*):?(.*)$")
    if id and id ~= "" then
      state[id] = {
        enabled = enabled == "1",
        active = active == "1",
        label = label or "",
      }
    end
  end
  return state
end

local function HandleMessage(message)
  local command, body = message:match("^([^\t]*)\t?(.*)$")
  if not command or command == "" then
    return
  end

  if command == "STATE" then
    ChallengeSuite.state = ParseState(body)
    Fire("StateUpdated", ChallengeSuite.state)
  elseif command == "SHOW_PANEL" then
    Fire("ShowPanel")
  end
end

-- Requests activation of a challenge; the server messages back success/failure
-- via normal chat (see ChallengeManager::ResolveAndActivateChallenge).
function ChallengeSuite:RequestEnable(id)
  SendAddonMessage(PREFIX, "ENABLE\t" .. id, "WHISPER", UnitName("player"))
end

local helloSent = false

local frame = CreateFrame("Frame")
-- PLAYER_ENTERING_WORLD (not just PLAYER_LOGIN) so a HELLO/STATE resync also
-- happens after /reload -- PLAYER_LOGIN only fires once per actual login, but
-- addon reloads are constant during normal play and testing alike.
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    if not helloSent then
      helloSent = true
      SendAddonMessage(PREFIX, "HELLO", "WHISPER", UnitName("player"))
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message = ...
    if prefix == PREFIX then
      HandleMessage(message)
    end
  end
end)

SLASH_CHALLENGESUITE1 = "/cs"
SlashCmdList["CHALLENGESUITE"] = function()
  Fire("ShowPanel")
end
