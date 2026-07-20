local Players = game:GetService("Players")
local RunS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local HttpS = game:GetService("HttpService")
local lp = Players.LocalPlayer
local cam = WS.CurrentCamera
math.randomseed(tick())

local _authed = false
local panicked = false
local cfg = {
	esp=false, teamCheck=true, maxDist=1000, boxThick=1, boxStyle="Corner",
	nameTag=true, healthBar=true, distance=true, skeleton=false, tracer=false,
	tracerOrigin="Bottom",
	aimbot=false, aimKey="MouseButton2", aimSmoothness=0.6, aimFOV=120, aimPart="Head", aimWallCheck=false, fovCircle=true,
	crosshair=false, zoom=false, zoomAmount=40, watermark=false, fullbright=false,
	radar=false, rSize=120, rOpacity=0.35,
}
local KEYS_URL = "https://raw.githubusercontent.com/ddrasinx-cloud/DurkLoader/master/keys.json?cb="..math.random()
local HWID_WH_URL = "https://discord.com/api/webhooks/1528565316731277372/9EhpNUgIiDeKMt5T-mKZ9Walgwi1Rrxktrpgkhx8yzQ6NCRZfYCPeabAxMnj7ut8QfzB"
local KEY_LOG_WH_URL = "https://discord.com/api/webhooks/1528565312851808397/P3gV08jiS_WHfycFNgksOBYqXms-kLc1kZFyYOs9PM4hKpHLkUDV9cv3dEYV9ee3JcYe"
local _SECRET_SALT = "Apex1.0_X7k9m2pQ"
local c3 = Color3.fromRGB

local function sha256(raw)
	local ok, ret = pcall(function() return syn and syn.crypt and syn.crypt.hash and syn.crypt.hash("sha256", raw) or nil end)
	if ok and ret then return ret end
	ok, ret = pcall(function() return HttpS:SHA256(raw) end)
	if ok and ret then return ret end
	return raw
end

local function getHWID() return sha256(tostring(lp.UserId)..":"..game.GameId) end

local function fetchKeys()
	local body
	pcall(function() body = game:HttpGet(KEYS_URL, true) end)
	if not body then pcall(function() body = HttpS:GetAsync(KEYS_URL, true) end) end
	if not body then
		for _, fn in ipairs({"syn.request","request","http_request"}) do
			pcall(function()
				local r = loadstring("return "..fn)()({Url=KEYS_URL, Method="GET"})
				if r and r.StatusCode==200 and r.Body and #r.Body>0 then body=r.Body end
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
	if ok and type(db)=="table" then return db end
	return {}
end

local function verifySignature(entry)
	local sig = entry.sig
	if not sig then return true end
	local clean = {created=entry.created, expires=entry.expires, duration=entry.duration, frozen=entry.frozen, hwid=entry.hwid}
	return sig == sha256(HttpS:JSONEncode(clean)..":".._SECRET_SALT)
end

local DColors = {green=5763719, red=15548997, blue=3447003, orange=15105570, purple=10181046}
local function sendEmbed(url, title, desc, color, fields)
	if not url or url=="" then return end
	local embed = {title=title, description=desc, color=color or DColors.blue, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"), footer={text="Apex Software"}}
	if fields then embed.fields=fields end
	local p = HttpS:JSONEncode({username="Apex Security", embeds={embed}})
	pcall(function() syn.request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=p}) end)
	pcall(function() http_request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=p}) end)
end

local function doAuth(key)
	local db = loadKeyDB()
	if not db or not db[key] then return false, "Invalid key" end
	local entry = db[key]
	if entry.frozen then return false, "Key frozen" end
	if entry.expires and os.time()>entry.expires then return false, "Key expired" end
	if not verifySignature(entry) then return false, "Signature mismatch" end
	local hwid = getHWID()
	local cacheOk, cache = pcall(function() return HttpS:JSONDecode(readfile("ApexHWIDCache.json")) end)
	if not cacheOk or type(cache)~="table" then cache={} end
	if entry.hwid=="" then
		if not cache[key] or cache[key]~=hwid then
			cache[key]=hwid
			pcall(function() writefile("ApexHWIDCache.json", HttpS:JSONEncode(cache)) end)
			sendEmbed(HWID_WH_URL, "HWID Bound", nil, DColors.blue, {
				{name="Player", value=lp.Name, inline=true},
				{name="Key", value="`"..key.."`", inline=true},
				{name="HWID", value="`"..hwid.."`", inline=false},
			})
		end
	end
	if entry.hwid~="" and entry.hwid~=hwid then return false, "HWID mismatch" end
	_authed=true
	return true, "Authorized"
end

local v2 = Vector2.new
local v3 = Vector3.new
local drOk = pcall(Drawing.new, "Line")
local function dr(t) if drOk then return Drawing.new(t) end return {Visible=false} end

