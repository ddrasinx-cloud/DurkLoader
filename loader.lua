--===========================================================
-- Fury 1.0  |  Key System + ESP + Aimbot + Radar
--===========================================================
local Services = setmetatable({}, {__index = function(s,k)
	local ok, v = pcall(game.GetService, game, k)
	if ok and v then s[k] = v; return v end
end})
local Players = Services.Players
local RunS = Services.RunService
local UIS = Services.UserInputService
local WS = Services.Workspace
local HttpS = Services.HttpService
local StarterGui = Services.StarterGui
while not Players.LocalPlayer do task.wait() end
while not WS.CurrentCamera do task.wait() end
local lp = Players.LocalPlayer
local cam = WS.CurrentCamera

--===========================================================
-- UTILITY
--===========================================================
local Rand = Random.new(os.time() + os.clock() * 1000)
local function ri(a, b) return Rand:NextInteger(a, b) end
local function rn(a, b) return Rand:NextNumber(a, b) end
local function c3(r, g, b) return Color3.fromRGB(r, g, b) end
local function v2(x, y) return Vector2.new(x, y) end
local function v3(x, y, z) return Vector3.new(x, y, z) end
local function rnd(n, p) p = 10 ^ (p or 0); return math.floor(n * p + 0.5) / p end
local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function getHWID()
	local ok, h = pcall(function()
		if syn and syn.crypt and syn.crypt.hash then
			return syn.crypt.hash("sha256", tostring(lp.UserId) .. ":" .. game.GameId)
		end
	end)
	if ok and h then return h end
	return tostring(lp.UserId)
end

--===========================================================
-- PERSISTENCE
--===========================================================
local KEYS_URL = "https://raw.githubusercontent.com/ddrasinx-cloud/DurkLoader/master/keys.json"
local function loadKeyDB()
	-- Load from GitHub (centralized — freeze/delete enforced instantly)
	local ok, d = pcall(function()
		local body = game:HttpGet(KEYS_URL)
		return HttpS:JSONDecode(body)
	end)
	if ok and type(d) == "table" then return d end
	-- Fallback to local file
	local ok2, d2 = pcall(readfile, "FuryKeys.json")
	if ok2 and d2 then
		local ok3, t = pcall(HttpS.JSONDecode, HttpS, d2)
		if ok3 and type(t) == "table" then return t end
	end
	return {}
end
local function saveKeyDB(t)
	pcall(function() writefile("FuryKeys.json", HttpS:JSONEncode(t)) end)
end
local function isAuthed()
	return pcall(isfile, "FuryAuth.json") and pcall(readfile, "FuryAuth.json") == "1"
end
local function setAuthed(v)
	pcall(function() writefile("FuryAuth.json", v and "1" or "0") end)
end
local keyDB = loadKeyDB()
local _authed = isAuthed()  -- in-memory auth flag (render gates)

--===========================================================
-- KEY EXPIRY
--===========================================================
local function parseDuration(d)
	if type(d) ~= "string" then return 30 * 86400 end
	local n, u = d:match("^(%d+)([ywdhms])$")
	n = tonumber(n)
	if not n then return 30 * 86400 end
	if u == "y" then return n * 365 * 86400
	elseif u == "w" then return n * 7 * 86400
	elseif u == "d" then return n * 86400
	elseif u == "h" then return n * 3600
	elseif u == "m" then return n * 60
	elseif u == "s" then return n
	end; return 30 * 86400
end

local function isKeyExpired(key)
	local db = loadKeyDB()
	local e = db[key]
	if not e then return false end
	if type(e) ~= "table" or not e.expires then return false end
	if os.time() > e.expires then return true end
	return false
end

--===========================================================
-- KEY SYSTEM  (DURK prefix — kept for key format compatibility)
--===========================================================
local KA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local SL = 5
local KC = {5, 11, 3}
local DURK_END = {69, 86, 52}

local function segSum(s)
	local n = 0
	for i = 1, #s do n = n + string.byte(s, i) end
	return n % 17
end

