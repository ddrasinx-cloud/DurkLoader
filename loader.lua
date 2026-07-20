-- APEX SOFTWARE — REWRITTEN
-- UI: Orion Library  |  ESP: Drawing API  |  Aimbot: mousemoverel

--===========================================================
-- SETUP
--===========================================================
local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local HttpS = game:GetService("HttpService")
local lp = Players.LocalPlayer
local cam = WS.CurrentCamera
local mouse = lp:GetMouse()

local _SECRET_SALT = "Apex1.0_X7k9m2pQ"
local _authed = false
local panicked = false
local cfg = {}
local KEYS_URL = "https://raw.githubusercontent.com/ddrasinx-cloud/DurkLoader/master/keys.json?cb="..math.random()
local WH_URL = "https://discord.com/api/webhooks/1528481174241018008/Lq3PtajZvhxWfVa8gmdWse29idKNnyVW4tr9WAKyOQ0e2c-fBuzsvjz2rsA4Zid3BRzO"
local HWID_WH_URL = WH_URL

--===========================================================
-- CRYPTO HELPERS
--===========================================================
local function sha256(raw)
	if syn and syn.crypt and syn.crypt.hash then
		return syn.crypt.hash("sha256", raw)
	end
	local ok, ret = pcall(function() return game:GetService("HttpService"):SHA256(raw) end)
	if ok then return ret end
	warn("[Apex] No SHA256 available")
	return raw
end

local function b64enc(raw)
	if syn and syn.crypt and syn.crypt.encode then
		return syn.crypt.encode("base64", raw)
	end
	return raw
end

local function b64dec(raw)
	if syn and syn.crypt and syn.crypt.decode then
		local ok, d = pcall(syn.crypt.decode, "base64", raw)
		if ok then return d end
	end
	return raw
end

local function getHWID()
	return sha256(tostring(lp.UserId) .. ":" .. game.GameId)
end

--===========================================================
-- KEY AUTH
--===========================================================
local function fetchKeys()
	local body
	pcall(function() body = game:HttpGet(KEYS_URL, true) end)
	if not body then
		pcall(function() body = HttpS:GetAsync(KEYS_URL, true) end)
	end
	if not body then
		for _, fnName in ipairs({"syn.request","request","http_request"}) do
			pcall(function()
				local fn = loadstring("return " .. fnName)()
				local r = fn({Url=KEYS_URL, Method="GET"})
				if r and r.StatusCode == 200 and r.Body and #r.Body > 0 then body = r.Body end
			end)
			if body then break end
		end
	end
	if not body then
		for _, fnName in ipairs({"syn.request","request","http_request"}) do
			pcall(function()
				local fn = loadstring("return " .. fnName)()
				local r = fn({Url="https://api.github.com/repos/ddrasinx-cloud/DurkLoader/contents/keys.json", Method="GET", Headers={Accept="application/vnd.github.v3.raw"}})
				if r and r.StatusCode == 200 and r.Body and #r.Body > 0 then body = r.Body end
			end)
			if body then break end
		end
	end
	return body
end

local function loadKeyDB()
	local raw = fetchKeys()
	if not raw then return {} end
	local ok, db = pcall(HttpS.JSONDecode, HttpS, raw)
	if ok and type(db) == "table" then return db end
	return {}
end

local function signEntry(entry)
	if syn and syn.crypt and syn.crypt.hash then
		local payload = HttpS:JSONEncode(entry)
		entry.sig = syn.crypt.hash("sha256", payload .. ":" .. _SECRET_SALT)
	end
	return entry
end

local function verifySignature(entry)
	local sig = entry.sig
	if not sig then return true end
	local clean = {created=entry.created, expires=entry.expires, duration=entry.duration, frozen=entry.frozen, hwid=entry.hwid}
	local payload = HttpS:JSONEncode(clean)
	local expected = sha256(payload .. ":" .. _SECRET_SALT)
	return sig == expected
end