-- Drawing pool
local POOL = 30
local pool = {box={}, name={}, hp={}, dist={}, line={}, skel={}}

local function initDraw()
	for i = 1, POOL do
		local b = {}
		for _, k in ipairs({"tl","tr","bl","br","lt","rt","lb","rb","lt_","rt_","lb_","rb_"}) do
			b[k] = dr("Line"); pcall(function() b[k].Thickness=1; b[k].ZIndex=999 end)
		end
		pool.box[i] = b
		pool.name[i] = dr("Text"); pcall(function() pool.name[i].Size=14; pool.name[i].Center=true; pool.name[i].ZIndex=999 end)
		pool.hp[i] = dr("Text"); pcall(function() pool.hp[i].Size=12; pool.hp[i].Center=true; pool.hp[i].ZIndex=999 end)
		pool.dist[i] = dr("Text"); pcall(function() pool.dist[i].Size=11; pool.dist[i].Center=true; pool.dist[i].ZIndex=999 end)
		pool.line[i] = dr("Line"); pcall(function() pool.line[i].Thickness=1; pool.line[i].ZIndex=999 end)
	end
	for i = 1, POOL do
		local s = {}
		for j = 1, 14 do s[j] = dr("Line"); pcall(function() s[j].Thickness=1.5; s[j].ZIndex=999 end) end
		pool.skel[i] = s
	end
end

local rBg, rBd, rCt, rPv, rDt, fovC, chLine1, chLine2, wmText
local function initAllDraw()
	initDraw()
	rBg = dr("Square"); pcall(function() rBg.Thickness=1; rBg.Filled=true; rBg.ZIndex=999 end)
	rBd = dr("Square"); pcall(function() rBd.Thickness=2; rBd.Filled=false; rBd.ZIndex=999 end)
	rCt = dr("Square"); pcall(function() rCt.Thickness=0; rCt.Filled=true; rCt.Size=v2(4,4); rCt.ZIndex=999 end)
	rPv = dr("Line"); pcall(function() rPv.Thickness=2; rPv.ZIndex=999 end)
	rDt = {}; for i=1,60 do rDt[i]=dr("Square"); pcall(function() rDt[i].Thickness=0; rDt[i].Filled=true; rDt[i].Size=v2(4,4); rDt[i].ZIndex=999 end) end
	fovC = dr("Circle"); pcall(function() fovC.Thickness=1; fovC.Filled=false; fovC.NumSides=64; fovC.ZIndex=999 end)
	chLine1 = dr("Line"); pcall(function() chLine1.Thickness=1.5; chLine1.ZIndex=999 end)
	chLine2 = dr("Line"); pcall(function() chLine2.Thickness=1.5; chLine2.ZIndex=999 end)
	wmText = dr("Text"); pcall(function() wmText.Size=14; wmText.ZIndex=999 end)
end
initAllDraw()

local C_RD = Color3.new(1, 0.2, 0.2)
local C_GN = Color3.new(0, 1, 0.2)

-- ESP
local SKEL = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}

local function getScreenBox(c)
	local hrp = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health<=0 then return end
	local pos, on = cam:WorldToViewportPoint(hrp.Position)
	if not on then return end
	local dist = (hrp.Position - cam.CFrame.Position).Magnitude
	local sz = c:GetExtentsSize()
	local cf = hrp.CFrame
	local top, tOn = cam:WorldToViewportPoint((cf*CFrame.new(0,sz.Y/2,0)).Position)
	local bot, bOn = cam:WorldToViewportPoint((cf*CFrame.new(0,-sz.Y/2,0)).Position)
	if not tOn or not bOn then return end
	local scH = bot.Y - top.Y
	if scH<5 then return end
	local scW = scH * 0.65
	local ox, oy = top.X - scW/2, top.Y
	return ox, oy, scW, scH, hrp, hum, dist, cf, sz
end

local C_RD2 = Color3.new(1,0.2,0.2)
local C_GN2 = Color3.new(0,1,0.2)

