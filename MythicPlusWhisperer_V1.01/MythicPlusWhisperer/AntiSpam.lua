-- AntiSpam.lua
-- Simple anti-spam guards for whispers + auto features:
--  - per-target cooldown (don't whisper same player too often)
--  - per-run cap (max whispers per run)
--  - prevents duplicate sending if UI opens twice

MPW = MPW or {}
MPW.AntiSpam = MPW.AntiSpam or {}

-- Defaults (safe, not annoying)
MPW.AntiSpam.DEFAULTS = {
    whisperCooldown = 60 * 20,  -- 20 min per target
    maxWhispersPerRun = 12,     -- cap per run (Msg1+Msg2 count)
    minSecondsBetweenBursts = 3 -- minimum time between two "Send" actions
}

local function EnsureCharConfig()
    MPW_CharConfig = MPW_CharConfig or {}
    MPW_CharConfig.antispam = MPW_CharConfig.antispam or {}
    local a = MPW_CharConfig.antispam
    for k, v in pairs(MPW.AntiSpam.DEFAULTS) do
        if a[k] == nil then a[k] = v end
    end
    return a
end

local function EnsureState()
    MPW_AntiSpamState = MPW_AntiSpamState or {
        lastWhisperAt = {},   -- fullName -> timestamp
        lastBurstAt = 0,
        runKey = "",
        runCount = 0,
    }
    return MPW_AntiSpamState
end

local function RunKey()
    -- Unique-ish key per run context; avoids double-send if window pops twice
    local rt = tostring(MPW.CurrentRunType or "")
    local takenAt = (MPW.PartySnapshot and MPW.PartySnapshot.takenAt) or 0
    return rt .. ":" .. tostring(takenAt)
end

-- Call before sending a queue; returns (ok, reason)
function MPW.AntiSpam.CanStartBurst()
    local cfg = EnsureCharConfig()
    local st = EnsureState()

    local now = MPW.Now()
    if (now - (st.lastBurstAt or 0)) < (cfg.minSecondsBetweenBursts or 0) then
        return false, "Too soon (burst throttle)."
    end

    -- reset per-run counter if run changed
    local rk = RunKey()
    if st.runKey ~= rk then
        st.runKey = rk
        st.runCount = 0
    end

    return true
end

-- Call when a whisper is about to be sent; returns (ok, reason)
function MPW.AntiSpam.CanWhisperTarget(targetFullName)
    local cfg = EnsureCharConfig()
    local st = EnsureState()

    local now = MPW.Now()

    -- per-target cooldown
    local last = st.lastWhisperAt[targetFullName]
    if last and (now - last) < (cfg.whisperCooldown or 0) then
        return false, "Cooldown for " .. tostring(targetFullName)
    end

    -- per-run cap
    if (st.runCount or 0) >= (cfg.maxWhispersPerRun or 0) then
        return false, "Run cap reached."
    end

    return true
end

-- Call after a whisper is sent
function MPW.AntiSpam.MarkWhisper(targetFullName)
    local cfg = EnsureCharConfig()
    local st = EnsureState()

    st.lastWhisperAt[targetFullName] = MPW.Now()
    st.runCount = (st.runCount or 0) + 1
end

-- Call when a burst starts
function MPW.AntiSpam.MarkBurstStart()
    local st = EnsureState()
    st.lastBurstAt = MPW.Now()

    -- ensure run key is current
    local rk = RunKey()
    if st.runKey ~= rk then
        st.runKey = rk
        st.runCount = 0
    end
end

-- Utility: for debug
function MPW.AntiSpam.GetRunCount()
    local st = EnsureState()
    return st.runCount or 0
end