function generateKey()
	local segs = {}
	local tailByte = DURK_END[ri(1, #DURK_END)]
	segs[1] = "DURK" .. string.char(tailByte)
	repeat
		segs[2] = ""
		for _ = 1, SL do segs[2] = segs[2] .. KA:sub(ri(1, #KA), ri(1, #KA)) end
	until segSum(segs[2]) == KC[2]
	repeat
		segs[3] = ""
		for _ = 1, SL do segs[3] = segs[3] .. KA:sub(ri(1, #KA), ri(1, #KA)) end
	until segSum(segs[3]) == KC[3]
	return segs[1] .. "-" .. segs[2] .. "-" .. segs[3]
end

local function checksumMatch(k)
	local a, b, c = k:match("^([" .. KA .. "]+)-([" .. KA .. "]+)-([" .. KA .. "]+)$")
	if not (a and b and c) then return false end
	if #a ~= SL or #b ~= SL or #c ~= SL then return false end
	if a:sub(1, 4) ~= "DURK" then return false end
	return segSum(a) == KC[1] and segSum(b) == KC[2] and segSum(c) == KC[3]
end

function validateKey(k)
	if type(k) ~= "string" then return false end
	if not checksumMatch(k) then return false end
	local db = loadKeyDB(); local e = db[k]
	if not e then return false end
	if type(e) ~= "table" then return false end
	if e.frozen then return false end
	if e.hwid and e.hwid ~= "" and e.hwid ~= getHWID() then return false end
	return true
end

--===========================================================
-- WEBHOOK
--===========================================================
local WH_URL = "https://discord.com/api/webhooks/1528481174241018008/Lq3PtajZvhxWfVa8gmdWse29idKNnyVW4tr9WAKyOQ0e2c-fBuzsvjz2rsA4Zid3BRzO"
local function sendWebhook(key, expires, duration)
	local expStr = os.date("%Y-%m-%d %H:%M", expires)
	local buyerMsg = ">>> **Thank you for purchasing Fury Software!** 🎉\n```\n" .. key .. "\n```\n📅 Expires: " .. expStr .. "\n\n**Instructions:**\n1️⃣ Load the script in your executor\n2️⃣ Enter your license key\n3️⃣ Press RightShift to open the menu\n4️⃣ Configure and enjoy!"
	local data = {embeds = {{
		title = "Fury Software — New License",
		color = 0xc83250,
		fields = {
			{name = "License Key", value = "```\n" .. key .. "\n```", inline = false},
			{name = "Expires", value = expStr .. " (" .. duration .. ")", inline = true},
			{name = "Status", value = "✅ Active", inline = true},
			{name = "📋 Copy & Send to Buyer", value = buyerMsg, inline = false},
			{name = "🔗 Support Discord", value = "[Click to join](https://discord.gg/sAW47m2UcK)", inline = true}
		},
		footer = {text = "Fury 1.0 | All sales are recorded"}
	}}}
	local body = HttpS:JSONEncode(data)
	local ok
	ok = pcall(function() syn.request({Url = WH_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body}) end)
	if not ok then ok = pcall(function() request({Url = WH_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body}) end) end
	if not ok then ok = pcall(function() http_request({Url = WH_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body}) end) end
	print("")
	print("=== COPY & SEND TO BUYER ===")
	print("Thanks for purchasing Fury Software!")
	print("Key: " .. key)
	print("Expires: " .. expStr)
	print("1. Load the script")
	print("2. Enter your key")
	print("3. Press RightShift to open menu")
	print("4. Enjoy!")
	print("=============================")
	print("")
end

-- Send webhook when HWID gets bound at auth time
local function sendHWIDWebhook(key, hwid)
	if not hwid or hwid == "" then return end
	local db = loadKeyDB(); local e = db[key]
	if not e then return end
	local data = {embeds = {{
		title = "Fury Software — HWID Bound",
		color = 0x4080e0,
		fields = {
			{name = "License Key", value = "```\n" .. key .. "\n```", inline = false},
			{name = "HWID", value = "```\n" .. hwid .. "\n```", inline = true},
			{name = "Status", value = "✅ Bound & Active", inline = true},
			{name = "Expires", value = os.date("%Y-%m-%d %H:%M", e.expires) .. " (" .. e.duration .. ")", inline = false}
		},
		footer = {text = "Fury 1.0 | HWID auto-recorded"}
	}}}
	local body = HttpS:JSONEncode(data)
	pcall(function() syn.request({Url = WH_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body}) end)
	pcall(function() request({Url = WH_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body}) end)
	pcall(function() http_request({Url = WH_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body}) end)
end

--===========================================================
-- SETTINGS
--===========================================================
local cfg = {
	esp = true,
	skel = false,
	aimbot = true,
	radar = true,
	fov = 90,
	smooth = 5,
	target = "Head",
	stream = false,
	rSize = 180,
	rRadius = 300,
	triggerbot = false,
	triggerDelay = 100,
	aimKey = "Always",
	maxDist = 1200,
	boxStyle = "2D",
	tracerPos = "Bottom",
	teamCheck = true,
	boxThick = 1.2,
	rOpacity = 0.5,
	watermark = true,
	crosshair = false,
	zoom = false,
	zoomKey = "Z",
	zoomFOV = 40,
}
local function saveCfg()
	pcall(function() writefile("FuryCfg.json", HttpS:JSONEncode(cfg)) end)
end
local function loadCfg()
	pcall(function()
		if isfile("FuryCfg.json") then
			local d = readfile("FuryCfg.json")
			local t = HttpS:JSONDecode(d)
			if type(t) == "table" then for k, v in pairs(t) do cfg[k] = v end end
		end
	end)
end
loadCfg()

--===========================================================
-- DRAWING POOL
--===========================================================
local SKEL_CONNS = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local POOL_SZ = 48
local pool = {box = {}, name = {}, hp = {}, dist = {}, line = {}, skel = {}}
local Dr_OK = pcall(Drawing.new, "Line")
local function mkDr(t)
	if Dr_OK then return Drawing.new(t) end
	return setmetatable({}, {__index = function() return function() end end})
end
if not Dr_OK then warn("[Fury] Drawing API unavailable — visuals disabled.") end
for _ = 1, POOL_SZ do
	local b = {}
	for _, k in ipairs({"t", "b", "l", "r"}) do b[k] = mkDr("Line"); b[k].Thickness = cfg.boxThick; b[k].ZIndex = 999 end
	for _, k in ipairs({"t_", "b_", "l_", "r_"}) do b[k] = mkDr("Line"); b[k].Thickness = 0.5; b[k].ZIndex = 998 end
	local n = mkDr("Text"); n.Size = 14; n.Outline = true; n.Center = true; n.ZIndex = 999
	local h = mkDr("Text"); h.Size = 12; h.Outline = true; h.Center = true; h.ZIndex = 999
	local d = mkDr("Text"); d.Size = 11; d.Outline = true; d.Center = true; d.ZIndex = 999
	local l = mkDr("Line"); l.Thickness = 1; l.ZIndex = 999
	table.insert(pool.box, b); table.insert(pool.name, n)
	table.insert(pool.hp, h); table.insert(pool.dist, d); table.insert(pool.line, l)
end
pool.skel = {}
for _ = 1, POOL_SZ do
	local s = {}
	for i = 1, #SKEL_CONNS do s[i] = mkDr("Line"); s[i].Thickness = 1.5; s[i].ZIndex = 999 end
	table.insert(pool.skel, s)
end

-- radar
local rBg = mkDr("Square"); rBg.Thickness = 1; rBg.Filled = true; rBg.Transparency = 0.5; rBg.ZIndex = 999
local rBd = mkDr("Square"); rBd.Thickness = 2; rBd.Filled = false; rBd.ZIndex = 999
local rCt = mkDr("Square"); rCt.Thickness = 0; rCt.Filled = true; rCt.Size = v2(4, 4); rCt.ZIndex = 999
local rPv = mkDr("Line"); rPv.Thickness = 2; rPv.Transparency = 0.3; rPv.ZIndex = 999
local rDt = {}
for _ = 1, 60 do local s = mkDr("Square"); s.Thickness = 0; s.Filled = true; s.Size = v2(4, 4); s.ZIndex = 999; table.insert(rDt, s) end

-- FOV circle
local fovC = mkDr("Circle"); fovC.Thickness = 1; fovC.Filled = false; fovC.NumSides = 64; fovC.ZIndex = 999

--===========================================================
-- STREAM / PANIC STATE
--===========================================================
local panicked = false
local function hideViz()
	panicked = true
	for _, b in ipairs(pool.box) do for _, ls in pairs(b) do if typeof(ls) == "Drawing" then ls.Visible = false end end end
	for _, s in ipairs(pool.skel) do for _, l in ipairs(s) do if typeof(l) == "Drawing" then l.Visible = false end end end
	for _, t in pairs(pool) do if t ~= pool.box and t ~= pool.skel then for _, o in pairs(t) do o.Visible = false end end end
	for _, o in pairs(rDt) do o.Visible = false end
	for _, o in ipairs({rBg, rBd, rCt, rPv, fovC, chLine1, chLine2, wmText}) do o.Visible = false end
	if mainGui then mainGui.Enabled = false end
end
local function showViz()
	panicked = false
	if mainGui then mainGui.Enabled = true end
	for _, b in ipairs(pool.box) do for _, ls in pairs(b) do if typeof(ls) == "Drawing" then ls.Visible = true end end end
	for _, s in ipairs(pool.skel) do for _, l in ipairs(s) do if typeof(l) == "Drawing" then l.Visible = true end end end
	for _, t in pairs(pool) do if t ~= pool.box and t ~= pool.skel then for _, o in pairs(t) do o.Visible = true end end end
	for _, o in pairs(rDt) do o.Visible = true end
	for _, o in ipairs({rBg, rBd, rCt, rPv, fovC, chLine1, chLine2, wmText}) do o.Visible = true end
end

--===========================================================
-- F3 KILL SWITCH
--===========================================================
local dead = false
local conns = {}
local function hook(c) table.insert(conns, c); return c end
local f3Lock = false

local function nuke()
	if dead then return end
	dead = true
	hideViz()
	for _, c in pairs(conns) do pcall(c.Disconnect, c) end; conns = {}
	for _, t in pairs(pool) do for _, o in pairs(t) do if typeof(o) == "Drawing" then pcall(function() o:Remove() end) elseif type(o) == "table" then for _, c in pairs(o) do if typeof(c) == "Drawing" then pcall(function() c:Remove() end) end end end end; t = {} end
	for _, o in pairs(rDt) do if typeof(o) == "Drawing" then pcall(function() o:Remove() end) end end
	for _, o in ipairs({rBg, rBd, rCt, rPv, fovC, chLine1, chLine2, wmText}) do if typeof(o) == "Drawing" then pcall(function() o:Remove() end) end end
	if mainGui and mainGui.Parent then mainGui:Destroy() end
	pool = nil; mainGui = nil; _LD = nil
	local env = getfenv()
	for k, _ in pairs(env) do if type(k) == "string" and k:sub(1, 1) == "_" then env[k] = nil end end
	pcall(warn, "[Fury] Nuked. F3 clean exit.")
end

--===========================================================
-- GUI  (Fury — dark red carbon)
--===========================================================
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "Fury_Menu"; mainGui.ResetOnSpawn = false; mainGui.Enabled = false; mainGui.DisplayOrder = 999
local parent = CoreGui or lp:FindFirstChildOfClass("PlayerGui")
pcall(function() mainGui.Parent = parent end)

local C_BG = c3(10, 10, 14); local C_FG = c3(18, 17, 24); local C_AC = c3(200, 30, 60)
local C_TX = c3(215, 215, 225); local C_DM = c3(100, 100, 115)
local C_RD = c3(220, 40, 40); local C_GN = c3(40, 210, 80)

-- Main frame with built-in border accent
local frm = Instance.new("Frame")
frm.BackgroundColor3 = C_BG; frm.BorderSizePixel = 0
frm.Size = UDim2.new(0, 420, 0, 540); frm.Position = UDim2.new(0.5, -210, 0.5, -270)
frm.ClipsDescendants = true; frm.Draggable = true; frm.Active = true; frm.Parent = mainGui
pcall(function() Instance.new("UICorner", frm).CornerRadius = UDim.new(0, 8) end)
-- Thin red border
local bdr = Instance.new("UIStroke")
bdr.Color = c3(180, 25, 50); bdr.Thickness = 1.5; bdr.Transparency = 0.4; pcall(function() bdr.Parent = frm end)

-- Title bar
local tbar = Instance.new("Frame")
tbar.BackgroundColor3 = c3(14, 12, 18); tbar.BorderSizePixel = 0; tbar.Size = UDim2.new(1, 0, 0, 36)
tbar.Parent = frm

local ttl = Instance.new("TextLabel")
ttl.BackgroundTransparency = 1; ttl.Size = UDim2.new(1, -40, 1, 0); ttl.Position = UDim2.new(0, 14, 0, 0)
ttl.Text = "FURY  1.0"; ttl.TextColor3 = C_AC; ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 17
ttl.TextXAlignment = Enum.TextXAlignment.Left; ttl.Parent = tbar

-- Accent line under title bar
local accLine = Instance.new("Frame")
accLine.BackgroundColor3 = C_AC; accLine.BorderSizePixel = 0
accLine.Size = UDim2.new(1, 0, 0, 2); accLine.Position = UDim2.new(0, 0, 1, 0)
accLine.Parent = tbar

local closeBtn = Instance.new("TextButton")
closeBtn.BackgroundTransparency = 1; closeBtn.Size = UDim2.new(0, 36, 1, 0); closeBtn.Position = UDim2.new(1, -36, 0, 0)
closeBtn.Text = "X"; closeBtn.TextColor3 = c3(180,180,190); closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 15
closeBtn.Parent = tbar
closeBtn.MouseButton1Click:Connect(function() mainGui.Enabled = false end)

-- Tab bar
local TAB_NAMES = {"Combat", "Visuals", "Radar", "Settings"}
local TAB_W = 105
local tabBar = Instance.new("Frame")
tabBar.BackgroundColor3 = c3(14, 12, 18); tabBar.BorderSizePixel = 0
tabBar.Size = UDim2.new(1, 0, 0, 32); tabBar.Position = UDim2.new(0, 0, 0, 36); tabBar.Parent = frm

local tabBtns = {}
local tabFrames = {}
local activeTab = 1

local function makeTab(name)
	local box = Instance.new("ScrollingFrame")
	box.BackgroundColor3 = c3(13, 12, 17); box.BorderSizePixel = 0
	box.Size = UDim2.new(1, -12, 1, -82); box.Position = UDim2.new(0, 6, 0, 68)
	box.CanvasSize = UDim2.new(0, 0, 0, 800); box.ScrollBarThickness = 3; box.Parent = frm
	box.Visible = false
	pcall(function() Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6) end)
	local L = {}
	L.Y = 6
	function L.lbl(t)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.new(1, -10, 0, 20); l.Position = UDim2.new(0, 5, 0, L.Y)
		l.Text = t; l.TextColor3 = C_AC; l.Font = Enum.Font.GothamBold; l.TextSize = 12
		l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = box
		L.Y = L.Y + 22; return l
	end
	function L.tog(t, get, set)
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = c3(22, 21, 28); b.BorderSizePixel = 0; b.Size = UDim2.new(1, -10, 0, 28); b.Position = UDim2.new(0, 5, 0, L.Y)
		b.Text = ""; b.Parent = box; L.Y = L.Y + 32
		pcall(function() Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) end)
		local on = get()
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = on and C_AC or c3(55, 55, 60); dot.Size = UDim2.new(0, 14, 0, 14); dot.Position = UDim2.new(0, 8, 0.5, -7); dot.Parent = b
		pcall(function() Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 7) end)
		local lb = Instance.new("TextLabel")
		lb.BackgroundTransparency = 1; lb.Size = UDim2.new(1, -28, 1, 0); lb.Position = UDim2.new(0, 28, 0, 0)
		lb.Text = t; lb.TextColor3 = on and C_TX or C_DM; lb.Font = Enum.Font.Gotham; lb.TextSize = 13; lb.TextXAlignment = Enum.TextXAlignment.Left; lb.Parent = b
		b.MouseButton1Click:Connect(function()
			set(not get()); local n = get(); dot.BackgroundColor3 = n and C_AC or c3(55,55,60); lb.TextColor3 = n and C_TX or C_DM; saveCfg()
		end); return b
	end
	function L.sldr(t, get, set, mn, mx)
		local b = Instance.new("Frame")
		b.BackgroundColor3 = c3(22, 21, 28); b.BorderSizePixel = 0; b.Size = UDim2.new(1, -10, 0, 36); b.Position = UDim2.new(0, 5, 0, L.Y)
		b.Parent = box; L.Y = L.Y + 40
		pcall(function() Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) end)
		local lb = Instance.new("TextLabel")
		lb.BackgroundTransparency = 1; lb.Size = UDim2.new(1, -14, 0, 16); lb.Position = UDim2.new(0, 9, 0, 1)
		lb.Text = t .. ": " .. rnd(get(), 1); lb.TextColor3 = C_TX; lb.Font = Enum.Font.Gotham; lb.TextSize = 12
		lb.TextXAlignment = Enum.TextXAlignment.Left; lb.Parent = b
		local tr = Instance.new("Frame")
		tr.BackgroundColor3 = c3(40, 40, 45); tr.Size = UDim2.new(1, -24, 0, 3); tr.Position = UDim2.new(0, 12, 0, 24); tr.Parent = b
		pcall(function() Instance.new("UICorner", tr).CornerRadius = UDim.new(0, 2) end)
		local pct = (get() - mn) / (mx - mn)
		local fl = Instance.new("Frame")
		fl.BackgroundColor3 = C_AC; fl.BorderSizePixel = 0; fl.Size = UDim2.new(pct, 0, 1, 0); fl.Parent = tr
		pcall(function() Instance.new("UICorner", fl).CornerRadius = UDim.new(0, 2) end)
		local th = Instance.new("TextButton")
		th.BackgroundColor3 = c3(230, 230, 235); th.Size = UDim2.new(0, 14, 0, 14)
		th.Position = UDim2.new(pct, -7, 0.5, -7); th.Text = ""; th.BorderSizePixel = 0; th.Parent = b
		pcall(function() Instance.new("UICorner", th).CornerRadius = UDim.new(0, 7) end)
		local drag = false
		th.MouseButton1Down:Connect(function()
			drag = true
			local dc; dc = UIS.InputEnded:Connect(function(i, gp)
				if gp and i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false; dc:Disconnect() end
			end)
		end)
		local mvCon; mvCon = UIS.InputChanged:Connect(function(i)
			if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
				local mp = UIS:GetMouseLocation() - b.AbsolutePosition
				local np = clamp(mp.X / b.AbsoluteSize.X, 0, 1)
				local v = mn + np * (mx - mn)
				if mx - mn > 10 then v = rnd(v) end
				set(v); lb.Text = t .. ": " .. rnd(v, 1)
				fl.Size = UDim2.new(np, 0, 1, 0); th.Position = UDim2.new(np, -7, 0.5, -7)
				saveCfg()
			end
		end)
		table.insert(conns, mvCon); return b
	end
	function L.drop(t, get, set, opts)
		local b = Instance.new("Frame")
		b.BackgroundColor3 = c3(22, 21, 28); b.BorderSizePixel = 0; b.Size = UDim2.new(1, -10, 0, 28); b.Position = UDim2.new(0, 5, 0, L.Y)
		b.Parent = box; L.Y = L.Y + 32
		pcall(function() Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) end)
		local lb = Instance.new("TextLabel")
		lb.BackgroundTransparency = 1; lb.Size = UDim2.new(0, 90, 1, 0); lb.Position = UDim2.new(0, 10, 0, 0)
		lb.Text = t; lb.TextColor3 = C_TX; lb.Font = Enum.Font.Gotham; lb.TextSize = 13
		lb.TextXAlignment = Enum.TextXAlignment.Left; lb.Parent = b
		local dbtn = Instance.new("TextButton")
		dbtn.BackgroundColor3 = c3(45, 42, 50); dbtn.BorderSizePixel = 0
		dbtn.Size = UDim2.new(0, 130, 0, 24); dbtn.Position = UDim2.new(1, -136, 0.5, -12)
		dbtn.Text = ""; dbtn.Parent = b
		pcall(function() Instance.new("UICorner", dbtn).CornerRadius = UDim.new(0, 4) end)
		dbtn.MouseEnter:Connect(function() dbtn.BackgroundColor3 = c3(55, 52, 60) end)
		dbtn.MouseLeave:Connect(function() dbtn.BackgroundColor3 = c3(45, 42, 50) end)
		local dtxt = Instance.new("TextLabel")
		dtxt.BackgroundTransparency = 1; dtxt.Size = UDim2.new(1, -18, 1, 0); dtxt.Position = UDim2.new(0, 8, 0, 0)
		dtxt.Text = get(); dtxt.TextColor3 = C_TX; dtxt.Font = Enum.Font.Gotham; dtxt.TextSize = 12
		dtxt.TextXAlignment = Enum.TextXAlignment.Left; dtxt.Parent = dbtn
		local arr = Instance.new("TextLabel")
		arr.BackgroundTransparency = 1; arr.Size = UDim2.new(0, 16, 1, 0); arr.Position = UDim2.new(1, -16, 0, 0)
		arr.Text = ">"; arr.TextColor3 = C_DM; arr.Font = Enum.Font.Gotham; arr.TextSize = 11; arr.Parent = dbtn
		local open = false; local list
		dbtn.MouseButton1Click:Connect(function()
			open = not open
			if open then
				if list then list:Destroy() end
				list = Instance.new("Frame"); list.BackgroundColor3 = c3(28, 26, 32); list.BorderSizePixel = 0
				list.Size = UDim2.new(0, 130, 0, #opts * 24); list.Position = UDim2.new(1, -136, 1, 2); list.Parent = b
				pcall(function() Instance.new("UICorner", list).CornerRadius = UDim.new(0, 4) end)
				local lbdr = Instance.new("UIStroke")
				lbdr.Color = c3(60, 55, 65); lbdr.Thickness = 1; lbdr.Transparency = 0.5; pcall(function() lbdr.Parent = list end)
				for i, opt in ipairs(opts) do
					local o = Instance.new("TextButton"); o.BackgroundColor3 = opt == get() and c3(40, 35, 45) or c3(28, 26, 32); o.BorderSizePixel = 0
					o.Size = UDim2.new(1, 0, 0, 24); o.Position = UDim2.new(0, 0, 0, (i - 1) * 24)
					o.Text = ""; o.Parent = list
					o.MouseEnter:Connect(function() o.BackgroundColor3 = c3(45, 40, 50) end)
					o.MouseLeave:Connect(function() o.BackgroundColor3 = opt == get() and c3(40, 35, 45) or c3(28, 26, 32) end)
					local otxt = Instance.new("TextLabel")
					otxt.BackgroundTransparency = 1; otxt.Size = UDim2.new(1, -10, 1, 0); otxt.Position = UDim2.new(0, 8, 0, 0)
					otxt.Text = opt; otxt.TextColor3 = opt == get() and C_AC or C_TX; otxt.Font = Enum.Font.Gotham; otxt.TextSize = 12
					otxt.TextXAlignment = Enum.TextXAlignment.Left; otxt.Parent = o
					o.MouseButton1Click:Connect(function()
						set(opt); dtxt.Text = opt; arr.Text = ">"; open = false; list:Destroy(); saveCfg()
					end)
				end
				arr.Text = "v"
			else if list then list:Destroy(); arr.Text = ">" end end
		end); return b
	end
			else if list then list:Destroy() end end
		end); return b
	end
	function L.btn(t, cb)
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = C_AC; b.BorderSizePixel = 0; b.Size = UDim2.new(1, -10, 0, 30); b.Position = UDim2.new(0, 5, 0, L.Y)
		b.Text = "  " .. t; b.TextColor3 = c3(240, 240, 245); b.Font = Enum.Font.GothamBold; b.TextSize = 13; b.Parent = box
		pcall(function() Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6) end)
		b.MouseButton1Click:Connect(cb); L.Y = L.Y + 34; return b
	end
	return box, L