local function doESP()
	if not cfg.esp or panicked or not _authed then
		for i=1,POOL do
			for _,k in ipairs({"tl","tr","bl","br","lt","rt","lb","rb","lt_","rt_","lb_","rb_"}) do
				if pool.box[i][k] then pool.box[i][k].Visible=false end
			end
			for j=1,14 do if pool.skel[i][j] then pool.skel[i][j].Visible=false end end
			pool.name[i].Visible=false; pool.hp[i].Visible=false; pool.dist[i].Visible=false; pool.line[i].Visible=false
		end
		return
	end
	local idx, myPos = 0, cam.CFrame.Position
	local plrs = Players:GetPlayers()
	for i=1,#plrs do for j=i+1,#plrs do
		local a,b=plrs[i],plrs[j]
		local da = a.Character and a.Character:FindFirstChild("HumanoidRootPart") and (a.Character.HumanoidRootPart.Position-myPos).Magnitude or 1e9
		local db = b.Character and b.Character:FindFirstChild("HumanoidRootPart") and (b.Character.HumanoidRootPart.Position-myPos).Magnitude or 1e9
		if da>db then plrs[i],plrs[j]=plrs[j],plrs[i] end
	end end
	for _,p in ipairs(plrs) do
		if p==lp then break end
		if cfg.teamCheck and p.Team==lp.Team then break end
		local c = p.Character
		if not c then break end
		local ox, oy, scW, scH, hrp, hum, dist, cf, sz = getScreenBox(c)
		if not ox then break end
		if dist>cfg.maxDist then break end
		idx=idx+1; if idx>POOL then break end
		local col = (cfg.teamCheck and p.Team~=lp.Team) or not p.Team and C_RD2 or C_GN2
		local b = pool.box[idx]
		-- Corner box
		local cn = scW*0.2
		-- top-left corner L
		b.tl.Visible=true; b.tl.From=v2(ox,oy); b.tl.To=v2(ox+cn,oy); b.tl.Color=col
		-- top-left corner |
		b.lt.Visible=true; b.lt.From=v2(ox,oy); b.lt.To=v2(ox,oy+cn); b.lt.Color=col
		-- top-right corner L
		b.tr.Visible=true; b.tr.From=v2(ox+scW,oy); b.tr.To=v2(ox+scW-cn,oy); b.tr.Color=col
		-- top-right corner |
		b.rt.Visible=true; b.rt.From=v2(ox+scW,oy); b.rt.To=v2(ox+scW,oy+cn); b.rt.Color=col
		-- bottom-left corner L
		b.bl.Visible=true; b.bl.From=v2(ox,oy+scH); b.bl.To=v2(ox+cn,oy+scH); b.bl.Color=col
		-- bottom-left corner |
		b.lb.Visible=true; b.lb.From=v2(ox,oy+scH); b.lb.To=v2(ox,oy+scH-cn); b.lb.Color=col
		-- bottom-right corner L
		b.br.Visible=true; b.br.From=v2(ox+scW,oy+scH); b.br.To=v2(ox+scW-cn,oy+scH); b.br.Color=col
		-- bottom-right corner |
		b.rb.Visible=true; b.rb.From=v2(ox+scW,oy+scH); b.rb.To=v2(ox+scW,oy+scH-cn); b.rb.Color=col
		-- dim parts hidden
		b.lt_.Visible=false; b.rt_.Visible=false; b.lb_.Visible=false; b.rb_.Visible=false
		-- Name
		if cfg.nameTag then
			pool.name[idx].Text=p.Name; pool.name[idx].Color=col; pool.name[idx].Position=v2(ox+scW/2,oy-16); pool.name[idx].Visible=true
		else pool.name[idx].Visible=false end
		-- HP text
		if cfg.healthBar then
			local hpPct = hum.Health/hum.MaxHealth
			pool.hp[idx].Text=tostring(math.floor(hum.Health))
			pool.hp[idx].Color=c3(math.floor(255*(1-hpPct)), math.floor(255*hpPct), 0)
			pool.hp[idx].Position=v2(ox-22,oy+scH*0.3); pool.hp[idx].Visible=true
		else pool.hp[idx].Visible=false end
		-- Distance
		if cfg.distance then
			pool.dist[idx].Text=tostring(math.floor(dist)).."m"; pool.dist[idx].Color=col
			pool.dist[idx].Position=v2(ox+scW/2,oy+scH+4); pool.dist[idx].Visible=true
		else pool.dist[idx].Visible=false end
		-- Tracer
		if cfg.tracer then
			local tx, ty
			if cfg.tracerOrigin=="Bottom" then tx,ty=cam.ViewportSize.X/2,cam.ViewportSize.Y
			elseif cfg.tracerOrigin=="Top" then tx,ty=cam.ViewportSize.X/2,0
			elseif cfg.tracerOrigin=="Mouse" then tx,ty=UIS:GetMouseLocation().X,UIS:GetMouseLocation().Y
			else tx,ty=cam.ViewportSize.X/2,cam.ViewportSize.Y/2 end
			pool.line[idx].From=v2(tx,ty); pool.line[idx].To=v2(ox+scW/2,oy+scH)
			pool.line[idx].Color=col; pool.line[idx].Visible=true
		else pool.line[idx].Visible=false end
		-- Skeleton
		if cfg.skeleton and c then
			for j,pair in ipairs(SKEL) do
				local p1=c:FindFirstChild(pair[1]); local p2=c:FindFirstChild(pair[2])
				if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
					local s1,o1=cam:WorldToViewportPoint(p1.Position); local s2,o2=cam:WorldToViewportPoint(p2.Position)
					if o1 and o2 then
						pool.skel[idx][j].From=v2(s1.X,s1.Y); pool.skel[idx][j].To=v2(s2.X,s2.Y)
						pool.skel[idx][j].Color=col; pool.skel[idx][j].Visible=true
					else pool.skel[idx][j].Visible=false end
				else pool.skel[idx][j].Visible=false end
			end
		else for j=1,14 do pool.skel[idx][j].Visible=false end end
	end
	for i=idx+1,POOL do
		for _,k in ipairs({"tl","tr","bl","br","lt","rt","lb","rb","lt_","rt_","lb_","rb_"}) do pool.box[i][k].Visible=false end
		for j=1,14 do pool.skel[i][j].Visible=false end
		pool.name[i].Visible=false; pool.hp[i].Visible=false; pool.dist[i].Visible=false; pool.line[i].Visible=false
	end