local function generateKey()
	local t = tostring(os.time())
	local r = tostring(math.random(1e9, 9e9))
	return sha256(t .. r .. lp.UserId):sub(1, 24)
end

local function parseDuration(str)
	local n = tonumber(str:match("%d+")) or 30
	if str:find("h") then return n * 3600
	elseif str:find("d") then return n * 86400
	elseif str:find("m") and not str:find("mo") then return n * 60
	elseif str:find("mo") then return n * 2592000
	else return n * 86400 end
end

--===========================================================
-- ORION LIBRARY LOAD
--===========================================================
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Snxdfer/back-ups-for-libs/refs/heads/main/Orion.lua"))()
if not OrionLib then
	warn("[Apex] Failed to load UI library")
	return
end

--===========================================================
-- CFG DEFAULTS
--===========================================================
cfg = {
	esp = false,
	boxStyle = "Corners",
	boxThick = 1.5,
	teamCheck = true,
	maxDist = 200,
	skeleton = true,
	tracer = true,
	healthBar = true,
	nameTag = true,
	distance = true,
	aimbot = false,
	aimKey = "MouseButton2",
	aimSmoothness = 0.6,
	aimFOV = 120,
	aimPart = "Head",
	aimWallCheck = false,
	fovCircle = true,
	crosshair = false,
	zoom = false,
	zoomAmount = 40,
	radar = false,
	rSize = 120,
	rOpacity = 0.35,
	fullbright = false,
	watermark = false,
}

--===========================================================
-- DRAWING SETUP
--===========================================================
local Dr_OK = pcall(Drawing.new, "Line")
local function dr(t)
	if Dr_OK then return Drawing.new(t) end
	return setmetatable({}, {__index = function() return function() end end})
end
if not Dr_OK then warn("[Apex] Drawing unavailable") end

local v2 = Vector2.new
local POOL_SZ = 30
local pool = {box={}, name={}, hp={}, dist={}, line={}, skel={}}