end

-- Build tabs
for i, name in ipairs(TAB_NAMES) do
	local box, L = makeTab(name)
	tabFrames[i] = box
	if name == "Combat" then
		L.tog("Aimbot", function() return cfg.aimbot end, function(v) cfg.aimbot = v end)
		L.tog("Triggerbot", function() return cfg.triggerbot end, function(v) cfg.triggerbot = v end)
		L.Y = L.Y + 2; L.lbl("-- AIMBOT SETTINGS --")
		L.sldr("FOV", function() return cfg.fov end, function(v) cfg.fov = v end, 10, 180)
		L.sldr("Smoothness", function() return cfg.smooth end, function(v) cfg.smooth = v end, 1, 20)
		L.drop("Target", function() return cfg.target end, function(v) cfg.target = v end, {"Head", "Torso", "Random"})
		L.drop("Aim Key", function() return cfg.aimKey end, function(v) cfg.aimKey = v end, {"RightShift", "LeftAlt", "MouseButton2", "Always"})
		L.Y = L.Y + 2; L.lbl("-- TRIGGERBOT SETTINGS --")
		L.sldr("Trigger Delay (ms)", function() return cfg.triggerDelay end, function(v) cfg.triggerDelay = v end, 0, 1000)
	elseif name == "Visuals" then
		L.tog("ESP", function() return cfg.esp end, function(v) cfg.esp = v end)
		L.tog("Skeleton", function() return cfg.skel end, function(v) cfg.skel = v end)
		L.tog("Team Check", function() return cfg.teamCheck end, function(v) cfg.teamCheck = v end)
		L.tog("Crosshair", function() return cfg.crosshair end, function(v) cfg.crosshair = v end)
		L.tog("Stream Mode", function() return cfg.stream end, function(v)
			cfg.stream = v
			print("[Fury] Stream mode " .. (v and "ON — OBS bypass active" or "OFF"))
		end)
		L.Y = L.Y + 2; L.lbl("-- ESP SETTINGS --")
		L.sldr("Max Distance", function() return cfg.maxDist end, function(v) cfg.maxDist = v end, 200, 2000)
		L.sldr("Box Thickness", function() return cfg.boxThick end, function(v) cfg.boxThick = rnd(v, 1) end, 0.5, 4)
		L.drop("Box Style", function() return cfg.boxStyle end, function(v) cfg.boxStyle = v end, {"2D", "Corners"})
		L.drop("Tracer Pos", function() return cfg.tracerPos end, function(v) cfg.tracerPos = v end, {"Bottom", "Center", "Top"})
	elseif name == "Radar" then
		L.tog("Radar", function() return cfg.radar end, function(v) cfg.radar = v end)
		L.Y = L.Y + 2; L.lbl("-- RADAR SETTINGS --")
		L.sldr("Size", function() return cfg.rSize end, function(v) cfg.rSize = v end, 80, 300)
		L.sldr("Radius", function() return cfg.rRadius end, function(v) cfg.rRadius = v end, 50, 600)
		L.sldr("Opacity", function() return cfg.rOpacity end, function(v) cfg.rOpacity = rnd(v, 2) end, 0, 1)
	elseif name == "Settings" then
		L.tog("Watermark", function() return cfg.watermark end, function(v) cfg.watermark = v end)
		L.tog("Zoom", function() return cfg.zoom end, function(v) cfg.zoom = v end)
		L.Y = L.Y + 2; L.lbl("-- ZOOM SETTINGS --")
		L.drop("Zoom Key", function() return cfg.zoomKey end, function(v) cfg.zoomKey = v end, {"Z", "X", "C", "LeftShift", "LeftControl", "MouseButton2"})
		L.sldr("Zoom FOV", function() return cfg.zoomFOV end, function(v) cfg.zoomFOV = v end, 10, 80)
		L.Y = L.Y + 2; L.lbl("-- CONFIG --")
		L.btn("Save Config", saveCfg)
		L.btn("Load Config", function() loadCfg(); print("[Fury] Config loaded.") end)
		L.btn("Generate Key", function()
			local k = _LD.GenKey(); if k then print("[Fury] Key: " .. k) end
		end)
	end
	box.CanvasSize = UDim2.new(0, 0, 0, L.Y + 10)