end

-- Aimbot
local function getClosest(fovDeg)
	local closest, closestAng, sc = nil, fovDeg, cam.ViewportSize/2
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=lp and not (cfg.teamCheck and p.Team==lp.Team) then
			local c=p.Character
			if c then
				local part = c:FindFirstChild(cfg.aimPart) or c:FindFirstChild("Head")
				if part and part:IsA("BasePart") then
					local pos, vis = cam:WorldToViewportPoint(part.Position)
					if vis then
						local ang = (v2(pos.X,pos.Y)-sc).Magnitude
						if ang<closestAng then closestAng=ang; closest={pos=v2(pos.X,pos.Y), part=part, player=p} end
					end
				end
			end
		end
	end
	return closest
end

local function doAim()
	if not cfg.aimbot or panicked or not _authed then return end
	local held
	if cfg.aimKey=="MouseButton2" then held=UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	elseif cfg.aimKey:find("Mouse") then held=UIS:IsMouseButtonPressed(Enum.UserInputType[cfg.aimKey])
	else held=UIS:IsKeyDown(Enum.KeyCode[cfg.aimKey]) end
	if not held then return end
	local target = getClosest(cfg.aimFOV)
	if not target then return end
	if cfg.aimWallCheck then
		local ray = Ray.new(cam.CFrame.Position, (target.part.Position-cam.CFrame.Position).Unit*500)
		local hit = WS:FindPartOnRayWithIgnoreList(ray, {lp.Character,cam})
		if hit and hit:IsA("BasePart") then
			local owner = hit.Parent
			if owner and Players:GetPlayerFromCharacter(owner)~=target.player then return end
		end
	end
	local delta = target.pos - cam.ViewportSize/2
	local smooth = 1 - math.max(0, math.min(1, cfg.aimSmoothness))
	if mousemoverel then mousemoverel(delta.X*smooth, delta.Y*smooth) end
end

-- FOV
local function drawFOV()
	if not cfg.fovCircle or not cfg.aimbot or panicked or not _authed then fovC.Visible=false; return end
	fovC.Position=cam.ViewportSize/2; fovC.Radius=cfg.aimFOV; fovC.Color=c3(255,255,255); fovC.Transparency=0.55; fovC.Visible=true
end

-- Crosshair
local function drawCrosshair()
	if not cfg.crosshair or panicked or not _authed then chLine1.Visible=false; chLine2.Visible=false; return end
	local sc=cam.ViewportSize/2; local sz=10
	chLine1.From=v2(sc.X-sz,sc.Y); chLine1.To=v2(sc.X+sz,sc.Y); chLine1.Color=c3(255,255,255); chLine1.Visible=true
	chLine2.From=v2(sc.X,sc.Y-sz); chLine2.To=v2(sc.X,sc.Y+sz); chLine2.Color=c3(255,255,255); chLine2.Visible=true
end

-- Watermark
local function drawWatermark()
	if not cfg.watermark or panicked or not _authed then wmText.Visible=false; return end
	wmText.Position=v2(10,10); wmText.Text="Apex Software | "..os.date("%H:%M:%S"); wmText.Color=c3(200,50,80); wmText.Visible=true
end

-- Zoom
local function doZoom()
	if not cfg.zoom then pcall(function() cam.FieldOfView=90 end); return end
	pcall(function() cam.FieldOfView=math.max(10,90-cfg.zoomAmount) end)
end

-- Fullbright
local function doFullbright()
	if not cfg.fullbright then return end
	pcall(function() cam.FieldOfView=90 end)
	for _,v in ipairs(WS:GetDescendants()) do
		if v:IsA("Lighting") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") then pcall(function() v.Enabled=false end) end
		if v:IsA("Atmosphere") then pcall(function() v:Destroy() end) end
	end
	game:GetService("Lighting").FogEnd=1e5; game:GetService("Lighting").Brightness=2; game:GetService("Lighting").ClockTime=14
	game:GetService("Lighting").Ambient=Color3.new(1,1,1); game:GetService("Lighting").OutdoorAmbient=Color3.new(1,1,1)
