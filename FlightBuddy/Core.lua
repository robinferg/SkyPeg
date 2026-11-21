-- Flight Buddy :: Core.lua
-- Saved data, flight-path detection, slash commands.
local ADDON, NS = ...
local floor = math.floor

local DEFAULTS = {
    settings = {
        onFlight = "auto",      -- "auto" | "ask" | "off"
        closeOnLand = true,
        share = true,
        space = true,
        sound = true,
        reducedMotion = false,
        symbols = true,
        realmBoards = true,     -- share and receive scores on the hidden realm channel
        -- scale = nil means "fit my screen"
    },
    stats = { flights = 0 },
    flightTimes = {},
    peg = { best = 0, stats = { shots = 0, levels = 0, bestShot = 0 }, seenHelp = false },
    putt = {},
    flap = {},
    pin = {},
    gem = {},
    orbs = {},
    pool = {},
    boards = {},
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function NS.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9e2eFlight Buddy|r: " .. tostring(msg))
end

local function Setup()
    if type(FlightBuddyDB) ~= "table" then FlightBuddyDB = {} end
    local db = FlightBuddyDB
    Merge(db, DEFAULTS)
    NS.db = db
    -- games read shared settings through their own sub-table (never saved twice)
    for _, k in ipairs({ "peg", "putt", "flap", "pin", "gem", "orbs", "pool" }) do
        setmetatable(db[k], { __index = function(_, key) if key == "settings" then return db.settings end end })
    end
    NS.Social:Init(db)
    if NS.Versus then NS.Versus:Init(db.putt or db) end
    if NS.DeathRoll then NS.DeathRoll:Init(db); NS.DeathRollUI:Init(db.dr) end
    NS.Peg:Init(db.peg)
    NS.PuttUI:Init(db.putt)
    NS.FlapUI:Init(db.flap)
    NS.PinballUI:Init(db.pin)
    NS.GemsUI:Init(db.gem)
    NS.OrbsUI:Init(db.orbs)
    NS.PoolUI:Init(db.pool)
    NS.Shell:Init(db)
end

---------------------------------------------------------------------------
-- Flight tracking
---------------------------------------------------------------------------
local onTaxi, flightStart, pollAcc = false, nil, 0
local function InCombat() return InCombatLockdown and InCombatLockdown() end

---------------------------------------------------------------------------
-- Time to destination. WoW doesn't say how long a flight takes, so we note
-- the route when you pick it at the flight master, time every flight, and
-- count down from the learned time. Unknown routes are estimated from the
-- straight-line distance and your average pace, shown with a "~".
---------------------------------------------------------------------------
local pendingRoute -- { key, dist, at }
local DEFAULT_PACE = 1000 -- seconds per unit of taxi-map distance (refined as you fly)

local function RouteFromIndex(i)
    if not (TaxiNodeName and NumTaxiNodes) then return nil end
    local to = TaxiNodeName(i)
    local fromName, fx, fy
    for k = 1, NumTaxiNodes() do
        if TaxiNodeGetType and TaxiNodeGetType(k) == "CURRENT" then
            fromName = TaxiNodeName(k)
            if TaxiNodePosition then fx, fy = TaxiNodePosition(k) end
        end
    end
    if not (to and fromName) then return nil end
    local dist
    if fx and TaxiNodePosition then
        local tx, ty = TaxiNodePosition(i)
        if tx then dist = math.sqrt((tx - fx) ^ 2 + (ty - fy) ^ 2) end
    end
    return { key = fromName .. " > " .. to, dist = dist, at = GetTime(), from = fromName, to = to,
             zone = GetRealZoneText and GetRealZoneText() or nil }
end
if hooksecurefunc and TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function(i)
        local ok, r = pcall(RouteFromIndex, i)
        if ok then pendingRoute = r end
    end)
end

local function Estimate(route)
    local db = NS.db
    local known = db.flightTimes[route.key]
    if known then return known, false end
    if route.dist and route.dist > 0 then return route.dist * (db.flightPace or DEFAULT_PACE), true end
end

local function OnFlightStart()
    local db = NS.db
    flightStart = GetTime()
    db.flight = nil
    if pendingRoute and GetTime() - pendingRoute.at < 20 then
        local est, guess = Estimate(pendingRoute)
        db.flight = { key = pendingRoute.key, dist = pendingRoute.dist, start = flightStart, est = est, guess = guess,
                      from = pendingRoute.from, to = pendingRoute.to, zone = pendingRoute.zone }
        db.lastFlight = { from = pendingRoute.from, to = pendingRoute.to, dist = pendingRoute.dist, zone = pendingRoute.zone }
        if NS.Route then pcall(function() NS.Route.Note(NS.Route.Spec(db.lastFlight), true) end) end
    end
    pendingRoute = nil
    db.stats.flights = (db.stats.flights or 0) + 1
    if InCombat() then return end
    local mode = db.settings.onFlight
    if mode == "auto" then
        if not NS.Shell:IsShown() then NS.Shell:Open("flight") end
    elseif mode == "ask" then
        if not NS.Shell:IsShown() then NS.Shell:ShowToast() end
    end
end

local function OnLanded()
    local db = NS.db
    local fl = db.flight
    if fl and flightStart then
        local dur = GetTime() - fl.start
        -- learn only from flights that ran their course (not cut short or wildly off)
        if dur > 8 and (not fl.est or fl.guess or math.abs(dur - fl.est) < fl.est * 0.5) then
            local old = db.flightTimes[fl.key]
            db.flightTimes[fl.key] = old and (old * 0.5 + dur * 0.5) or dur
            if fl.dist and fl.dist > 0.01 then
                local pace = dur / fl.dist
                db.flightPace = db.flightPace and (db.flightPace * 0.7 + pace * 0.3) or pace
            end
        end
    end
    db.flight = nil
    flightStart = nil
    NS.Shell:SetStatus("Grounded")
    NS.Shell:OnLanded()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("CHAT_MSG_ADDON")

ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "ADDON_LOADED" and a1 == ADDON then
        Setup()
        if NS.db and not NS.db.artcheck and C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(NS.RunArtCheck) end) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- a loading screen mid-flight is not a fresh take-off
        onTaxi = UnitOnTaxi("player") and true or false
        if onTaxi and not flightStart then
            -- after a /reload mid-flight, pick the countdown back up
            local fl = NS.db and NS.db.flight
            flightStart = (fl and GetTime() - fl.start < 3600 and fl.start) or GetTime()
        end
        if NS.db and NS.db.settings.share then
            if C_Timer and C_Timer.After then
                C_Timer.After(8, function()
                    NS.Social:Query("putt", NS.Social.Today())
                end)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        -- last chance to write things down. Each game is asked on its own, so one that trips
        -- cannot stop the others from saving.
        if NS.db and NS.Shell.frame then
            local open = NS.Shell:IsShown()
            for _, m in pairs(NS.Shell.mods) do
                if m.frame then
                    if open and m.OnHide then pcall(m.OnHide, m) end
                    if m.OnLogout then pcall(m.OnLogout, m) end
                end
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if NS.db then
            NS.Shell:HideToast()
            if NS.Shell:IsShown() then
                NS.Shell:Close()
                NS.Print("Closed for combat - your games are saved.")
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        if NS.db then
            NS.Social.Hear(a3, a4, a1, a2)
            NS.Social:OnMessage(a1, a2, a3, a4)
            if NS.Versus then NS.Versus:OnMessage(a1, a2, a3, a4) end
            if NS.DeathRoll then NS.DeathRoll:OnMessage(a1, a2, a3, a4) end
        end
    end