-- Skeleton connections (R15 default)
local SKEL = {
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
	{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local function initESP()
	for i = 1, POOL_SZ do
		local b = {}
		for _, k in ipairs({"t","b","l","r"}) do
			b[k] = dr("Line"); b[k].Thickness = cfg.boxThick; b[k].ZIndex = 999
		end
		for _, k in ipairs({"t_","b_","l_","r_"}) do
			b[k] = dr("Line"); b[k].Thickness = 0.5; b[k].ZIndex = 998
		end
		table.insert(pool.box, b)
		local n = dr("Text"); n.Size = 14; n.Outline = true; n.Center = true; n.ZIndex = 999
		local h = dr("Text"); h.Size = 12; h.Outline = true; h.Center = true; h.ZIndex = 999
		local d = dr("Text"); d.Size = 11; d.Outline = true; d.Center = true; d.ZIndex = 999
		local l = dr("Line"); l.Thickness = 1; l.ZIndex = 999
		table.insert(pool.name, n); table.insert(pool.hp, h); table.insert(pool.dist, d); table.insert(pool.line, l)
	end
	pool.skel = {}
	for i = 1, POOL_SZ do
		local s = {}
		for j = 1, #SKEL do s[j] = dr("Line"); s[j].Thickness = 1.5; s[j].ZIndex = 999 end
		table.insert(pool.skel, s)
	end
end

local rBg, rBd, rCt, rPv, rDt
local fovC, chLine1, chLine2, wmText

local function initDraw()
	initESP()
	rBg = dr("Square"); rBg.Thickness = 1; rBg.Filled = true; rBg.ZIndex = 999
	rBd = dr("Square"); rBd.Thickness = 2; rBd.Filled = false; rBd.ZIndex = 999
	rCt = dr("Square"); rCt.Thickness = 0; rCt.Filled = true; rCt.Size = v2(4,4); rCt.ZIndex = 999
	rPv = dr("Line"); rPv.Thickness = 2; rPv.ZIndex = 999
	rDt = {}
	for i = 1, 60 do local s = dr("Square"); s.Thickness = 0; s.Filled = true; s.Size = v2(4,4); s.ZIndex = 999; table.insert(rDt, s) end
	fovC = dr("Circle"); fovC.Thickness = 1; fovC.Filled = false; fovC.NumSides = 64; fovC.ZIndex = 999
	chLine1 = dr("Line"); chLine1.Thickness = 1.5; chLine1.ZIndex = 999
	chLine2 = dr("Line"); chLine2.Thickness = 1.5; chLine2.ZIndex = 999
	wmText = dr("Text"); wmText.Size = 14; wmText.Outline = true; wmText.ZIndex = 999
end

initDraw()

local C_RD = Color3.new(1, 0.2, 0.2)
local C_GN = Color3.new(0, 1, 0.2)
local c3 = Color3.fromRGB

--===========================================================
-- HIDE/SHOW VIZ
--===========================================================
local function hideViz()
	panicked = true
	for _, b in ipairs(pool.box) do for _, ls in pairs(b) do if typeof(ls) == "Drawing" then ls.Visible = false end end end
	for _, s in ipairs(pool.skel) do for _, l in ipairs(s) do if typeof(l) == "Drawing" then l.Visible = false end end end
	for _, t in pairs(pool) do if t ~= pool.box and t ~= pool.skel then for _, o in pairs(t) do o.Visible = false end end end
	for _, o in pairs(rDt) do o.Visible = false end
	for _, o in ipairs({rBg, rBd, rCt, rPv, fovC, chLine1, chLine2, wmText}) do o.Visible = false end
end

local function showViz()
	panicked = false
end

--===========================================================
-- FULLBRIGHT
--===========================================================
local function doFullbright()
	if not cfg.fullbright then return end
	pcall(function() cam.FieldOfView = 90 end)
	for _, v in ipairs(WS:GetDescendants()) do
		if v:IsA("Lighting") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") then
			v.Enabled = false
		end
		if v:IsA("Atmosphere") then v:Destroy() end
	end
	game:GetService("Lighting").FogEnd = 1e5
	game:GetService("Lighting").Brightness = 2
	game:GetService("Lighting").ClockTime = 14
	game:GetService("Lighting").Ambient = c3(255, 255, 255)
	game:GetService("Lighting").OutdoorAmbient = c3(255, 255, 255)
end

--===========================================================
-- ESP (2D bounding box from all character parts)
--===========================================================
local function getCharESP(p)
	local c = p.Character
	if not c then return end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end
	local min, max = v2(1e9, 1e9), v2(-1e9, -1e9)
	local onscreen = false
	for _, part in ipairs(c:GetDescendants()) do
		if part:IsA("BasePart") then
			local sz = part.Size / 2
			local cf = part.CFrame
			for _, off in ipairs({v3(-sz.X,-sz.Y,-sz.Z), v3(sz.X,-sz.Y,-sz.Z), v3(sz.X,sz.Y,-sz.Z), v3(-sz.X,sz.Y,-sz.Z), v3(-sz.X,-sz.Y,sz.Z), v3(sz.X,-sz.Y,sz.Z), v3(sz.X,sz.Y,sz.Z), v3(-sz.X,sz.Y,sz.Z)}) do
				local pos, vis = cam:WorldToViewportPoint(cf:PointToWorldSpace(off))
				if vis then
					local pv2 = v2(pos.X, pos.Y)
					min = v2(math.min(min.X, pv2.X), math.min(min.Y, pv2.Y))
					max = v2(math.max(max.X, pv2.X), math.max(max.Y, pv2.Y))
					onscreen = true
				end
			end
		end
	end
	if not onscreen then return end
	return min, max, hrp, hum, (cam.CFrame.Position - hrp.Position).Magnitude
end

local function doESP()
	if not cfg.esp or panicked or not _authed then
		for _, b in ipairs(pool.box) do for _, k in ipairs({"t","b","l","r","t_","b_","l_","r_"}) do if b[k] then b[k].Visible = false end end end
		for _, s in ipairs(pool.skel) do for _, l in ipairs(s) do l.Visible = false end end
		for i = 1, #pool.name do
			if typeof(pool.name[i]) == "Drawing" then pool.name[i].Visible = false end
			if typeof(pool.hp[i]) == "Drawing" then pool.hp[i].Visible = false end
			if typeof(pool.dist[i]) == "Drawing" then pool.dist[i].Visible = false end
			if typeof(pool.line[i]) == "Drawing" then pool.line[i].Visible = false end
		end
		if not cfg.esp or panicked or not _authed then return end
	end
	local idx = 0
	local myPos = cam.CFrame.Position
	local plrs = Players:GetPlayers()
	table.sort(plrs, function(a,b)
		local da = a.Character and a.Character:FindFirstChild("HumanoidRootPart") and (a.Character.HumanoidRootPart.Position - myPos).Magnitude or 1e9
		local db = b.Character and b.Character:FindFirstChild("HumanoidRootPart") and (b.Character.HumanoidRootPart.Position - myPos).Magnitude or 1e9
		return da < db
	end)
	for _, p in ipairs(plrs) do
		if p == lp then break end
		if cfg.teamCheck and p.Team == lp.Team then break end
		repeat
		local min, max, hrp, hum, dist = getCharESP(p)
		if not min then break end
		if dist > cfg.maxDist then break end
		idx = idx + 1
		if idx > POOL_SZ then idx = idx - 1; break end
		local col = (cfg.teamCheck and p.Team ~= lp.Team) or not p.Team and C_RD or C_GN
		local mnX, mnY, mxX, mxY = min.X, min.Y, max.X, max.Y
		local w, h = mxX - mnX, mxY - mnY
		local b = pool.box[idx]

		-- Box (corners)
		local wn, hn = w * 0.25, h * 0.25
		b.t_.Visible = true; b.t_.From = v2(mnX-1, mnY-1); b.t_.To = v2(mnX+wn+1, mnY-1); b.t_.Color = c3(col.R*0.4, col.G*0.4, col.B*0.4)
		b.l_.Visible = true; b.l_.From = v2(mnX-1, mnY-1); b.l_.To = v2(mnX-1, mnY+hn+1); b.l_.Color = c3(col.R*0.4, col.G*0.4, col.B*0.4)
		b.r_.Visible = true; b.r_.From = v2(mxX+1, mnY-1); b.r_.To = v2(mxX-wn-1, mnY-1); b.r_.Color = c3(col.R*0.4, col.G*0.4, col.B*0.4)
		b.b_.Visible = true; b.b_.From = v2(mxX+1, mnY-1); b.b_.To = v2(mxX+1, mnY+hn+1); b.b_.Color = c3(col.R*0.4, col.G*0.4, col.B*0.4)
		b.t.Visible = true; b.t.Color = col; b.t.From = v2(mnX, mnY); b.t.To = v2(mnX+wn, mnY)
		b.l.Visible = true; b.l.Color = col; b.l.From = v2(mnX, mnY); b.l.To = v2(mnX, mnY+hn)
		b.r.Visible = true; b.r.Color = col; b.r.From = v2(mxX, mnY); b.r.To = v2(mxX-wn, mnY)
		b.b.Visible = true; b.b.Color = col; b.b.From = v2(mxX, mnY); b.b.To = v2(mxX, mnY+hn)

		-- Name
		if cfg.nameTag then
			local n = pool.name[idx]; n.Text = p.Name; n.Color = col; n.Position = v2(mnX + w/2, mnY - 16); n.Visible = true
		else pool.name[idx].Visible = false end

		-- HP
		if cfg.healthBar then
			local hp = pool.hp[idx]; local hpPct = hum.Health / hum.MaxHealth
			hp.Text = tostring(math.floor(hum.Health)); hp.Color = c3(255*(1-hpPct), 255*hpPct, 0); hp.Position = v2(mnX - 22, mnY + h*0.3); hp.Visible = true
		else pool.hp[idx].Visible = false end

		-- Distance
		if cfg.distance then
			local d = pool.dist[idx]; d.Text = tostring(math.floor(dist)) .. "m"; d.Color = col; d.Position = v2(mnX + w/2, mxY + 4); d.Visible = true
		else pool.dist[idx].Visible = false end

		-- Tracer
		if cfg.tracer then
			local l = pool.line[idx]; l.From = v2(cam.ViewportSize.X/2, cam.ViewportSize.Y); l.To = v2(mnX + w/2, mxY); l.Color = col; l.Visible = true
		else pool.line[idx].Visible = false end

		-- Skeleton
		if cfg.skeleton then
			local sk = pool.skel[idx]
			for j, pair in ipairs(SKEL) do
				local p1 = c:FindFirstChild(pair[1]); local p2 = c:FindFirstChild(pair[2])
				if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
					local pos1, on1 = cam:WorldToViewportPoint(p1.Position)
					local pos2, on2 = cam:WorldToViewportPoint(p2.Position)
					if on1 or on2 then
						sk[j].From = v2(pos1.X, pos1.Y); sk[j].To = v2(pos2.X, pos2.Y); sk[j].Color = col; sk[j].Visible = true
					else sk[j].Visible = false end
				else sk[j].Visible = false end
			end
		else
			for _, l in ipairs(pool.skel[idx]) do l.Visible = false end
		end
		break; until true end
	-- Hide unused pool entries
	for i = idx + 1, POOL_SZ do
		for _, k in ipairs({"t","b","l","r","t_","b_","l_","r_"}) do pool.box[i][k].Visible = false end
		for _, l in ipairs(pool.skel[i]) do l.Visible = false end
		pool.name[i].Visible = false; pool.hp[i].Visible = false; pool.dist[i].Visible = false; pool.line[i].Visible = false
	end
end

--===========================================================
-- AIMBOT
--===========================================================
local aimTarget = nil
local function getClosestToFOV(fovDeg)
	local closest, closestAng = nil, fovDeg
	local sc = cam.ViewportSize / 2
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp and not (cfg.teamCheck and p.Team == lp.Team) then
			local c = p.Character
			if c then
				local part = c:FindFirstChild(cfg.aimPart) or c:FindFirstChild("Head")
				if part and part:IsA("BasePart") then
					local pos, vis = cam:WorldToViewportPoint(part.Position)
					if vis then
						local ang = (v2(pos.X, pos.Y) - sc).Magnitude
						if ang < closestAng then
							closestAng = ang
							closest = {pos=v2(pos.X, pos.Y), part=part, player=p}
						end
					end
				end
			end
		end
	end
	return closest
end

local aimHolding = false
local function doAim()
	if not cfg.aimbot or panicked or not _authed then
		aimTarget = nil; return
	end
	local held = false
	if cfg.aimKey == "MouseButton2" then held = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	elseif cfg.aimKey:find("Mouse") then
		local btn = tonumber(cfg.aimKey:match("%d+")) or 2
		held = UIS:IsMouseButtonPressed(Enum.UserInputType[cfg.aimKey])
	else held = UIS:IsKeyDown(Enum.KeyCode[cfg.aimKey]) end
	if not held then aimHolding = false; aimTarget = nil; return end
	aimHolding = true
	local target = getClosestToFOV(cfg.aimFOV)
	if not target then aimTarget = nil; return end
	aimTarget = target

	-- Wall check
	if cfg.aimWallCheck then
		local ray = Ray.new(cam.CFrame.Position, (target.part.Position - cam.CFrame.Position).Unit * 500)
		local hit = WS:FindPartOnRayWithIgnoreList(ray, {lp.Character, cam})
		if hit and hit:IsA("BasePart") then
			local owner = hit.Parent
			if owner and Players:GetPlayerFromCharacter(owner) ~= target.player then return end
		end
	end

	-- Smooth mousemoverel
	local sc = cam.ViewportSize / 2
	local delta = target.pos - sc
	local smooth = 1 - math.clamp(cfg.aimSmoothness, 0, 1)
	if mousemoverel then
		mousemoverel(delta.X * smooth, delta.Y * smooth)
	end
end

--===========================================================
-- FOV CIRCLE
--===========================================================
local function drawFOV()
	if not cfg.fovCircle or not cfg.aimbot or panicked or not _authed then
		fovC.Visible = false; return
	end
	fovC.Position = cam.ViewportSize / 2
	fovC.Radius = cfg.aimFOV
	fovC.Color = aimTarget and c3(0, 255, 100) or c3(255, 255, 255)
	fovC.Transparency = 0.55
	fovC.Visible = true
end

--===========================================================
-- CROSSHAIR
--===========================================================
local function drawCrosshair()
	if not cfg.crosshair or panicked or not _authed then
		chLine1.Visible = false; chLine2.Visible = false; return
	end
	local sc = cam.ViewportSize / 2; local sz = 10
	chLine1.From = v2(sc.X - sz, sc.Y); chLine1.To = v2(sc.X + sz, sc.Y); chLine1.Color = c3(255,255,255); chLine1.Visible = true
	chLine2.From = v2(sc.X, sc.Y - sz); chLine2.To = v2(sc.X, sc.Y + sz); chLine2.Color = c3(255,255,255); chLine2.Visible = true
end

--===========================================================
-- WATERMARK
--===========================================================
local function drawWatermark()
	if not cfg.watermark or panicked or not _authed then wmText.Visible = false; return end
	wmText.Position = v2(10, 10)
	wmText.Text = "Apex Software | " .. os.date("%H:%M:%S")
	wmText.Color = c3(200, 50, 80)
	wmText.Visible = true
end

--===========================================================
-- ZOOM
--===========================================================
local function doZoom()
	if not cfg.zoom then
		pcall(function() cam.FieldOfView = 90 end); return
	end
	pcall(function() cam.FieldOfView = math.max(10, 90 - cfg.zoomAmount) end)
end

--===========================================================
-- RADAR
--===========================================================
local function doRadar()
	if not cfg.radar or panicked or not _authed then
		rBg.Visible = false; rBd.Visible = false; rCt.Visible = false; rPv.Visible = false
		for i = 1, #rDt do rDt[i].Visible = false end; return
	end
	local rs = cfg.rSize
	local rx = cam.ViewportSize.X - rs - 16
	local ry = cam.ViewportSize.Y - rs - 16
	local myPos = cam.CFrame.Position
	local myCF = cam.CFrame
	local fwd = -myCF.LookVector
	rBg.Size = v2(rs, rs); rBg.Position = v2(rx - rs/2, ry - rs/2); rBg.Color = c3(0,0,0); rBg.Transparency = cfg.rOpacity; rBg.Visible = true
	rBd.Size = v2(rs, rs); rBd.Position = v2(rx - rs/2, ry - rs/2); rBd.Color = c3(55,55,60); rBd.Visible = true
	rCt.Position = v2(rx - 2, ry - 2); rCt.Color = C_GN; rCt.Visible = true
	local la = math.atan2(-fwd.X, -fwd.Z)
	rPv.From = v2(rx, ry); rPv.To = v2(rx + math.sin(la)*32, ry - math.cos(la)*32); rPv.Color = c3(255,255,255); rPv.Visible = true
	local di = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp then
			local c = p.Character
			if c then
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp then
					local rel = myCF:PointToObjectSpace(hrp.Position)
					local sc2 = rs * 0.5 / 80
					local px = rx + math.clamp(rel.X * sc2, -rs/2 + 2, rs/2 - 2)
					local py = ry + math.clamp(-rel.Z * sc2, -rs/2 + 2, rs/2 - 2)
					di = di + 1
					if di <= #rDt then
						rDt[di].Position = v2(px - 2, py - 2); rDt[di].Color = C_RD; rDt[di].Visible = true
					end
				end
			end
		end
	end
	for i = di + 1, #rDt do rDt[i].Visible = false end
end

--===========================================================
-- SEND WEBHOOK
--===========================================================
local function sendWebhook(url, msg)
	if not url then return end
	local body = HttpS:JSONEncode({content = msg, username = "Apex Security"})
	pcall(function() syn.request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body}) end)
	pcall(function() http_request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body}) end)