end

-- Radar
local function doRadar()
	if not cfg.radar or panicked or not _authed then
		rBg.Visible=false; rBd.Visible=false; rCt.Visible=false; rPv.Visible=false
		for i=1,60 do rDt[i].Visible=false end; return
	end
	local rs=cfg.rSize; local rx=cam.ViewportSize.X-rs-16; local ry=cam.ViewportSize.Y-rs-16
	local myCF=cam.CFrame; local fwd=-myCF.LookVector
	rBg.Size=v2(rs,rs); rBg.Position=v2(rx-rs/2,ry-rs/2); rBg.Color=c3(0,0,0); rBg.Transparency=cfg.rOpacity; rBg.Visible=true
	rBd.Size=v2(rs,rs); rBd.Position=v2(rx-rs/2,ry-rs/2); rBd.Color=c3(55,55,60); rBd.Visible=true
	rCt.Position=v2(rx-2,ry-2); rCt.Color=C_GN; rCt.Visible=true
	local la=math.atan2(-fwd.X,-fwd.Z)
	rPv.From=v2(rx,ry); rPv.To=v2(rx+math.sin(la)*32,ry-math.cos(la)*32); rPv.Color=c3(255,255,255); rPv.Visible=true
	local di=0
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=lp then
			local c=p.Character
			if c then
				local hrp=c:FindFirstChild("HumanoidRootPart")
				if hrp then
					local rel=myCF:PointToObjectSpace(hrp.Position)
					local sc2=rs*0.5/80; local cl=function(v,lo,hi) return math.max(lo,math.min(hi,v)) end
					local px=rx+cl(rel.X*sc2,-rs/2+2,rs/2-2); local py=ry+cl(-rel.Z*sc2,-rs/2+2,rs/2-2)
					di=di+1; if di<=60 then rDt[di].Position=v2(px-2,py-2); rDt[di].Color=C_RD; rDt[di].Visible=true end
				end
			end
		end
	end
	for i=di+1,60 do rDt[i].Visible=false end
end

-- Auth GUI
local keyGui=Instance.new("ScreenGui"); keyGui.Name="ApexKeyGui"; keyGui.ResetOnSpawn=false
local par=pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or lp:WaitForChild("PlayerGui")
keyGui.Parent=par
local ov=Instance.new("Frame"); ov.BackgroundColor3=Color3.new(0,0,0); ov.BackgroundTransparency=0.5; ov.Size=UDim2.new(1,0,1,0); ov.Parent=keyGui
local bg=Instance.new("Frame"); bg.BackgroundColor3=c3(15,14,22); bg.BorderSizePixel=0; bg.Size=UDim2.new(0,360,0,240); bg.Position=UDim2.new(0.5,-180,0.5,-120); bg.Parent=keyGui
pcall(function() Instance.new("UICorner",bg).CornerRadius=UDim.new(0,12) end)
pcall(function() local s=Instance.new("UIStroke",bg); s.Color=c3(200,30,60); s.Thickness=1.5; s.Transparency=0.4 end)
local ttl=Instance.new("TextLabel"); ttl.BackgroundTransparency=1; ttl.Size=UDim2.new(1,0,0,50); ttl.Text="Apex Software"; ttl.TextColor3=c3(220,50,80); ttl.Font=Enum.Font.GothamBlack; ttl.TextSize=24; ttl.Parent=bg
local sub=Instance.new("TextLabel"); sub.BackgroundTransparency=1; sub.Size=UDim2.new(1,-40,0,20); sub.Position=UDim2.new(0,20,0,48); sub.Text="Enter your license key"; sub.TextColor3=c3(140,140,150); sub.Font=Enum.Font.Gotham; sub.TextSize=13; sub.TextXAlignment=Enum.TextXAlignment.Left; sub.Parent=bg
local kb=Instance.new("TextBox"); kb.BackgroundColor3=c3(25,24,34); kb.BorderSizePixel=0; kb.Size=UDim2.new(1,-40,0,38); kb.Position=UDim2.new(0,20,0,75); kb.PlaceholderText="License Key"; kb.PlaceholderColor3=c3(100,100,110); kb.Text=""; kb.TextColor3=c3(220,220,230); kb.Font=Enum.Font.Gotham; kb.TextSize=15; kb.TextXAlignment=Enum.TextXAlignment.Center; kb.ClearTextOnFocus=false; kb.Parent=bg
pcall(function() Instance.new("UICorner",kb).CornerRadius=UDim.new(0,6) end)
local st=Instance.new("TextLabel"); st.BackgroundTransparency=1; st.Size=UDim2.new(1,-40,0,20); st.Position=UDim2.new(0,20,0,118); st.Text=""; st.TextColor3=c3(200,50,50); st.Font=Enum.Font.Gotham; st.TextSize=12; st.TextXAlignment=Enum.TextXAlignment.Center; st.Parent=bg
local btn=Instance.new("TextButton"); btn.BackgroundColor3=c3(200,30,60); btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.Size=UDim2.new(1,-40,0,42); btn.Position=UDim2.new(0,20,0,145); btn.Text="AUTHENTICATE"; btn.TextColor3=c3(255,255,255); btn.Font=Enum.Font.GothamBold; btn.TextSize=14; btn.Parent=bg
pcall(function() Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6) end)
btn.MouseEnter:Connect(function() pcall(function() TS:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=c3(230,50,80)}):Play() end) end)
btn.MouseLeave:Connect(function() pcall(function() TS:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=c3(200,30,60)}):Play() end) end)