end)

ev:SetScript("OnUpdate", function(_, el)
    if not NS.db then return end
    NS.Social:Pump(el)
    if NS.Versus then NS.Versus:Pump(el) end
    if NS.DeathRoll then NS.DeathRoll:Pump(el) end
    pollAcc = pollAcc + el
    if pollAcc < 0.25 then return end
    pollAcc = 0
    local now = UnitOnTaxi("player") and true or false
    if now and not onTaxi then
        onTaxi = true
        OnFlightStart()
    elseif onTaxi and not now then
        onTaxi = false
        OnLanded()
    end
    if onTaxi and flightStart then
        local fl = NS.db.flight
        if fl and fl.est then
            local left = fl.est - (GetTime() - flightStart)
            if left > 0 then
                left = math.ceil(left)
                NS.Shell:SetStatus(("Time to destination  %s%d:%02d"):format(fl.guess and "~" or "", floor(left / 60), left % 60), true)
            else
                NS.Shell:SetStatus("Arriving...", true)
            end
        else
            NS.Shell:SetStatus("Time to destination  --:--", true)
        end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Help()
    NS.Print("commands:")
    print("  |cffffcc40/fb|r  open or close Flight Buddy")
    print("  |cffffcc40/fb peg|r, |cffffcc40/fb putt|r, |cffffcc40/fb gem|r, |cffffcc40/fb orbs|r, |cffffcc40/fb pool|r, |cffffcc40/fb roll|r, |cffffcc40/fb flap|r, |cffffcc40/fb pin|r  jump to a game")
    print("  |cffffcc40/fb options|r  settings (auto-open on flights, sharing, sound, size...)")
    print("  |cffffcc40/fb test|r  preview the take-off prompt")
    print("  |cffffcc40/fb resetpos|r  move the window back to the middle")
end

local TAB_ALIASES = { peg = "peg", skypeg = "peg", peggle = "peg",
    putt = "putt", golf = "putt", greens = "putt",
    flap = "flap", featherbeard = "flap", gryphon = "flap", fly = "flap",
    pin = "pin", pinball = "pin", tinker = "pin", hightinker = "pin",
    roll = "roll", deathroll = "roll", dice = "roll",
    gem = "gem", gems = "gem", jewel = "gem", jewelcrafter = "gem", match = "gem",
    orbs = "orbs", orb = "orbs", cannon = "orbs", bubble = "orbs", bubbles = "orbs",
    pool = "pool", billiards = "pool", eightball = "pool", ["8ball"] = "pool",
    home = "home", tavern = "home" }

local function Slash(msg, forceTab)
    if not NS.db then return end
    if not forceTab and NS.Versus and NS.Versus:Slash(msg or "") then return end
    msg = ((msg or ""):lower()):match("^%s*(.-)%s*$")
    local Shell = NS.Shell
    local tab = forceTab or TAB_ALIASES[msg]
    if tab then
        if Shell:IsShown() and Shell.tab == tab and not forceTab then Shell:Close() else Shell:Open(nil, tab) end
    elseif msg == "" or msg == "show" or msg == "toggle" then
        Shell:Toggle()
    elseif msg == "options" or msg == "config" or msg == "settings" then
        if not Shell:IsShown() then Shell:Open() end
        if not Shell.options:IsShown() then Shell:ToggleOptions() end
    elseif msg == "test" then
        Shell:ShowToast()
    elseif msg == "artcheck" then
        NS.RunArtCheck()
    elseif msg == "resetpos" then
        NS.db.pos = nil
        if Shell.frame then
            Shell.frame:ClearAllPoints()
            Shell.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    else
        Help()
    end
end

SLASH_FLIGHTBUDDY1 = "/fb"
SLASH_FLIGHTBUDDY2 = "/flightbuddy"
SlashCmdList.FLIGHTBUDDY = function(msg) Slash(msg) end
SLASH_FLIGHTBUDDYPEG1 = "/rune"
SLASH_FLIGHTBUDDYPEG2 = "/peg"
SlashCmdList.FLIGHTBUDDYPEG = function(msg)
    if msg and msg ~= "" then Slash(msg) else Slash("", "peg") end
end
SLASH_FLIGHTBUDDYDR1 = "/deathroll"
SLASH_FLIGHTBUDDYDR2 = "/droll"
SlashCmdList.FLIGHTBUDDYDR = function(msg) if NS.db and NS.DeathRoll then NS.DeathRoll:Slash(msg) end end
SLASH_FLIGHTBUDDYPUTT1 = "/putt"
SlashCmdList.FLIGHTBUDDYPUTT = function() Slash("", "putt") end
SLASH_FLIGHTBUDDYFLAP1 = "/featherbeard"
SlashCmdList.FLIGHTBUDDYFLAP = function() Slash("", "flap") end
SLASH_FLIGHTBUDDYPIN1 = "/pinball"
SLASH_FLIGHTBUDDYPIN2 = "/hightinker"
SlashCmdList.FLIGHTBUDDYPIN = function() Slash("", "pin") end

function FlightBuddy_OnAddonCompartmentClick()
    if NS.db then NS.Shell:Toggle() end
end

---------------------------------------------------------------------------
-- One-time art survey: which of Blizzard's painted textures does this client
-- have? Results land in FlightBuddyDB.artcheck (read after a /reload).
---------------------------------------------------------------------------
local ART_CANDIDATES = {
{131817,"interface\\glues\\loadingscreens\\dynamicelements"},
{131818,"interface\\glues\\loadingscreens\\loadscreenahnqiraj20man"},
{131819,"interface\\glues\\loadingscreens\\loadscreenahnqiraj40man"},
{131820,"interface\\glues\\loadingscreens\\loadscreenarathibasin"},
{131821,"interface\\glues\\loadingscreens\\loadscreenauchindoun"},
{131822,"interface\\glues\\loadingscreens\\loadscreenazjoluppercity"},
{131823,"interface\\glues\\loadingscreens\\loadscreenblackfathomdeeps"},
{131824,"interface\\glues\\loadingscreens\\loadscreenblackrockdepths"},
{131825,"interface\\glues\\loadingscreens\\loadscreenblackrockspire"},
{131826,"interface\\glues\\loadingscreens\\loadscreenblacktemple"},
{131827,"interface\\glues\\loadingscreens\\loadscreenblackwinglair"},
{131828,"interface\\glues\\loadingscreens\\loadscreenbladesedgearena"},
{131829,"interface\\glues\\loadingscreens\\loadscreencave"},
{131830,"interface\\glues\\loadingscreens\\loadscreencavernstime"},
{131831,"interface\\glues\\loadingscreens\\loadscreenchampionshall"},
{131832,"interface\\glues\\loadingscreens\\loadscreencoilfang"},
{131833,"interface\\glues\\loadingscreens\\loadscreendeadmines"},
{131834,"interface\\glues\\loadingscreens\\loadscreendeepruntram"},
{131835,"interface\\glues\\loadingscreens\\loadscreendiremaul"},
{131836,"interface\\glues\\loadingscreens\\loadscreendraktharon"},
{131837,"interface\\glues\\loadingscreens\\loadscreendraktheron"},
{131838,"interface\\glues\\loadingscreens\\loadscreendungeon"},
{131839,"interface\\glues\\loadingscreens\\loadscreeneasternkingdom"},
{131840,"interface\\glues\\loadingscreens\\loadscreenenviroment"},
{131841,"interface\\glues\\loadingscreens\\loadscreengnomeregan"},
{131842,"interface\\glues\\loadingscreens\\loadscreengruulslair"},
{131843,"interface\\glues\\loadingscreens\\loadscreenhalloflegends"},
{131844,"interface\\glues\\loadingscreens\\loadscreenhellfirecitadel"},
{131845,"interface\\glues\\loadingscreens\\loadscreenhellfirecitadel5man"},
{131846,"interface\\glues\\loadingscreens\\loadscreenhellfirecitadelraid"},
{131847,"interface\\glues\\loadingscreens\\loadscreenhyjal"},
{131848,"interface\\glues\\loadingscreens\\loadscreenkalimdor"},
{131849,"interface\\glues\\loadingscreens\\loadscreenkarazhan"},
{131850,"interface\\glues\\loadingscreens\\loadscreenmaraudon"},
{131851,"interface\\glues\\loadingscreens\\loadscreenmoltencore"},
{131852,"interface\\glues\\loadingscreens\\loadscreenmonastery"},
{131853,"interface\\glues\\loadingscreens\\loadscreennagrandarenabattlegrounds"},
{131854,"interface\\glues\\loadingscreens\\loadscreennaxxramas"},
{131855,"interface\\glues\\loadingscreens\\loadscreennetherbattlegrounds"},
{131856,"interface\\glues\\loadingscreens\\loadscreennexus70"},
{131857,"interface\\glues\\loadingscreens\\loadscreennexus80"},
{131858,"interface\\glues\\loadingscreens\\loadscreennorthrend"},
{131859,"interface\\glues\\loadingscreens\\loadscreenoldstrathome"},
{131860,"interface\\glues\\loadingscreens\\loadscreenoutland"},
{131861,"interface\\glues\\loadingscreens\\loadscreenpvpbattleground"},
{131862,"interface\\glues\\loadingscreens\\loadscreenragefirechasm"},
{131863,"interface\\glues\\loadingscreens\\loadscreenraid"},
{131864,"interface\\glues\\loadingscreens\\loadscreenrazorfendowns"},
{131865,"interface\\glues\\loadingscreens\\loadscreenrazorfenkraul"},
{131866,"interface\\glues\\loadingscreens\\loadscreenruinedcity"},
{131867,"interface\\glues\\loadingscreens\\loadscreenruinsoflordaeronbattlegrounds"},
{131868,"interface\\glues\\loadingscreens\\loadscreenscholomance"},
{131869,"interface\\glues\\loadingscreens\\loadscreenshadowfangkeep"},
{131870,"interface\\glues\\loadingscreens\\loadscreenstormwindstockade"},
{131871,"interface\\glues\\loadingscreens\\loadscreenstrathome"},
{131872,"interface\\glues\\loadingscreens\\loadscreensunkentemple"},
{131873,"interface\\glues\\loadingscreens\\loadscreensunwell"},
{131874,"interface\\glues\\loadingscreens\\loadscreensunwell5man"},
{131875,"interface\\glues\\loadingscreens\\loadscreentempestkeep"},
{131876,"interface\\glues\\loadingscreens\\loadscreenuldaman"},
{131877,"interface\\glues\\loadingscreens\\loadscreenulduar77"},
{131878,"interface\\glues\\loadingscreens\\loadscreenulduar80"},
{131879,"interface\\glues\\loadingscreens\\loadscreenulduarraid"},
{131880,"interface\\glues\\loadingscreens\\loadscreenutgarde"},
{131881,"interface\\glues\\loadingscreens\\loadscreenutgardepinnecle"},
{131882,"interface\\glues\\loadingscreens\\loadscreenwailingcaverns"},
{131883,"interface\\glues\\loadingscreens\\loadscreenwarsonggulch"},
{131884,"interface\\glues\\loadingscreens\\loadscreenzulaman"},
{131885,"interface\\glues\\loadingscreens\\loadscreenzulfarrak"},
{131886,"interface\\glues\\loadingscreens\\loadscreenzulgurub"},
{236056,"interface\\glues\\loadingscreens\\loadscreenazjolnerub76"},
{236057,"interface\\glues\\loadingscreens\\loadscreenchamberblack"},
{236058,"interface\\glues\\loadingscreens\\loadscreendalaranprison"},
{236059,"interface\\glues\\loadingscreens\\loadscreendalaransewersarena"},
{236060,"interface\\glues\\loadingscreens\\loadscreendeathknight"},
{236061,"interface\\glues\\loadingscreens\\loadscreengundrak"},
{236062,"interface\\glues\\loadingscreens\\loadscreenmalygos"},
{236063,"interface\\glues\\loadingscreens\\loadscreennorthrendbg"},
{236064,"interface\\glues\\loadingscreens\\loadscreenorgrimmararena"},
{236065,"interface\\glues\\loadingscreens\\loadscreenwintergrasp"},
{309885,"interface\\glues\\loadingscreens\\loadscreenisleofconquest"},
{310729,"interface\\glues\\loadingscreens\\loadscreenargentraid"},
{311102,"interface\\glues\\loadingscreens\\loadscreenargentdungeon"},
{317257,"interface\\glues\\loadingscreens\\loadscreenicecrown5man"},
{318964,"interface\\glues\\loadingscreens\\loadscreenicecrowncitadel"},
{320915,"interface\\glues\\loadingscreens\\loadscreenblizzcon09"},
{335909,"interface\\glues\\loadingscreens\\loadscreenpitofsaron"},
{336388,"interface\\glues\\loadingscreens\\loadscreenhallsofreflection"},
{343001,"interface\\glues\\loadingscreens\\loadscreeneasternkingdomwide"},
{343002,"interface\\glues\\loadingscreens\\loadscreenkalimdorwide"},
{343003,"interface\\glues\\loadingscreens\\loadscreennorthrendwide"},
{343004,"interface\\glues\\loadingscreens\\loadscreenoutlandwide"},
{365622,"interface\\glues\\loadingscreens\\loadscreenrubysanctum"},
{397151,"interface\\glues\\loadingscreens\\loadscreenthroneofthetides"},
{400719,"interface\\glues\\loadingscreens\\loadscreenhallsoforigination"},
{401942,"interface\\glues\\loadingscreens\\loadscreendeepholmdungeon"},
{401943,"interface\\glues\\loadingscreens\\loadscreengrimbatol"},
{402550,"interface\\glues\\loadingscreens\\loadscreenskywall"},
{404445,"interface\\glues\\loadingscreens\\loadscreenblackwingdescentraid"},
{405445,"interface\\glues\\loadingscreens\\loadscreengilneasbg"},
{407226,"interface\\glues\\loadingscreens\\loadscreentwinpeaksbg"},
{407545,"interface\\glues\\loadingscreens\\loadscreengrimbatolraid"},
{411683,"interface\\glues\\loadingscreens\\loadscreentolbarad"},
{411684,"interface\\glues\\loadingscreens\\loadscreenuldumdungeon"},
{418218,"interface\\glues\\loadingscreens\\loadscreenblackrockcaverns"},
{424078,"interface\\glues\\loadingscreens\\loadscreendeepholm"},
{427941,"interface\\glues\\loadingscreens\\loadscreengilneasbg2"},
{445506,"interface\\glues\\loadingscreens\\loadscreeneasternkingdom2"},
{445508,"interface\\glues\\loadingscreens\\loadscreenkalimdor2"},
{445510,"interface\\glues\\loadingscreens\\loadscreennorthrend2"},
{445512,"interface\\glues\\loadingscreens\\loadscreenoutland2"},
{447132,"interface\\glues\\loadingscreens\\loadscreeneasternkingdom2wide"},
{447133,"interface\\glues\\loadingscreens\\loadscreenkalimdor2wide"},
{447134,"interface\\glues\\loadingscreens\\loadscreennorthrend2wide"},
{447135,"interface\\glues\\loadingscreens\\loadscreenoutland2wide"},
{450109,"interface\\glues\\loadingscreens\\loadscreenskywallraid"},
{468402,"interface\\glues\\loadingscreens\\loadscreenbaradinhold"},
{512032,"interface\\glues\\loadingscreens\\loadscreenmaelstrom"},
{514085,"interface\\glues\\loadingscreens\\loadscreenfirelands"},
{514270,"interface\\glues\\loadingscreens\\loadscreenfirelandsraid"},
{514758,"interface\\glues\\loadingscreens\\loadscreenzulaman2"},
{534166,"interface\\glues\\loadingscreens\\loadscreendarkmoonisland"},
{534812,"interface\\glues\\loadingscreens\\loadscreendeathwingraid"},
{535280,"interface\\glues\\loadingscreens\\loadscreenendtime"},
{535281,"interface\\glues\\loadingscreens\\loadscreenwellofeternity"},
{535413,"interface\\glues\\loadingscreens\\loadscreenhouroftwilight"},
{574578,"interface\\glues\\loadingscreens\\loadscreenwanderingisle"},
{613546,"interface\\glues\\loadingscreens\\loadscreenjadeforest"},
{633147,"interface\\glues\\loadingscreens\\loadscreengateofthesettingsun"},
{633148,"interface\\glues\\loadingscreens\\loadscreenheartoffear"},
{633149,"interface\\glues\\loadingscreens\\loadscreenjadetemple"},
{633150,"interface\\glues\\loadingscreens\\loadscreenmogushanpalace"},
{633151,"interface\\glues\\loadingscreens\\loadscreenmogushanvaults"},
{633152,"interface\\glues\\loadingscreens\\loadscreenscholomance2"},
{633153,"interface\\glues\\loadingscreens\\loadscreenshadowpanmonastery"},
{633154,"interface\\glues\\loadingscreens\\loadscreensiegeofnizaotemple"},
{633155,"interface\\glues\\loadingscreens\\loadscreensilvershardmines"},
{633156,"interface\\glues\\loadingscreens\\loadscreenstormstoutbrewery"},
{633157,"interface\\glues\\loadingscreens\\loadscreentolvirarena"},
{633158,"interface\\glues\\loadingscreens\\loadscreenvalleyofpower"},
{643908,"interface\\glues\\loadingscreens\\loadscreenscarlethalls"},
{643909,"interface\\glues\\loadingscreens\\loadscreenterraceofendlesssprings"},
{645156,"interface\\glues\\loadingscreens\\loadscreenscarletmonastery2"},
{647838,"interface\\glues\\loadingscreens\\loadscreenabrewingstorm"},
{647839,"interface\\glues\\loadingscreens\\loadscreenungaingoo"},
{650621,"interface\\glues\\loadingscreens\\loadscreentheramorehorde"},
{650622,"interface\\glues\\loadingscreens\\loadscreenworld"},
{651272,"interface\\glues\\loadingscreens\\loadscreenvalleyofthefourwindsmap"},
{651536,"interface\\glues\\loadingscreens\\loadscreentheramorealliance"},
{651944,"interface\\glues\\loadingscreens\\loadscreenpandaria"},
{651994,"interface\\glues\\loadingscreens\\loadscreenpandariawide"},
{652547,"interface\\glues\\loadingscreens\\loadscreenbrewmoonfestival"},
{652548,"interface\\glues\\loadingscreens\\loadscreencryptofforgottenkings"},
{652549,"interface\\glues\\loadingscreens\\loadscreengreenstonevillage"},
{654139,"interface\\glues\\loadingscreens\\loadscreenassaultonzanvess"},
{656110,"interface\\glues\\loadingscreens\\loadscreentempleofkotmogu"},
{769191,"interface\\glues\\loadingscreens\\loadscreenpvpbattlegrounds"},
{774864,"interface\\glues\\loadingscreens\\loadscreendominationpoint"},
{774865,"interface\\glues\\loadingscreens\\loadscreenlionslanding"},
{774866,"interface\\glues\\loadingscreens\\loadscreenvoljinscenario"},
{775185,"interface\\glues\\loadingscreens\\loadscreenbrawlgararena"},
{775426,"interface\\glues\\loadingscreens\\loadscreenalittlepatience"},
{775634,"interface\\glues\\loadingscreens\\loadscreentyrivess"},
{795305,"interface\\glues\\loadingscreens\\loadscreenkotmoguscenario"},
{801471,"interface\\glues\\loadingscreens\\loadscreenthunderkingraid"},
{804100,"interface\\glues\\loadingscreens\\loadscreenthunderisle"},
{841556,"interface\\glues\\loadingscreens\\loadscreenprovinggrounds"},
{851882,"interface\\glues\\loadingscreens\\loadingscreen_shadowpan_bg"},
{852903,"interface\\glues\\loadingscreens\\loadscreenemberdeepscenario"},
{852904,"interface\\glues\\loadingscreens\\loadscreennavalbattlescenario"},
{853210,"interface\\glues\\loadingscreens\\loadscreenbloodsnowscenario"},
{874615,"interface\\glues\\loadingscreens\\loadscreenheartofdarkness"},
{875627,"interface\\glues\\loadingscreens\\loadscreen_goldrush"},
{903869,"interface\\glues\\loadingscreens\\loadscreensiegeoforgrimmar"},
{937565,"interface\\glues\\loadingscreens\\loadscreenblizzcon2013"},
{937566,"interface\\glues\\loadingscreens\\loadscreenblizzcon2013wide"},
{1013075,"interface\\glues\\loadingscreens\\loadscreenogrecompound"},
{1017727,"interface\\glues\\loadingscreens\\loadscreenblackrocktraindepot"},
{1032622,"interface\\glues\\loadingscreens\\loadingscreen_blackrockfoundry"},
{1032623,"interface\\glues\\loadingscreens\\loadscreenblackrockfoundry"},
{1033059,"interface\\glues\\loadingscreens\\loadingscreen_shadowmoonburialgrounds"},
{1033498,"interface\\glues\\loadingscreens\\loadingscreen_highmaulraid"},
{1033900,"interface\\glues\\loadingscreens\\loadscreen_skyreach"},
{1033901,"interface\\glues\\loadingscreens\\loadscreenskyreach"},
{1034725,"interface\\glues\\loadingscreens\\loadscreenauchindoun_wod"},
{1035008,"interface\\glues\\loadingscreens\\loadscreendraenor"},
{1035009,"interface\\glues\\loadingscreens\\loadscreendraenorwide"},
{1035010,"interface\\glues\\loadingscreens\\loadscreeneasternkingdoms3"},
{1035011,"interface\\glues\\loadingscreens\\loadscreeneasternkingdoms3wide"},
{1035012,"interface\\glues\\loadingscreens\\loadscreenkalimdor3"},
{1035013,"interface\\glues\\loadingscreens\\loadscreenkalimdor3wide"},
{1035275,"interface\\glues\\loadingscreens\\loadscreenupperblackrockspire"},
{1040025,"interface\\glues\\loadingscreens\\inv_bullroarer"},
{1058989,"interface\\glues\\loadingscreens\\loadingscreen_irondocks_cn"},
{1058990,"interface\\glues\\loadingscreens\\loadingscreen_irondocks_tw"},
{1058991,"interface\\glues\\loadingscreens\\loadingscreen_irondocks"},
{1060205,"interface\\glues\\loadingscreens\\loadscreen_everbloom"},
{1086951,"interface\\glues\\loadingscreens\\loadingscreen_hordegarrison"},
{1089530,"interface\\glues\\loadingscreens\\loadscreen_blackrockfoundry"},
{1099378,"interface\\glues\\loadingscreens\\loadscreen_alliancegarrison"},
{1132136,"interface\\glues\\loadingscreens\\loadscreen_hellfireraid"},
{1272375,"interface\\glues\\loadingscreens\\loadingscreen_lighthopeschapel"},
{1272474,"interface\\glues\\loadingscreens\\loadscreenbrokenisles"},
{1303233,"interface\\glues\\loadingscreens\\loadingscreen_mardum"},
{1303234,"interface\\glues\\loadingscreens\\loadingscreen_mardumwide"},
{1375895,"interface\\glues\\loadingscreens\\loadscreen_monkorderhall_wide"},
{1375896,"interface\\glues\\loadingscreens\\loadscreen_monkorderhall_wide_nologo"},
{1379024,"interface\\glues\\loadingscreens\\loadscreen_hunterorderhall_wide"},
{1382383,"interface\\glues\\loadingscreens\\loadscreen_deathknightorderhall_wide"},
{1389211,"interface\\glues\\loadingscreens\\loadingscreen_demonhunterorderhall_wide"},
{1389212,"interface\\glues\\loadingscreens\\loadingscreen_nightmaredungeon_wide"},
{1389214,"interface\\glues\\loadingscreens\\loadingscreen_demonhunterartifact_wide"},
{1389449,"interface\\glues\\loadingscreens\\loadingscreen_vaultofthewardens_wide"},
{1391080,"interface\\glues\\loadingscreens\\loadingscreen_helheimship_wide"},
{1394867,"interface\\glues\\loadingscreens\\loadscreen_emeraldnightmareraid_wide"},
{1394926,"interface\\glues\\loadingscreens\\loadscreen_warlockorderhall_wide"},
{1395043,"interface\\glues\\loadingscreens\\loadingscreen_niskara_wide"},
{1395129,"interface\\glues\\loadingscreens\\loadscreen_suramarcatacombs_wide"},
{1399464,"interface\\glues\\loadingscreens\\loadingscreen_blackrookhold_wide"},
{1405662,"interface\\glues\\loadingscreens\\loadingscreen_shamanartifact_wide"},
{1412500,"interface\\glues\\loadingscreens\\loadscreen_priestorderhall_wide"},
{1414064,"interface\\glues\\loadingscreens\\loadingscreen_deathknightorderhall_wide"},
{1417745,"interface\\glues\\loadingscreens\\loadingscreen_druidorderhall_wide"},
{1445178,"interface\\glues\\loadingscreens\\loadingscreen_neltharionslair_wide"},
{1445353,"interface\\glues\\loadingscreens\\loadscreen_mageartifact"},
{1446595,"interface\\glues\\loadingscreens\\loadingscreen_brokenisles_wide"},
{1448532,"interface\\glues\\loadingscreens\\loadscreen_suramarraid"},
{1451468,"interface\\glues\\loadingscreens\\loadingscreen_blackrookholdarena_wide"},
{1454533,"interface\\glues\\loadingscreens\\loadingscreen_lighthopeschapel_wide"},
{1454826,"interface\\glues\\loadingscreens\\loadingscreen_hallsofvalor_wide"},
{1467575,"interface\\glues\\loadingscreens\\loadscreen_nagadungeon"},
{1472862,"interface\\glues\\loadingscreens\\loadingscreen_arenavalsharah_wide"},
{1476725,"interface\\glues\\loadingscreens\\loadingscreen_emeralddreamway_wide"},
{1477131,"interface\\glues\\loadingscreens\\loadscreen_suramarcitydungeon"},
{1496467,"interface\\glues\\loadingscreens\\loadingscreen_violethold_wide"},
{1498772,"interface\\glues\\loadingscreens\\loadscreeneasternkingdoms4"},
{1498773,"interface\\glues\\loadingscreens\\loadscreeneasternkingdoms4wide"},
{1498774,"interface\\glues\\loadingscreens\\loadscreenkalimdor4"},
{1498775,"interface\\glues\\loadingscreens\\loadscreenkalimdor4wide"},
{1536931,"interface\\glues\\loadingscreens\\loadingscreen_nagrandarena_wide"},
{1537272,"interface\\glues\\loadingscreens\\loadingscreen_returntokarazhan"},
{1537273,"interface\\glues\\loadingscreens\\loadingscreen_trialsofvalor"},
{1568178,"interface\\glues\\loadingscreens\\loadingscreen_bladesedgearena_wide"},
{1608213,"interface\\glues\\loadingscreens\\loadingscreen_arathibasin"},
{1608214,"interface\\glues\\loadingscreens\\loadingscreen_arathibasinwinter"},
{1615560,"interface\\glues\\loadingscreens\\loadscreen_tombofsargerasraid_wide"},
{1616802,"interface\\glues\\loadingscreens\\loadscreen_tombofsargerasdungeon_wide"},
{1672553,"interface\\glues\\loadingscreens\\loadscreen_chromiescenario_wide"},
{1717118,"interface\\glues\\loadingscreens\\loadingscreen_argus3"},
{1717768,"interface\\glues\\loadingscreens\\loadingscreen_argusdungeon_widescreen"},
{1717773,"interface\\glues\\loadingscreens\\loadingscreen_argusraid_widescreen"},
{1719332,"interface\\glues\\loadingscreens\\loadingscreen_krokuun_wide"},
{1719502,"interface\\glues\\loadingscreens\\loadingscreen_macaree_wide"},
{1780110,"interface\\glues\\loadingscreens\\loadingscreen_8xp_forlornvictory_wide"},
{1864572,"interface\\glues\\loadingscreens\\loadingscreen_seethingshore"},
{1865666,"interface\\glues\\loadingscreens\\loadingscreen_azeritebg_wide"},
{1968998,"interface\\glues\\loadingscreens\\loadingscreen_goldencityexterior_wide_battleforazeroth"},
{1969119,"interface\\glues\\loadingscreens\\loadscreen_toldagor_wide"},
{1984118,"interface\\glues\\loadingscreens\\loadscreen_waycrestmanor_wide"},
{2000399,"interface\\glues\\loadingscreens\\loadingscreen_goldencityinterior_wide_battleforazeroth"},
{2016712,"interface\\glues\\loadingscreens\\loadingscreen_goblinmine_masterwidescreen_battleforazeroth"},
{2033044,"interface\\glues\\loadingscreens\\loadingscreen_alliancepvparena_masterwidescreen_battleforazeroth"},
{2061464,"interface\\glues\\loadingscreens\\loadingscreen_serpentinetunnels_wide"},
{2068775,"interface\\glues\\loadingscreens\\loadscreen_boralusdungeon"},
{2103695,"interface\\glues\\loadingscreens\\loadingscreen_zuldazararena"},
{2103696,"interface\\glues\\loadingscreens\\loadingscreen_arathiwarfronts_masterwidescreen_battleforazeroth"},
{2103733,"interface\\glues\\loadingscreens\\loadingscreen_masterwidescreen_shrineofthestorm_wide"},
{2125650,"interface\\glues\\loadingscreens\\loadscreen_freeholddungeon"},
{2126830,"interface\\glues\\loadingscreens\\loadingscreen_nazmirraid"},
{2139069,"interface\\glues\\loadingscreens\\loadscreen_islandexpeditions"},
{2142255,"interface\\glues\\loadingscreens\\loadscreen_kultiras-tiragarde_wide"},
{2143605,"interface\\glues\\loadingscreens\\loadingscreen_kultiras"},
{2143606,"interface\\glues\\loadingscreens\\loadingscreen_zandalar"},
{2175832,"interface\\glues\\loadingscreens\\loadingscreen_underrot_wide"},
{2494959,"interface\\glues\\loadingscreens\\loadingscreen_seapriestraid_wide_battleforazeroth"},
{2529512,"interface\\glues\\loadingscreens\\loadscreen_darkshorewarfront"},
{2530069,"interface\\glues\\loadingscreens\\loadscreen_zuldazarraid_wide"},
{2820825,"interface\\glues\\loadingscreens\\loadingscreen_arathibasin_update_wide"},
{2821799,"interface\\glues\\loadingscreens\\loadscreenbrawlgararena_classiclogo"},
{2821800,"interface\\glues\\loadingscreens\\loadscreendarkmoonisland_classiclogo"},
{2827086,"interface\\glues\\loadingscreens\\loadscreen_warsonggulch_update_wide"},
{2994053,"interface\\glues\\loadingscreens\\loadingscreen_nazjatar_raid"},
{6213069,"interface\\glues\\loadingscreens\\loadscreen_classic_demon_fall_canyon"},
{6213070,"interface\\glues\\loadingscreens\\loadscreen_classic_storm_cliffs"},
{6213071,"interface\\glues\\loadingscreens\\loadscreen_classic_tainted_scar"},
{6422642,"interface\\glues\\loadingscreens\\loadscreen_classic_scarletraid"},
{6514589,"interface\\glues\\loadingscreens\\loadscreen_classic_karazhancrypts"},
{6650900,"interface\\glues\\loadingscreens\\loadscreen_classic_crystalvale"},
{6730949,"interface\\glues\\loadingscreens\\loadscreen_classic_greendragonraid"},
{131201,"interface\\glues\\credits\\1000px-coilfangpaintover1"},
{131207,"interface\\glues\\credits\\1024px-blade3_final1"},
{131215,"interface\\glues\\credits\\1h_axes1"},
{131223,"interface\\glues\\credits\\acrest1"},
{131227,"interface\\glues\\credits\\arakkoa1"},
{131233,"interface\\glues\\credits\\arcane_golem1"},
{131239,"interface\\glues\\credits\\auchindoun1"},
{131247,"interface\\glues\\credits\\auchindoun_1h1"},
{131255,"interface\\glues\\credits\\badlands1"},
{131261,"interface\\glues\\credits\\bd1"},
{131269,"interface\\glues\\credits\\be_building1"},
{131275,"interface\\glues\\credits\\be_building_two1"},
{131281,"interface\\glues\\credits\\bladesedge1"},
{131289,"interface\\glues\\credits\\bladesedgemountains1"},
{131295,"interface\\glues\\credits\\blastedlands1"},
{131301,"interface\\glues\\credits\\blood_elf_one1"},
{131309,"interface\\glues\\credits\\bloodelf_female1"},
{131318,"interface\\glues\\credits\\bloodelf_icon1"},
{131322,"interface\\glues\\credits\\bloodelf_priestess_master1"},
{131328,"interface\\glues\\credits\\bloodelf_two1"},
{131334,"interface\\glues\\credits\\bloodelf_webimage1"},
{131338,"interface\\glues\\credits\\border1"},
{131339,"interface\\glues\\credits\\centaur1"},
{131345,"interface\\glues\\credits\\clefthoof_3_horn1"},
{131353,"interface\\glues\\credits\\dark_portal1"},
{131359,"interface\\glues\\credits\\darnasis1"},
{131365,"interface\\glues\\credits\\ddraenei_start1"},
{131373,"interface\\glues\\credits\\demon_chamber1"},
{131381,"interface\\glues\\credits\\desolace1"},
{131387,"interface\\glues\\credits\\draenei1"},
{131393,"interface\\glues\\credits\\draenei_character1"},
{131397,"interface\\glues\\credits\\draenei_cityint1"},
{131405,"interface\\glues\\credits\\draenei_crest1"},
{131409,"interface\\glues\\credits\\draenei_female1"},
{131417,"interface\\glues\\credits\\draenei_paladin1"},
{131423,"interface\\glues\\credits\\draenei_three1"},
{131429,"interface\\glues\\credits\\draenei_two1"},
{131437,"interface\\glues\\credits\\dragonisles1"},
{131443,"interface\\glues\\credits\\drake1"},
{131449,"interface\\glues\\credits\\dranei_f_hair1"},
{131455,"interface\\glues\\credits\\dranei_m_hair1"},
{131459,"interface\\glues\\credits\\dwarfcrest1"},
{131463,"interface\\glues\\credits\\dwarfhunter1"},
{131467,"interface\\glues\\credits\\elekk1"},
{131473,"interface\\glues\\credits\\elemental1"},
{131477,"interface\\glues\\credits\\fellwood1"},
{131483,"interface\\glues\\credits\\female_bloodelf1"},
{131487,"interface\\glues\\credits\\forsakencrest1"},
{131491,"interface\\glues\\credits\\fungalgiant1"},
{131495,"interface\\glues\\credits\\gargoyle1"},
{131499,"interface\\glues\\credits\\hellfire_concept1"},
{131507,"interface\\glues\\credits\\hordebanner1"},
{131511,"interface\\glues\\credits\\human_mage1"},
{131515,"interface\\glues\\credits\\human_male1"},
{131519,"interface\\glues\\credits\\humanmale1"},
{131523,"interface\\glues\\credits\\hunter1"},
{131529,"interface\\glues\\credits\\illidan1"},
{131537,"interface\\glues\\credits\\illidan_concept1"},
{131543,"interface\\glues\\credits\\l60etc1"},
{131547,"interface\\glues\\credits\\lab1"},
{131553,"interface\\glues\\credits\\militaryorcboss1"},
{131561,"interface\\glues\\credits\\naaru_crashsite1"},
{131569,"interface\\glues\\credits\\naaru_ship1"},
{131577,"interface\\glues\\credits\\naga1"},
{131581,"interface\\glues\\credits\\nightelfcrest1"},
{131585,"interface\\glues\\credits\\nightelves1"},
{131591,"interface\\glues\\credits\\nightshollow1"},
{131595,"interface\\glues\\credits\\ocean1"},
{131601,"interface\\glues\\credits\\ogre_lord1"},
{131605,"interface\\glues\\credits\\orc1"},
{131607,"interface\\glues\\credits\\orccamp1"},
{131613,"interface\\glues\\credits\\orcshield1"},
{131617,"interface\\glues\\credits\\outland1"},
{131623,"interface\\glues\\credits\\parchment1"},
{131631,"interface\\glues\\credits\\photos1"},
{131639,"interface\\glues\\credits\\razorfen1"},
{131645,"interface\\glues\\credits\\razorfendowns1"},
{131651,"interface\\glues\\credits\\ridingdrake1"},
{131657,"interface\\glues\\credits\\shattrath1"},
{131665,"interface\\glues\\credits\\shivan1"},
{131669,"interface\\glues\\credits\\shootingdwarf1"},
{131675,"interface\\glues\\credits\\silvermoon_day1"},
{131683,"interface\\glues\\credits\\silvermoon_tower1"},
{131689,"interface\\glues\\credits\\southerndesolace1"},
{131695,"interface\\glues\\credits\\strangle1"},
{131699,"interface\\glues\\credits\\swampofsorrows1"},
{131705,"interface\\glues\\credits\\tauren1"},
{131711,"interface\\glues\\credits\\tauren_hunter1"},
{131715,"interface\\glues\\credits\\taurencrest1"},
{131719,"interface\\glues\\credits\\tempest_keep1"},
{131727,"interface\\glues\\credits\\terrokkar1"},
{131735,"interface\\glues\\credits\\the_broken1"},
{131741,"interface\\glues\\credits\\thousandneedles1"},
{131747,"interface\\glues\\credits\\thunderbluff1"},
{131753,"interface\\glues\\credits\\tier4_druid1"},
{131759,"interface\\glues\\credits\\tirisfallglades1"},
{131765,"interface\\glues\\credits\\tolbarad1"},
{131771,"interface\\glues\\credits\\troll1"},
{131777,"interface\\glues\\credits\\trollbanner1"},
{131781,"interface\\glues\\credits\\undeadcrest1"},
{131785,"interface\\glues\\credits\\wow_bloodelves1"},
{131789,"interface\\glues\\credits\\wrathguard1"},
{131795,"interface\\glues\\credits\\zepplin1"},
{131801,"interface\\glues\\credits\\zulaman1"},
{235511,"interface\\glues\\credits\\axe2drak1"},
{235519,"interface\\glues\\credits\\axedrak1"},
{235527,"interface\\glues\\credits\\azol01"},
{235535,"interface\\glues\\credits\\boreantun1"},
{235543,"interface\\glues\\credits\\boreantundra21"},
{235551,"interface\\glues\\credits\\cinsnow01tga1"},
{235559,"interface\\glues\\credits\\coldarranextga1"},
{235567,"interface\\glues\\credits\\crystalsong1tga1"},
{235575,"interface\\glues\\credits\\dalarandometga1"},
{235583,"interface\\glues\\credits\\dalarantga1"},
{235591,"interface\\glues\\credits\\deathknight201"},
{235599,"interface\\glues\\credits\\deathknight301"},
{235607,"interface\\glues\\credits\\deathknight401"},
{235615,"interface\\glues\\credits\\deathknight501"},
{235623,"interface\\glues\\credits\\epicswordtga1"},
{235631,"interface\\glues\\credits\\frostwyrm01tga1"},
{235639,"interface\\glues\\credits\\gatetga1"},
{235647,"interface\\glues\\credits\\geist_contga1"},
{235655,"interface\\glues\\credits\\grizzlemaw2tga1"},
{235663,"interface\\glues\\credits\\grizzlemawtga1"},
{235672,"interface\\glues\\credits\\grizzlyhills2tga1"},
{235680,"interface\\glues\\credits\\grizzlyhills3tga1"},
{235688,"interface\\glues\\credits\\grizzlyhillstga1"},
{235696,"interface\\glues\\credits\\hallwaytga1"},
{235704,"interface\\glues\\credits\\hunter01tga1"},
{235712,"interface\\glues\\credits\\id_towntga1"},
{235720,"interface\\glues\\credits\\irondwarftga1"},
{235728,"interface\\glues\\credits\\knife1htga1"},
{235736,"interface\\glues\\credits\\leathersunwelltga1"},
{235744,"interface\\glues\\credits\\lichkingtga1"},
{235752,"interface\\glues\\credits\\mace1htga1"},
{235760,"interface\\glues\\credits\\maginnistga1"},
{235768,"interface\\glues\\credits\\magnataur1"},
{235770,"interface\\glues\\credits\\magnataur21"},
{235784,"interface\\glues\\credits\\mergul011"},
{235792,"interface\\glues\\credits\\nerubianarch1"},
{235800,"interface\\glues\\credits\\nexusfire1"},
{235808,"interface\\glues\\credits\\northgiant1"},
{235816,"interface\\glues\\credits\\northrendcomp1"},
{235824,"interface\\glues\\credits\\orctower1"},
{235832,"interface\\glues\\credits\\penguin1"},
{235840,"interface\\glues\\credits\\powersource1"},
{235848,"interface\\glues\\credits\\revanent1"},
{235850,"interface\\glues\\credits\\revanent21"},
{235864,"interface\\glues\\credits\\rocket1"},
{235872,"interface\\glues\\credits\\sanctification1"},
{235880,"interface\\glues\\credits\\seavrykul1"},
{235888,"interface\\glues\\credits\\shol021"},
{235896,"interface\\glues\\credits\\shol1"},
{235904,"interface\\glues\\credits\\shoveltusk1"},
{235912,"interface\\glues\\credits\\sword_1h1"},
{235920,"interface\\glues\\credits\\titan11"},
{235928,"interface\\glues\\credits\\trollfacade1"},
{235936,"interface\\glues\\credits\\turtle011"},
{235944,"interface\\glues\\credits\\tuskar house1"},
{235952,"interface\\glues\\credits\\tuskarguy1"},
{235954,"interface\\glues\\credits\\tuskarguy21"},
{235968,"interface\\glues\\credits\\uld_hall1"},
{235976,"interface\\glues\\credits\\valgardedragon1"},
{235984,"interface\\glues\\credits\\valgardeforge1"},
{235992,"interface\\glues\\credits\\vamp1"},
{236000,"interface\\glues\\credits\\vryfem1"},
{236008,"interface\\glues\\credits\\vrykdoor1"},
{236016,"interface\\glues\\credits\\vrykul_undead1"},
{236024,"interface\\glues\\credits\\vrykulbuild1"},
{236032,"interface\\glues\\credits\\vrykulface1"},
{236040,"interface\\glues\\credits\\zombie1"},
{236048,"interface\\glues\\credits\\zuldrak1"},
{3067393,"interface\\glues\\credits\\classicgryphon1"}
}
function NS.RunArtCheck()
    if not NS.db then return end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(4, 4); f:SetPoint("TOPLEFT", -100, 100)
    local t = f:CreateTexture()
    local res, found = {}, 0
    for _, c in ipairs(ART_CANDIDATES) do
        local okPath = t:SetTexture(c[2])
        local fidPath = t.GetTextureFileID and t:GetTextureFileID() or nil
        local okID = t:SetTexture(c[1])
        local fidID = t.GetTextureFileID and t:GetTextureFileID() or nil
        local w, h = 0, 0
        res[#res + 1] = ("%d|%s|%s|%s|%s|%s"):format(c[1], c[2], tostring(okPath), tostring(fidPath), tostring(okID), tostring(fidID))
        if fidPath then found = found + 1 end
    end
    NS.db.artcheck = { build = select(4, GetBuildInfo()), version = (GetBuildInfo()), results = res, found = found }
    print(("|cffffcc40Flight Buddy|r art check done: %d/%d textures resolved. /reload to save."):format(found, #ART_CANDIDATES))
end