end

--===========================================================
-- AUTH FLOW
--===========================================================
local function doAuth(key)
	local db = loadKeyDB()
	if not db or not db[key] then return false, "Invalid key" end
	local entry = db[key]
	if entry.frozen then return false, "Key frozen" end
	if os.time() > entry.expires then return false, "Key expired" end
	if not verifySignature(entry) then return false, "Signature mismatch" end
	local hwid = getHWID()
	if entry.hwid == "" then
		entry.hwid = hwid; db[key] = signEntry(entry)
		local raw = HttpS:JSONEncode(db)
		sendWebhook(HWID_WH_URL, "**HWID Bound**\nKey: `"..key.."`\nHWID: `"..hwid.."`\nPlayer: "..lp.Name)
		-- Note: writing back to GitHub isn't done via the script (GitHub API requires token)
		-- The webhook is informational; manual binding or bot handles it
	end
	if entry.hwid ~= hwid then return false, "HWID mismatch" end
	_authed = true
	return true, "Authorized"
end

--===========================================================
-- RENDER LOOP
--===========================================================
task.spawn(function()
	while task.wait(1) do
		if _authed and game.PlaceId ~= 0 then
			doFullbright()
		end
	end
end)

RunS.RenderStepped:Connect(function(dt)
	local ok, err = pcall(function()
		if panicked or not _authed then
			doESP(); drawFOV(); drawCrosshair(); drawWatermark(); doRadar()
			return
		end
		doZoom()
		doESP()
		drawFOV()
		doAim()
		drawCrosshair()
		drawWatermark()
		doRadar()
	end)
	if not ok then print("[Apex Error]", err) end
end)