local function doAuthUI()
	local key = kb.Text:match("^%s*(.-)%s*$")
	if key=="" then st.Text="Enter a license key"; return end
	btn.Text="VERIFYING..."; btn.BackgroundColor3=c3(100,100,110); btn.Active=false
	local ok, msg = doAuth(key)
	if ok then
		st.TextColor3=c3(80,220,80); st.Text="Authorized! Loading..."
		keyGui:Destroy()
		sendEmbed(KEY_LOG_WH_URL, "Login", nil, DColors.green, {{name="Player", value=lp.Name, inline=true},{name="HWID", value="`"..getHWID().."`", inline=true},{name="Key", value="`"..key.."`", inline=false}})
		task.wait(0.3)
		local bOk, bErr = pcall(buildUI)
		if bOk then
			task.spawn(function() while task.wait(1) do if _authed and game.PlaceId~=0 then doFullbright() end end end)
			RunS.RenderStepped:Connect(function()
				local eOk, eErr = pcall(function()
					if panicked or not _authed then doESP(); drawFOV(); drawCrosshair(); drawWatermark(); doRadar(); return end
					doZoom(); doESP(); drawFOV(); doAim(); drawCrosshair(); drawWatermark(); doRadar()
				end)
				if not eOk then print("[Apex]", eErr) end
			end)
		else warn("[Apex] UI Build Error:", bErr) end
	else
		st.TextColor3=c3(220,60,60); st.Text=msg; btn.Text="AUTHENTICATE"; btn.BackgroundColor3=c3(200,30,60); btn.Active=true
	end
end
btn.MouseButton1Click:Connect(doAuthUI)
kb.FocusLost:Connect(function(enter) if enter then doAuthUI() end end)

-- UI Build
local u2 = UDim2.new
local function newI(ct,props) local o=Instance.new(ct); for k,v in pairs(props) do o[k]=v end; return o end
local function addCorner(p,r) pcall(function() Instance.new("UICorner",p).CornerRadius=UDim.new(0,r or 6) end) end
local function addStroke(p,c,t) pcall(function() local s=Instance.new("UIStroke",p); s.Color=c or c3(200,30,60); s.Thickness=t or 1 end) end

local function addToggle(p,name,def,cb)
	local b=newI("TextButton",{Text="",BackgroundTransparency=1,Size=u2(1,0,0,26),Parent=p})
	local l=newI("TextLabel",{Text=name,TextColor3=c3(200,200,210),Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=u2(1,-40,0,26),Position=u2(0,10,0,0),Parent=b})
	local ch=newI("Frame",{BackgroundColor3=def and c3(200,50,80) or c3(40,40,50),Size=u2(0,22,0,22),Position=u2(1,-32,0,2),Parent=b}); addCorner(ch,11)
	local ci=newI("Frame",{BackgroundColor3=c3(255,255,255),Size=u2(0,16,0,16),Position=u2(0,3,0,3),Parent=ch}); addCorner(ci,8)
	local on=def; if on then ci.Visible=true end
	b.MouseButton1Click:Connect(function() on=not on; ch.BackgroundColor3=on and c3(200,50,80) or c3(40,40,50); ci.Visible=on; cb(on) end)
end