end

-- Tab buttons
local function switchTab(idx)
	if activeTab == idx then return end
	local oldIdx = activeTab; activeTab = idx
	for j, b in ipairs(tabBtns) do
		b.BackgroundColor3 = (j == idx) and c3(200, 30, 60) or c3(16, 14, 20)
		b.TextColor3 = (j == idx) and c3(240, 240, 245) or c3(120, 120, 130)
	end
	local oldF = tabFrames[oldIdx]; local newF = tabFrames[idx]
	newF.Visible = true
	local ok = pcall(function()
		local ts = Services.TweenService
		local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local s1 = ts:Create(oldF, ti, {Position = UDim2.new(0, -440, 0, 62)})
		newF.Position = UDim2.new(0, 440, 0, 62)
		local s2 = ts:Create(newF, ti, {Position = UDim2.new(0, 6, 0, 62)})
		s1:Play(); s2:Play()
		s1.Completed:Connect(function()
			oldF.Visible = false; oldF.Position = UDim2.new(0, 6, 0, 62)
		end)
	end)
	if not ok then
		oldF.Visible = false; newF.Position = UDim2.new(0, 6, 0, 62)
	end
end

for i, name in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = (i == 1) and c3(200, 30, 60) or c3(16, 14, 20)
	btn.BorderSizePixel = 0; btn.Size = UDim2.new(0, TAB_W, 1, 0)
	btn.Position = UDim2.new(0, (i - 1) * TAB_W, 0, 0)
	btn.Text = name; btn.TextColor3 = (i == 1) and c3(240, 240, 245) or c3(120, 120, 130)
	btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.Parent = tabBar
	btn.MouseButton1Click:Connect(function() switchTab(i) end)
	btn.MouseEnter:Connect(function() if i ~= activeTab then btn.BackgroundColor3 = c3(50, 20, 30) end end)
	btn.MouseLeave:Connect(function() if i ~= activeTab then btn.BackgroundColor3 = c3(16, 14, 20) end end)
	table.insert(tabBtns, btn)