--===========================================================
-- UI BUILD — ORION LIBRARY
--===========================================================
local Window = OrionLib:MakeWindow({
	Name = "Apex Software",
	HidePremium = true,
	SaveConfig = false,
	IntroEnabled = false,
	CloseCallback = function() hideViz() end,
})

-- COMBAT TAB
local CombatTab = Window:MakeTab({Name = "Combat", Icon = "rbxassetid://4483345998"})
CombatTab:AddToggle({Name = "Aimbot", Default = false, Callback = function(v) cfg.aimbot = v end})
CombatTab:AddSlider({Name = "Smoothness", Min = 0, Max = 1, Default = 0.6, Increment = 0.05, Callback = function(v) cfg.aimSmoothness = v end})
CombatTab:AddSlider({Name = "FOV", Min = 30, Max = 360, Default = 120, Increment = 5, Callback = function(v) cfg.aimFOV = v end})
CombatTab:AddDropdown({Name = "Aim Key", Options = {"MouseButton2","MouseButton1","E","Q","X"}, Default = "MouseButton2", Callback = function(v) cfg.aimKey = v end})
CombatTab:AddDropdown({Name = "Aim Part", Options = {"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, Default = "Head", Callback = function(v) cfg.aimPart = v end})
CombatTab:AddToggle({Name = "Wall Check", Default = false, Callback = function(v) cfg.aimWallCheck = v end})
CombatTab:AddToggle({Name = "FOV Circle", Default = true, Callback = function(v) cfg.fovCircle = v end})

-- VISUALS TAB
local VisualsTab = Window:MakeTab({Name = "Visuals", Icon = "rbxassetid://4483345998"})
VisualsTab:AddToggle({Name = "ESP", Default = false, Callback = function(v) cfg.esp = v end})
VisualsTab:AddToggle({Name = "Name Tags", Default = true, Callback = function(v) cfg.nameTag = v end})
VisualsTab:AddToggle({Name = "Health Bar", Default = true, Callback = function(v) cfg.healthBar = v end})
VisualsTab:AddToggle({Name = "Distance", Default = true, Callback = function(v) cfg.distance = v end})
VisualsTab:AddToggle({Name = "Skeleton", Default = true, Callback = function(v) cfg.skeleton = v end})
VisualsTab:AddToggle({Name = "Tracer Lines", Default = true, Callback = function(v) cfg.tracer = v end})
VisualsTab:AddToggle({Name = "Team Check", Default = true, Callback = function(v) cfg.teamCheck = v end})
VisualsTab:AddSlider({Name = "Max Distance", Min = 50, Max = 500, Default = 200, Increment = 10, Callback = function(v) cfg.maxDist = v end})
VisualsTab:AddSlider({Name = "Box Thickness", Min = 0.5, Max = 3, Default = 1.5, Increment = 0.5, Callback = function(v) cfg.boxThick = v end})
VisualsTab:AddToggle({Name = "Crosshair", Default = false, Callback = function(v) cfg.crosshair = v end})
VisualsTab:AddToggle({Name = "Watermark", Default = false, Callback = function(v) cfg.watermark = v end})
VisualsTab:AddToggle({Name = "Fullbright", Default = false, Callback = function(v) cfg.fullbright = v end})
VisualsTab:AddToggle({Name = "Zoom", Default = false, Callback = function(v) cfg.zoom = v end})
VisualsTab:AddSlider({Name = "Zoom Amount", Min = 10, Max = 70, Default = 40, Increment = 5, Callback = function(v) cfg.zoomAmount = v end})

-- RADAR TAB
local RadarTab = Window:MakeTab({Name = "Radar", Icon = "rbxassetid://4483345998"})
RadarTab:AddToggle({Name = "Radar", Default = false, Callback = function(v) cfg.radar = v end})
RadarTab:AddSlider({Name = "Radar Size", Min = 60, Max = 200, Default = 120, Increment = 10, Callback = function(v) cfg.rSize = v end})
RadarTab:AddSlider({Name = "Opacity", Min = 0, Max = 1, Default = 0.35, Increment = 0.05, Callback = function(v) cfg.rOpacity = v end})

-- SETTINGS TAB
local SettingsTab = Window:MakeTab({Name = "Settings", Icon = "rbxassetid://4483345998"})
SettingsTab:AddLabel("F3 to toggle ESP")
SettingsTab:AddLabel("RightShift to show/hide UI")

-- AUTH
local keyInput = ""
local authStatus = ""
SettingsTab:AddTextbox({Name = "License Key", Default = "", TextDisappear = false, Callback = function(v) keyInput = v end})
SettingsTab:AddButton({Name = "Authenticate", Callback = function()
	if keyInput == "" then OrionLib:MakeNotification({Name="Error", Content="Enter a key", Time=3}); return end
	local ok, msg = doAuth(keyInput)
	OrionLib:MakeNotification({Name=ok and "Success" or "Failed", Content=msg, Time=5})
	if ok then
		OrionLib:MakeNotification({Name="Welcome", Content="Apex authenticated for "..lp.Name, Time=5})
		sendWebhook(WH_URL, "**Login**\nPlayer: "..lp.Name.."\nKey: `"..keyInput.."`\nTime: "..os.date("%c"))
	end
end})

OrionLib:Init()

--===========================================================
-- PANIC / STREAM MODE
--===========================================================
pcall(function()
	local ss = game:GetService("StarterGui")
	ss:SetCore("SendNotification", {Title="Apex", Text="Loaded | F3 = Toggle ESP", Duration=5})
end)

print("|============================================|")
print("|  Apex Software loaded                     |")
print("|  F3 = Toggle ESP                          |")
print("|============================================|")