local function addSlider(p,name,mn,mx,def,cb)
	local f=newI("Frame",{BackgroundTransparency=1,Size=u2(1,0,0,50),Parent=p})
	local l=newI("TextLabel",{Text=name..": "..def,TextColor3=c3(180,180,190),Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=u2(1,-20,0,18),Position=u2(0,10,0,4),Parent=f})
	local bg=newI("Frame",{BackgroundColor3=c3(40,40,50),Size=u2(1,-20,0,6),Position=u2(0,10,0,30),Parent=f}); addCorner(bg,3)
	local fl=newI("Frame",{BackgroundColor3=c3(200,50,80),Size=u2((def-mn)/(mx-mn),0,1,0),Parent=bg}); addCorner(fl,3)
	local val=def; local drg=false
	local function upd(v)
		val=math.max(mn,math.min(mx,math.floor(v/(mx-mn)*1000+0.5)/1000*(mx-mn)+mn))
		fl.Size=u2((val-mn)/(mx-mn),0,1,0); l.Text=name..": "..math.floor(val*100)/100; cb(val)
	end
	bg.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
			drg=true; upd(mn+(inp.Position.X-bg.AbsolutePosition.X)/bg.AbsoluteSize.X*(mx-mn))
		end
	end)
	bg.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then drg=false end end)
	bg.MouseMoved:Connect(function(px) if drg then upd(mn+(px-bg.AbsolutePosition.X)/bg.AbsoluteSize.X*(mx-mn)) end end)
end