end

-- Show first tab
tabFrames[1].Visible = true

--===========================================================
-- KEY ENTRY GUI
--===========================================================
local keyGui = Instance.new("ScreenGui"); keyGui.Name = "Fury_Key"; keyGui.ResetOnSpawn = false; keyGui.DisplayOrder = 1000; pcall(function() keyGui.Parent = parent end)
local kf = Instance.new("Frame")
kf.BackgroundColor3 = C_BG; kf.BorderSizePixel = 0; kf.Size = UDim2.new(0, 360, 0, 210); kf.Position = UDim2.new(0.5, -180, 0.5, -105)
kf.Active = true; kf.Draggable = true; kf.Parent = keyGui
pcall(function() Instance.new("UICorner", kf).CornerRadius = UDim.new(0, 8) end)
local kb = Instance.new("UIStroke")
kb.Color = c3(180, 25, 50); kb.Thickness = 1.5; kb.Transparency = 0.3; pcall(function() kb.Parent = kf end)
local kh = Instance.new("TextLabel")
kh.BackgroundColor3 = C_AC; kh.BorderSizePixel = 0; kh.Size = UDim2.new(1, 0, 0, 36)
kh.Text = "FURY  1.0  -  Authenticate"; kh.TextColor3 = c3(240, 240, 245); kh.Font = Enum.Font.GothamBold; kh.TextSize = 14; kh.Parent = kf
pcall(function()
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 8)
	uc.Parent = kh
	local keep = Instance.new("Frame"); keep.BackgroundColor3 = C_AC; keep.BorderSizePixel = 0; keep.Size = UDim2.new(1, 0, 0, 2); keep.Position = UDim2.new(0, 0, 1, -2); keep.Parent = kh
end)
local ki = Instance.new("TextBox")
ki.BackgroundColor3 = c3(40, 38, 45); ki.BorderSizePixel = 0; ki.Size = UDim2.new(1, -24, 0, 34); ki.Position = UDim2.new(0, 12, 0, 52)
ki.PlaceholderText = "DURKX-XXXXX-XXXXX"; ki.Text = ""; ki.TextColor3 = C_TX; ki.Font = Enum.Font.Gotham; ki.TextSize = 15; ki.ClearTextOnFocus = false; ki.Parent = kf
pcall(function() Instance.new("UICorner", ki).CornerRadius = UDim.new(0, 6) end)
local ks = Instance.new("TextLabel")
ks.BackgroundTransparency = 1; ks.Size = UDim2.new(1, -24, 0, 18); ks.Position = UDim2.new(0, 12, 0, 94)
ks.Text = ""; ks.TextColor3 = C_RD; ks.Font = Enum.Font.Gotham; ks.TextSize = 11; ks.TextXAlignment = Enum.TextXAlignment.Center; ks.Parent = kf
local ka = Instance.new("TextButton")
ka.BackgroundColor3 = C_AC; ka.BorderSizePixel = 0; ka.Size = UDim2.new(1, -24, 0, 38); ka.Position = UDim2.new(0, 12, 0, 122)
ka.Text = "  AUTHENTICATE"; ka.TextColor3 = c3(240, 240, 245); ka.Font = Enum.Font.GothamBold; ka.TextSize = 14; ka.Parent = kf
ka.MouseEnter:Connect(function() ka.BackgroundColor3 = c3(230, 40, 70) end)
ka.MouseLeave:Connect(function() ka.BackgroundColor3 = C_AC end)
pcall(function() Instance.new("UICorner", ka).CornerRadius = UDim.new(0, 6) end)
local kx = Instance.new("TextLabel")
kx.BackgroundTransparency = 1; kx.Size = UDim2.new(1, -20, 0, 16); kx.Position = UDim2.new(0, 10, 0, 158)
kx.Text = "Format: DURKX-XXXXX-XXXXX - get your key from the Discord"; kx.TextColor3 = C_DM; kx.Font = Enum.Font.Gotham; kx.TextSize = 10
kx.TextXAlignment = Enum.TextXAlignment.Center; kx.Parent = kf

