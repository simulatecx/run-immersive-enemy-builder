-- core/safety.lua - the "never conflict with the game" firewall (owner
-- directive, 2026-11-04 Forever launch). The launch-day crash log told the
-- story: a packed starter zone runs the client near its MEMORY CEILING
-- (system at 94%) while flooding high-frequency events, and exactly one RUN
-- Lua error fired before the crash. RUN must be structurally incapable of
-- (a) letting an error reach the client, or (b) growing without bound under
-- that load. This file is the single guarded surface every periodic job and
-- client hook routes through:
--   * RUN.safeCall(where, fn, ...) - pcall + record + swallow (never rethrow)
--   * RUN.ticker(name, interval, fn) - periodic work on ONE shared, guarded,
--     throttled OnUpdate frame (no per-file raw tickers that can spam errors)
--   * RUN.Safety.recent()/errorCount - the error ring /ra diag surfaces
-- Pure parts (safeCall, dispatch, the error ring) are headless-tested; only
-- the OnUpdate frame is client-only.

local _, RUN = ...
if not RUN then RUN = _G.RunAdvisor or {}; _G.RunAdvisor = RUN end

local Safety = {}
RUN.Safety = Safety

-- ---------------------------------------------------------------------------
-- Error ring: the last ERR_MAX RUN-side errors, newest last. Bounded by
-- construction so the firewall can never itself become the leak.
-- ---------------------------------------------------------------------------
local ERR_MAX = 20
local errors = {}
Safety.errorCount = 0

function Safety.note(where, err)
    Safety.errorCount = Safety.errorCount + 1
    errors[#errors + 1] = { where = tostring(where), err = tostring(err) }
    while #errors > ERR_MAX do table.remove(errors, 1) end
end

function Safety.recent() return errors end

function Safety.lastError()
    local e = errors[#errors]
    if not e then return nil end
    return e.where .. ": " .. e.err
end

-- safeCall: THE wrapper for every client-side entry point (tickers, hooks).
-- Runs fn(...) under pcall; on error, records it and swallows - the client
-- never sees a RUN error. Returns ok plus up to three results on success.
function RUN.safeCall(where, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        Safety.note(where, a)
        return false
    end
    return true, a, b, c
end

-- ---------------------------------------------------------------------------
-- The shared ticker. Jobs declare an interval; each fires no more often than
-- that, under safeCall, so one throwing or slow job can neither spam the
-- client nor starve the others. Registration is pure (a table append), so it
-- is safe to call from any file and testable headless; only the OnUpdate
-- frame that drives it is client-only.
-- ---------------------------------------------------------------------------
local jobs = {}

function RUN.ticker(name, interval, fn)
    if type(fn) ~= "function" then return end
    jobs[#jobs + 1] = {
        name = tostring(name or "ticker"),
        interval = tonumber(interval) or 1,
        nextAt = 0,
        fn = fn,
    }
end

function Safety.jobs() return jobs end

-- Pure: fire every job whose time has come, advancing its nextAt. `run` is the
-- per-job runner (the live frame passes a safeCall wrapper; tests pass their
-- own). Returns how many fired. Shared by the OnUpdate and the selftest so the
-- throttle logic is covered headless.
function Safety.dispatch(list, now, run)
    if type(list) ~= "table" then return 0 end
    now = tonumber(now) or 0
    local fired = 0
    for i = 1, #list do
        local j = list[i]
        if type(j) == "table" and now >= (tonumber(j.nextAt) or 0) then
            j.nextAt = now + (tonumber(j.interval) or 1)
            fired = fired + 1
            if run then run(j) end
        end
    end
    return fired
end

-- ---------------------------------------------------------------------------
-- Selftests (registered; the firewall must prove it swallows + stays bounded).
-- ---------------------------------------------------------------------------
if type(RUN.selftestChecks) == "table" then
    table.insert(RUN.selftestChecks, function(check)
        local S = RUN.Safety

        check("safeCall passes through results", (function()
            local ok, a, b = RUN.safeCall("t", function() return 7, "x" end)
            return ok == true and a == 7 and b == "x"
        end)())

        check("safeCall swallows a throw + records it", (function()
            local before = S.errorCount
            local ok = RUN.safeCall("boom", function() error("kaboom") end)
            return ok == false and S.errorCount == before + 1
                and tostring(S.lastError()):find("boom", 1, true) ~= nil
        end)())

        check("safeCall rejects a non-function", RUN.safeCall("t", nil) == false)

        check("error ring stays bounded", (function()
            for _ = 1, 50 do RUN.safeCall("flood", function() error("x") end) end
            return #S.recent() <= 20
        end)())

        check("ticker registration is pure + shaped", (function()
            local before = #S.jobs()
            RUN.ticker("selftest-job", 2, function() end)
            local j = S.jobs()[#S.jobs()]
            return #S.jobs() == before + 1 and j.interval == 2 and j.nextAt == 0
        end)())

        check("ticker rejects a non-function", (function()
            local before = #S.jobs()
            RUN.ticker("bad", 1, nil)
            return #S.jobs() == before
        end)())

        check("dispatch fires only due jobs + advances nextAt", (function()
            local list = {
                { name = "a", interval = 1, nextAt = 0 },
                { name = "b", interval = 5, nextAt = 10 },  -- not due at now=0
            }
            local fired = {}
            local n = Safety.dispatch(list, 0, function(j) fired[#fired + 1] = j.name end)
            return n == 1 and fired[1] == "a" and list[1].nextAt == 1
                and list[2].nextAt == 10
        end)())

        check("dispatch re-fires after the interval elapses", (function()
            local list = { { name = "a", interval = 1, nextAt = 0 } }
            Safety.dispatch(list, 0)          -- nextAt -> 1
            local again = Safety.dispatch(list, 0.5)   -- not yet
            local due = Safety.dispatch(list, 1.5)     -- due again
            return again == 0 and due == 1
        end)())

        check("dispatch nil-safe", Safety.dispatch(nil, 0) == 0
            and Safety.dispatch("junk", 0) == 0)
    end)
end

-- Everything below drives the shared ticker; headless harness stops here.
if not _G.CreateFrame then return Safety end

local frame = CreateFrame("Frame", "RUNTicker")
frame:SetScript("OnUpdate", function()
    local now = _G.GetTime and _G.GetTime() or 0
    Safety.dispatch(jobs, now, function(j) RUN.safeCall(j.name, j.fn) end)
end)

return Safety