local function addDD(p,name,opts,def,cb)
	local f=newI("Frame",{BackgroundTransparency=1,Size=u2(1,0,0,66),Parent=p})
	local l=newI("TextLabel",{Text=name,TextColor3=c3(180,180,190),Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=u2(1,-20,0,18),Position=u2(0,10,0,2),Parent=f})
	local bb=newI("TextButton",{Text=def,TextColor3=c3(200,200,210),Font=Enum.Font.Gotham,TextSize=13,BackgroundColor3=c3(30,30,40),Size=u2(1,-20,0,24),Position=u2(0,10,0,22),Parent=f}); addCorner(bb,4)
	local open,dd=false
	bb.MouseButton1Click:Connect(function()
		open=not open
		if open then
			local n=#opts; if n>5 then n=5 end
			dd=newI("ScrollingFrame",{BackgroundColor3=c3(20,20,30),BorderSizePixel=0,Size=u2(1,-20,0,n*22),Position=u2(0,10,0,50),Parent=f,CanvasSize=u2(0,#opts*22,0,0),ScrollBarThickness=4})
			addCorner(dd,4)
			for _,o in ipairs(opts) do
				local ob=newI("TextButton",{Text=o,TextColor3=c3(180,180,190),Font=Enum.Font.Gotham,TextSize=12,BackgroundColor3=c3(25,25,35),Size=u2(1,0,0,22),Parent=dd})
				ob.MouseButton1Click:Connect(function() cb(o); bb.Text=o; open=false; dd:Destroy() end)
				ob.MouseEnter:Connect(function() ob.BackgroundColor3=c3(40,40,55) end)
				ob.MouseLeave:Connect(function() ob.BackgroundColor3=c3(25,25,35) end)
			end
		elseif dd then dd:Destroy() end
	end)
end

local function addLbl(p,t)
	newI("TextLabel",{Text=t,TextColor3=c3(160,160,170),Font=Enum.Font.Gotham,TextSize=12,BackgroundTransparency=1,Size=u2(1,-20,0,20),Position=u2(0,10,0,0),Parent=p,TextXAlignment=Enum.TextXAlignment.Left})
end

function buildUI()
	local p = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or lp:WaitForChild("PlayerGui")
	local gui = newI("ScreenGui",{Name="ApexUI",ResetOnSpawn=false,Parent=p})
	local main = newI("Frame",{
		BackgroundColor3=c3(12,11,18),Size=u2(0,520,0,380),Position=u2(0.5,-260,0.5,-190),
		Parent=gui,ClipsDescendants=true,Active=true,BorderSizePixel=0
	}); addCorner(main,8); addStroke(main,c3(200,30,60),1.5)
	local tb = newI("TextLabel",{Text="Apex Software",TextColor3=c3(220,50,80),Font=Enum.Font.GothamBlack,TextSize=18,BackgroundTransparency=1,Size=u2(1,0,0,34),Parent=main,Active=true})
	local dragging, dragOff
	tb.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true; dragOff=v2(UIS:GetMouseLocation().X-main.AbsolutePosition.X, UIS:GetMouseLocation().Y-main.AbsolutePosition.Y)
		end
	end)
	tb.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
	UIS.InputChanged:Connect(function(inp,g)
		if dragging and not g and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local ml=UIS:GetMouseLocation(); main.Position=u2(0,ml.X-dragOff.X,0,ml.Y-dragOff.Y)
		end
	end)
	local tabBar = newI("Frame",{BackgroundColor3=c3(18,17,26),Size=u2(0,110,1,-38),Position=u2(0,0,0,36),Parent=main})
	local tabCont = newI("Frame",{BackgroundTransparency=1,Size=u2(1,-120,1,-38),Position=u2(0,118,0,36),Parent=main})
	local panels = {}
	local active
	local tabDefs = {
		{"Aimbot",{
			{"Toggle","Aimbot",false,function(v)cfg.aimbot=v end},
			{"Slider","Smoothness",0,1,0.6,function(v)cfg.aimSmoothness=v end},
			{"Slider","FOV",30,360,120,function(v)cfg.aimFOV=v end},
			{"Dropdown","Aim Key",{"MouseButton2","MouseButton1","E","Q","X"},"MouseButton2",function(v)cfg.aimKey=v end},
			{"Dropdown","Target Part",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"},"Head",function(v)cfg.aimPart=v end},
			{"Toggle","Wall Check",false,function(v)cfg.aimWallCheck=v end},
			{"Toggle","FOV Circle",true,function(v)cfg.fovCircle=v end},
		}},
		{"Visuals",{
			{"Toggle","ESP",false,function(v)cfg.esp=v end},
			{"Toggle","Team Check",true,function(v)cfg.teamCheck=v end},
			{"Slider","Max Distance",50,1000,200,function(v)cfg.maxDist=v end},
			{"Toggle","Name Tags",true,function(v)cfg.nameTag=v end},
			{"Toggle","Health Bar",true,function(v)cfg.healthBar=v end},
			{"Toggle","Distance",true,function(v)cfg.distance=v end},
			{"Toggle","Skeleton",false,function(v)cfg.skeleton=v end},
			{"Toggle","Tracers",false,function(v)cfg.tracer=v end},
			{"Dropdown","Tracer Origin",{"Bottom","Top","Mouse","Center"},"Bottom",function(v)cfg.tracerOrigin=v end},
			{"Toggle","Crosshair",false,function(v)cfg.crosshair=v end},
			{"Toggle","Watermark",false,function(v)cfg.watermark=v end},
			{"Toggle","Fullbright",false,function(v)cfg.fullbright=v end},
			{"Toggle","Zoom",false,function(v)cfg.zoom=v end},
			{"Slider","Zoom Amount",10,70,40,function(v)cfg.zoomAmount=v end},
		}},
		{"Radar",{
			{"Toggle","Radar",false,function(v)cfg.radar=v end},
			{"Slider","Radar Size",60,200,120,function(v)cfg.rSize=v end},
			{"Slider","Opacity",0,1,0.35,function(v)cfg.rOpacity=v end},
		}},
		{"Settings",{
			{"Label","F3 - Toggle ESP"},{"Label","Right Shift - Show/Hide UI"},{"Label","End - Unload"},
		}},
	}
	for ti,td in ipairs(tabDefs) do
		local pan = newI("ScrollingFrame",{BackgroundTransparency=1,Size=u2(1,0,1,0),Parent=tabCont,Visible=false,CanvasSize=u2(0,0,0,0),ScrollBarThickness=4,ClipsDescendants=true,BorderSizePixel=0})
		panels[td[1]] = pan
		for _,ctl in ipairs(td[2]) do
			local a={}; for i=2,#ctl do a[#a+1]=ctl[i] end
			newI("Frame",{BackgroundTransparency=1,Size=u2(1,0,0,4),Parent=pan})
			if ctl[1]=="Toggle" then addToggle(pan,a[1],a[2],a[3])
			elseif ctl[1]=="Slider" then addSlider(pan,a[1],a[2],a[3],a[4],a[5])
			elseif ctl[1]=="Dropdown" then addDD(pan,a[1],a[2],a[3],a[4])
			elseif ctl[1]=="Label" then addLbl(pan,a[1]) end
		end
		local tbb = newI("TextButton",{Text=td[1],TextColor3=c3(140,140,150),Font=Enum.Font.Gotham,TextSize=12,BackgroundColor3=c3(18,17,26),Size=u2(1,0,0,32),Parent=tabBar})
		tbb.MouseEnter:Connect(function() if active~=td[1] then tbb.BackgroundColor3=c3(30,28,42) end end)
		tbb.MouseLeave:Connect(function() if active~=td[1] then tbb.BackgroundColor3=c3(18,17,26) end end)
		tbb.MouseButton1Click:Connect(function()
			if active and panels[active] then panels[active].Visible=false end
			active=td[1]; pan.Visible=true; tbb.BackgroundColor3=c3(200,30,60)
			for _,b in ipairs(tabBar:GetChildren()) do if b:IsA("TextButton") and b~=tbb then b.BackgroundColor3=c3(18,17,26) end end
		end)
		if ti==1 then active=td[1]; pan.Visible=true; tbb.BackgroundColor3=c3(200,30,60) end
	end
	UIS.InputBegan:Connect(function(inp,g) if not g and inp.KeyCode==Enum.KeyCode.RightShift then main.Visible=not main.Visible end end)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="Apex Software",Text="Authenticated - F3 Toggle ESP",Duration=5}) end)
	print("Fix applied successfully")
end