local function unlockProceed()
	_authed = true; keyGui:Destroy()
	showMenu = true; mainGui.Enabled = true; mainGui.Visible = true
end
if _authed then unlockProceed() end

local function doAuth()
	ks.Text = "Checking..."; ks.TextColor3 = c3(180, 180, 190)
	local ok, err = pcall(function()
		local key = ki.Text:upper():gsub("%s+", "")
		if not validateKey(key) then
			local db = loadKeyDB()
			if not db or not next(db) then
				ks.Text = "KEY NOT IN DB or invalid format"; ks.TextColor3 = c3(255, 200, 50)
			elseif db[key] and db[key].frozen then
				ks.Text = "KEY FROZEN — Contact support"; ks.TextColor3 = C_RD
			else
				ks.Text = "INVALID KEY"; ks.TextColor3 = C_RD
			end
			task.defer(function() task.wait(3); if ks then ks.Text = "" end end)
			return
		end
		if isKeyExpired(key) then
			ks.Text = "KEY EXPIRED"; ks.TextColor3 = C_RD
			task.defer(function() task.wait(2.5); if ks then ks.Text = "" end end)
			return
		end
		local db = loadKeyDB()
		if db[key] then
			if not db[key].hwid or db[key].hwid == "" then
				local hw = getHWID(); db[key].hwid = hw; saveKeyDB(db)
				task.defer(sendHWIDWebhook, key, hw)
			end
		end
		setAuthed(true); _authed = true; ks.Text = "KEY ACCEPTED"; ks.TextColor3 = C_GN
		task.wait(0.4); unlockProceed()
	end)
	if not ok then
		ks.Text = "ERROR"; ks.TextColor3 = c3(255, 100, 100)
		warn("[Fury] Auth error: " .. tostring(err))
		task.defer(function() task.wait(5); if ks then ks.Text = "" end end)
	end
end
ka.Activated:Connect(doAuth)
ki.FocusLost:Connect(function(enter) if enter then doAuth() end end)

if _authed and keyGui and keyGui.Parent then
	keyGui:Destroy(); mainGui.Enabled = true; mainGui.Visible = true
end

--===========================================================
-- ESP
--===========================================================
local function getChar(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character
end

	local function getCharExtents(c)
		local minY, maxY = math.huge, -math.huge; local maxRad = 0
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if not hrp then return v3(2.8, 4.6, 1.8) end
		local rp = hrp.Position
		for _, p in ipairs(c:GetChildren()) do
			if p:IsA("BasePart") then
				local hs = p.Size / 2; local pos = p.Position
				minY = math.min(minY, pos.Y - hs.Y)
				maxY = math.max(maxY, pos.Y + hs.Y)
				local dx, dz = pos.X - rp.X, pos.Z - rp.Z
				maxRad = math.max(maxRad, math.sqrt(dx*dx + dz*dz) + math.max(hs.X, hs.Z))
			end
		end
		if minY >= maxY then return v3(2.8, 4.6, 1.8) end
		return v3(maxRad * 2, maxY - minY, maxRad * 2)
	end

local function doESP()
	if not pool then return end
		-- wipe all drawings first (no ghosting)
	for _, b in ipairs(pool.box) do
		for _, k in ipairs({"t","b","l","r","t_","b_","l_","r_"}) do
			if b[k] then b[k].Visible = false end
		end
	end
	for _, s in ipairs(pool.skel) do for _, l in ipairs(s) do l.Visible = false end end
	for i = 1, #pool.name do pool.name[i].Visible = false; pool.hp[i].Visible = false; pool.dist[i].Visible = false; pool.line[i].Visible = false end
	if not cfg.esp or panicked or dead or not _authed then return end
	local idx = 0; local myPos = cam.CFrame.Position
	local plrs = Players:GetPlayers()
	table.sort(plrs, function(a, b)
		local da = a.Character and a.Character:FindFirstChild("HumanoidRootPart") and (a.Character.HumanoidRootPart.Position - myPos).Magnitude or 1e9
		local db = b.Character and b.Character:FindFirstChild("HumanoidRootPart") and (b.Character.HumanoidRootPart.Position - myPos).Magnitude or 1e9
		return da < db
	end)
	for _, p in ipairs(plrs) do
		repeat
			if p == lp then break end
			local c = getChar(p); if not c then break end
			local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then break end
			local hum = c:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then break end
			idx = idx + 1; if idx > #pool.box then idx = idx - 1; break end
			local dist = (myPos - hrp.Position).Magnitude
			if dist > cfg.maxDist then idx = idx - 1; break end
			local sz = getCharExtents(c); local cf = hrp.CFrame
			local hw, hh, hd = sz.X / 2, sz.Y / 2, sz.Z / 2
			local en = (cfg.teamCheck and p.Team ~= lp.Team) or not p.Team; local col = en and C_RD or C_GN
			local bfl = cf * v3(-hw, -hh, -hd); local bfr = cf * v3(hw, -hh, -hd)
			local bbr = cf * v3(hw, -hh, hd); local bbl = cf * v3(-hw, -hh, hd)
			local tfl = cf * v3(-hw, hh, -hd); local tfr = cf * v3(hw, hh, -hd)
			local tbr = cf * v3(hw, hh, hd); local tbl = cf * v3(-hw, hh, hd)
			local pts = {}
			for _, w in ipairs({bfl, bfr, bbr, bbl, tfl, tfr, tbr, tbl}) do
				local s, on = cam:WorldToViewportPoint(w)
				table.insert(pts, {s = v2(s.X, s.Y), on = on})
			end
			local any = false
			for _, pt in ipairs(pts) do if pt.on then any = true; break end end
			if not any then idx = idx - 1; break end
			local mnX, mnY, mxX, mxY = 1e9, 1e9, -1e9, -1e9
			for _, pt in ipairs(pts) do
				mnX = math.min(mnX, pt.s.X); mnY = math.min(mnY, pt.s.Y)
				mxX = math.max(mxX, pt.s.X); mxY = math.max(mxY, pt.s.Y)
			end
			local b = pool.box[idx]; local bw = cfg.boxThick
			if cfg.boxStyle == "Corners" then
				local hn = (mxY - mnY) * 0.25; local wn = (mxX - mnX) * 0.25
				-- Glow layer
				for _, k in ipairs({"t_","b_","l_","r_"}) do
					b[k].Color = Color3.new(col.R * 0.4, col.G * 0.4, col.B * 0.4)
					b[k].Visible = true
				end
				b.t_.From = v2(mnX - 1, mnY - 1); b.t_.To = v2(mnX + wn + 1, mnY - 1)
				b.l_.From = v2(mnX - 1, mnY - 1); b.l_.To = v2(mnX - 1, mnY + hn + 1)
				b.r_.From = v2(mxX + 1, mnY - 1); b.r_.To = v2(mxX - wn - 1, mnY - 1)
				b.b_.From = v2(mxX + 1, mnY - 1); b.b_.To = v2(mxX + 1, mnY + hn + 1)
				-- Main lines
				b.t.Color = col; b.t.Thickness = bw; b.t.From = v2(mnX, mnY); b.t.To = v2(mnX + wn, mnY); b.t.Visible = true
				b.l.Color = col; b.l.Thickness = bw; b.l.From = v2(mnX, mnY); b.l.To = v2(mnX, mnY + hn); b.l.Visible = true
				b.r.Color = col; b.r.Thickness = bw; b.r.From = v2(mxX, mnY); b.r.To = v2(mxX - wn, mnY); b.r.Visible = true
				b.b.Color = col; b.b.Thickness = bw; b.b.From = v2(mxX, mnY); b.b.To = v2(mxX, mnY + hn); b.b.Visible = true
			else
				-- Glow layer
				for _, k in ipairs({"t_","b_","l_","r_"}) do
					b[k].Color = Color3.new(col.R * 0.4, col.G * 0.4, col.B * 0.4)
					b[k].Visible = true
				end
				b.t_.From = v2(mnX - 1, mnY - 1); b.t_.To = v2(mxX + 1, mnY - 1)
				b.b_.From = v2(mnX - 1, mxY + 1); b.b_.To = v2(mxX + 1, mxY + 1)
				b.l_.From = v2(mnX - 1, mnY - 1); b.l_.To = v2(mnX - 1, mxY + 1)
				b.r_.From = v2(mxX + 1, mnY - 1); b.r_.To = v2(mxX + 1, mxY + 1)
				-- Main lines
				b.t.Color = col; b.t.Thickness = bw; b.t.From = v2(mnX, mnY); b.t.To = v2(mxX, mnY); b.t.Visible = true
				b.b.Color = col; b.b.Thickness = bw; b.b.From = v2(mnX, mxY); b.b.To = v2(mxX, mxY); b.b.Visible = true
				b.l.Color = col; b.l.Thickness = bw; b.l.From = v2(mnX, mnY); b.l.To = v2(mnX, mxY); b.l.Visible = true
				b.r.Color = col; b.r.Thickness = bw; b.r.From = v2(mxX, mnY); b.r.To = v2(mxX, mxY); b.r.Visible = true
			end
			local n = pool.name[idx]; n.Text = p.Name; n.Color = col; n.Position = v2(mnX + (mxX - mnX) / 2, mnY - 16); n.Visible = true
			local hp = pool.hp[idx]; local ch = math.floor(hum.Health + 0.5); local cm = math.floor(hum.MaxHealth + 0.5)
			hp.Text = ch .. "/" .. cm; hp.Color = ch > 70 and C_GN or (ch > 35 and c3(220, 200, 50) or C_RD)
			hp.Position = v2(mnX + (mxX - mnX) / 2, mnY - 2); hp.Visible = true
			local d = pool.dist[idx]; d.Text = math.floor(dist) .. "m"; d.Color = c3(170, 170, 175)
			d.Position = v2(mnX + (mxX - mnX) / 2, mxY + 2); d.Visible = true
			local l = pool.line[idx]; local vs = cam.ViewportSize
			local tx = vs.X / 2; local ty = cfg.tracerPos == "Top" and 0 or (cfg.tracerPos == "Center" and vs.Y / 2 or vs.Y)
			l.From = v2(tx, ty); l.To = v2(mnX + (mxX - mnX) / 2, mxY); l.Color = col; l.Visible = true
			if cfg.skel then
				local sk = pool.skel[idx]; local bp = {}
				for ci, conn in ipairs(SKEL_CONNS) do
					local p1 = bp[conn[1]] or (c:FindFirstChild(conn[1]) and c:FindFirstChild(conn[1]).Position) or nil
					local p2 = bp[conn[2]] or (c:FindFirstChild(conn[2]) and c:FindFirstChild(conn[2]).Position) or nil
					if conn[1] then bp[conn[1]] = p1 end
					if conn[2] then bp[conn[2]] = p2 end
					if p1 and p2 then
						local s1, on1 = cam:WorldToViewportPoint(p1)
						local s2, on2 = cam:WorldToViewportPoint(p2)
						if on1 or on2 then
							sk[ci].From = v2(s1.X, s1.Y); sk[ci].To = v2(s2.X, s2.Y)
							sk[ci].Color = col; sk[ci].Visible = true
						end
					end
				end
			end
		until true
	end
end

--===========================================================
-- AIMBOT
--===========================================================
local function getPart(tc)
	local p = cfg.target
	if p == "Random" then
		local opts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
		return tc:FindFirstChild(opts[ri(1, #opts)]) or tc:FindFirstChild("HumanoidRootPart")
	end
	return tc:FindFirstChild(p) or tc:FindFirstChild("Head") or tc:FindFirstChild("HumanoidRootPart")
end

local function findTarget()
	local best, bestD = nil, cfg.fov; local sc = cam.ViewportSize / 2
	for _, p in ipairs(Players:GetPlayers()) do
		repeat
			if p == lp then break end
			local c = getChar(p); if not c then break end
			local hum = c:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then break end
			local pt = getPart(c); if not pt then break end
			local sp, on = cam:WorldToViewportPoint(pt.Position); if not on then break end
			local d = (v2(sp.X, sp.Y) - sc).Magnitude
			if d < bestD then bestD = d; best = {pos = pt.Position} end
		until true
	end; return best
end

local function doAim()
	if not cfg.aimbot or panicked or dead or not _authed then return end
	local t = findTarget()
	if t then
		local cf = cam.CFrame; local ld = (t.pos - cf.Position).Unit
		local sm = cfg.smooth / 100; local nl = cf.LookVector:Lerp(ld, sm).Unit
		cam.CFrame = CFrame.lookAt(cf.Position, cf.Position + nl)
		-- Triggerbot
		if cfg.triggerbot then
			local mt = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
			if mt then
				task.delay(cfg.triggerDelay / 1000, function()
					pcall(function() mt:Activate() end)
				end)
			end
		end
	end
end

-- Zoom
local defaultFOV = cam.FieldOfView
local function doZoom()
	if not cfg.zoom or panicked or dead or not _authed then
		cam.FieldOfView = defaultFOV; return
	end
	local held = false
	local zk = cfg.zoomKey
	if zk == "MouseButton2" then
		held = pcall(function() return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end)
	elseif zk == "LeftControl" then
		held = UIS:IsKeyDown(Enum.KeyCode.LeftControl)
	elseif zk == "LeftShift" then
		held = UIS:IsKeyDown(Enum.KeyCode.LeftShift)
	elseif zk == "Z" then
		held = UIS:IsKeyDown(Enum.KeyCode.Z)
	elseif zk == "X" then
		held = UIS:IsKeyDown(Enum.KeyCode.X)
	elseif zk == "C" then
		held = UIS:IsKeyDown(Enum.KeyCode.C)
	end
	cam.FieldOfView = held and cfg.zoomFOV or defaultFOV
end

local function drawFOV()
	if not cfg.aimbot or panicked or dead or not _authed then fovC.Visible = false; return end
	local vs = cam.ViewportSize; local fp = cfg.fov * (vs.X / 1920) * 2.5
	fovC.Position = vs / 2; fovC.Radius = fp; fovC.Color = c3(255, 255, 255); fovC.Transparency = 0.55; fovC.Visible = true
end

-- Crosshair
local chLine1 = mkDr("Line"); chLine1.Thickness = 1.5; chLine1.ZIndex = 999
local chLine2 = mkDr("Line"); chLine2.Thickness = 1.5; chLine2.ZIndex = 999
local function drawCrosshair()
	if not cfg.crosshair or panicked or dead or not _authed then chLine1.Visible = false; chLine2.Visible = false; return end
	local vs = cam.ViewportSize; local cx, cy = vs.X / 2, vs.Y / 2; local sz = 8
	chLine1.From = v2(cx - sz, cy); chLine1.To = v2(cx + sz, cy); chLine1.Color = c3(255, 255, 255); chLine1.Visible = true
	chLine2.From = v2(cx, cy - sz); chLine2.To = v2(cx, cy + sz); chLine2.Color = c3(255, 255, 255); chLine2.Visible = true
end

-- Watermark
local wmText = mkDr("Text"); wmText.Size = 16; wmText.Outline = true; wmText.ZIndex = 999
local function drawWatermark()
	if not cfg.watermark or panicked or dead or not _authed then wmText.Visible = false; return end
	wmText.Text = "Fury 1.0 | " .. #Players:GetPlayers() .. " online"
	wmText.Position = v2(8, 8); wmText.Color = c3(200, 50, 80); wmText.Visible = true
end

--===========================================================
-- RADAR
--===========================================================
local function doRadar()
	rBg.Visible = false; rBd.Visible = false; rCt.Visible = false; rPv.Visible = false
	for i = 1, #rDt do rDt[i].Visible = false end
	if not cfg.radar or panicked or dead or not _authed then return end
	local rs = cfg.rSize; local rx, ry = rs + 12, rs + 12; local rr = cfg.rRadius
	local mp = cam.CFrame.Position; local lv = cam.CFrame.LookVector; local la = math.atan2(-lv.X, -lv.Z)
	rBg.Size = v2(rs, rs); rBg.Position = v2(rx - rs / 2, ry - rs / 2); rBg.Color = c3(0, 0, 0); rBg.Transparency = cfg.rOpacity; rBg.Visible = true
	rBd.Size = v2(rs, rs); rBd.Position = v2(rx - rs / 2, ry - rs / 2); rBd.Color = c3(55, 55, 60); rBd.Visible = true
	rCt.Position = v2(rx - 2, ry - 2); rCt.Color = C_GN; rCt.Visible = true
	rPv.From = v2(rx, ry); rPv.To = v2(rx + math.sin(la) * 32, ry - math.cos(la) * 32); rPv.Color = c3(255, 255, 255); rPv.Visible = true
	local di = 0
	for _, p in ipairs(Players:GetPlayers()) do
		repeat
			if p == lp then break end
			local c = getChar(p); if not c then break end
			local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then break end
			local hum = c:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then break end
			local rp = hrp.Position - mp; local d = rp.Magnitude
			if d > rr then break end
			local a = math.atan2(-rp.X, -rp.Z) - la; local sc = (rs / 2) * (d / rr)
			local px = rx + math.sin(a) * sc; local py = ry - math.cos(a) * sc
			di = di + 1; if di > #rDt then break end
			local dot = rDt[di]; dot.Color = (p.Team ~= lp.Team or not p.Team) and C_RD or C_GN
			dot.Position = v2(px - 2, py - 2); dot.Visible = true
		until true
	end
	for i = di + 1, #rDt do rDt[i].Visible = false end
end

--===========================================================
-- INPUT & MAIN LOOP
--===========================================================
local showMenu = true

-- F3 poll state
local f3Down = false

hook(UIS.InputBegan:Connect(function(input, gpe)
	if dead then return end
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
		showMenu = not showMenu
		if mainGui then mainGui.Enabled = showMenu end
	end
	if input.KeyCode == Enum.KeyCode.F9 then
		if panicked then showViz() else hideViz() end
	end
	if input.KeyCode == Enum.KeyCode.F3 then
		nuke()
	end
end))

hook(RunS.RenderStepped:Connect(function(dt)
	if dead then return end
	-- F3 secondary check (poll)
	if UIS:IsKeyDown(Enum.KeyCode.F3) then
		if not f3Down then f3Down = true; nuke() end
	else
		f3Down = false
	end
	doESP(); drawFOV(); doAim(); doZoom(); doRadar(); drawCrosshair(); drawWatermark()
	-- lava animation
	local fw, fh = 380, 520
	for _, p in ipairs(lavP) do
		local x, y = p.o.Position.X.Offset, p.o.Position.Y.Offset
		y = y + p.sp * dt * 60
		x = x + math.sin(p.ph + tick() * p.ss) * p.sw
		if y > fh + 10 then y = -10 - ri(0, 100); x = ri(-10, fw + 10) end
		p.o.Position = UDim2.new(0, x, 0, y)
	end

end))

--===========================================================
-- KEY GENERATOR (global export)
--===========================================================
_LD = {}
_LD.GenKey = function(duration)
	if not duration then duration = "30d" end
	local k = generateKey()
	local db = loadKeyDB()
	if db[k] then
		print("[Fury] Duplicate key, regenerating...")
		return _LD.GenKey(duration)
	end
	local expires = os.time() + parseDuration(duration)
	db[k] = {created = os.time(), expires = expires, duration = duration, frozen = false, hwid = ""}
	saveKeyDB(db)
	sendWebhook(k, expires, duration)
	local expStr = os.date("%Y-%m-%d %H:%M", expires)
	print("+-------------------------------------------+")
	print("|              FURY LICENSE KEY              |")
	print("+-------------------------------------------+")
	print("| " .. k .. " |")
	print("|  Expires: " .. expStr .. "  (" .. duration .. ")")
	print("+-------------------------------------------+")
	print("| loadstring: copy from Discord delivery    |")
	print("+-------------------------------------------+")
	return k, expires
end
_LD.ListKeys = function()
	local db = loadKeyDB(); local n = 0
	for k, e in pairs(db) do
		n = n + 1
		local expStr = e.expires and os.date("%Y-%m-%d %H:%M", e.expires) or "never"
		local frozen = e.frozen and " FROZEN" or ""
		local hwid = (e.hwid and e.hwid ~= "") and (" HWID:" .. e.hwid) or ""
		local expired = (e.expires and os.time() > e.expires) and " EXPIRED" or ""
		print(k .. "  " .. expStr .. " [" .. (expired .. frozen .. hwid):gsub("^ ", "") .. "]")
	end
	print("Total keys: " .. n)
end
_LD.FreezeKey = function(key)
	local db = loadKeyDB()
	if db[key] then db[key].frozen = true; saveKeyDB(db); print("[Fury] Frozen: " .. key); return true end
	return false
end
_LD.UnfreezeKey = function(key)
	local db = loadKeyDB()
	if db[key] then db[key].frozen = false; saveKeyDB(db); print("[Fury] Unfrozen: " .. key); return true end
	return false
end
_LD.SetHWID = function(key, hwid)
	local db = loadKeyDB()
	if db[key] then
		db[key].hwid = hwid or ""; saveKeyDB(db)
		print("[Fury] HWID set for " .. key .. ": " .. (hwid or "none"))
		if hwid and hwid ~= "" then task.defer(sendHWIDWebhook, key, hwid) end
		return true
	end
	return false
end
_LD.ResetHWID = function(key)
	local db = loadKeyDB()
	if db[key] then db[key].hwid = ""; saveKeyDB(db); print("[Fury] HWID reset for " .. key .. " — key can bind to a new user."); return true end
	return false
end
_LD.GetKeys = function()
	local db = loadKeyDB(); local out = {}
	for k, e in pairs(db) do table.insert(out, {key = k, created = e.created, expires = e.expires, duration = e.duration, frozen = e.frozen, hwid = e.hwid}) end
	table.sort(out, function(a, b) return (a.created or 0) > (b.created or 0) end)
	return out
end
_LD.Authed = isAuthed
_LD.Validate = validateKey

--===========================================================
-- STARTUP
--===========================================================
pcall(function() _ENV._LD = _LD end)
pcall(function() _ENV.LD_GenKey = _LD.GenKey end)
pcall(function() _ENV.LD_ListKeys = _LD.ListKeys end)
pcall(function() _ENV.LD_FreezeKey = _LD.FreezeKey end)
pcall(function() _ENV.LD_UnfreezeKey = _LD.UnfreezeKey end)
pcall(function() _ENV.LD_SetHWID = _LD.SetHWID end)
pcall(function() _ENV.LD_ResetHWID = _LD.ResetHWID end)

print("=== Fury 1.0 loaded ===")
print("> GenKey('30d')  | generate a key")
print("> ListKeys()     | list all keys")
print("> FreezeKey(k)   | freeze a key")
print("> UnfreezeKey(k) | unfreeze a key")
print("> SetHWID(k,uid) | bind key to user")
print("> ResetHWID(k)   | clear HWID binding")
print("> RightShift     | toggle menu")
print("> F9             | panic hide")
print("> F3             | nuke script")
print("> Discord: discord.gg/sAW47m2UcK")
