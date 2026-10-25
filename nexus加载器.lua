--[[ ==========================================================================
     Nexus 脚本中心加载器 (Hub Loader)        By: KZ666
     黑白简约 · 白天/夜晚切换 · 动效 · 图标 · 音效
     全宽服务器列表 / 搜索 / 左下角头像（点击查看卡密信息）

     用法：
        getgenv().NEXUS_KEY = "卡密"
        loadstring(game:HttpGet("Hub加载器地址"))()
========================================================================== ]]

-- ============================ ① 在这里填卡密（可留空） ============================
local key = ""
-- ==============================================================================

local SUPABASE_URL   = "https://rwvuwtwirfkmbexvoudv.supabase.co"
local SUPABASE_KEY   = "sb_publishable_pGrBf582IQDuDm0UShzJgQ_jkpG63e7"
local OBF_SALT       = "NEXUS"
local SAVE_KEY       = true
local HUB_SCRIPT     = "hub"
local QQ_GROUP       = "1098748906"   -- 侧边栏展示的 QQ 群号
local DEFAULT_THEME  = "dark"
-- ==============================================================================

local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextService  = game:GetService("TextService")
local LP = Players.LocalPlayer
local requestFn = (syn and syn.request) or (http and http.request) or http_request or request
local hasWrite = (type(writefile) == "function")
local hasRead  = (type(readfile) == "function")
local KEY_FILE = "nexus_key.txt"
local THEME_FILE = "nexus_hub_theme.txt"

local function log(...) local a = { ... } pcall(function() print("[Nexus Hub]", table.unpack(a)) end) end

-- ============================ HWID ============================
local function rawHWID()
    local tries = {
        function() return gethwid and gethwid() end,
        function() return syn and syn.get_hwid and syn.get_hwid() end,
        function() return krnl and krnl.get_hwid and krnl.get_hwid() end,
        function() return fluxus and fluxus.get_hwid and fluxus.get_hwid() end,
        function() return game:GetService("RbxAnalyticsService"):GetClientId() end,
    }
    for _, f in ipairs(tries) do
        local ok, v = pcall(f)
        if ok and type(v) == "string" and #v > 0 then return v end
    end
    return "UID-" .. tostring(LP.UserId)
end
local function hash(str)
    local h = 5381
    for i = 1, #str do h = (h * 33 + string.byte(str, i)) % 4294967296 end
    return string.format("%08x", h) .. string.format("%08x", (#str * 2654435761) % 4294967296)
end
local HWID = hash(rawHWID())

-- ============================ HTTP ============================
local function postRPC(rpc, body)
    if not requestFn then return nil, "执行器不支持 HTTP 请求" end
    local ok, res = pcall(requestFn, {
        Url = SUPABASE_URL .. "/rest/v1/rpc/" .. rpc,
        Method = "POST",
        Headers = {
            ["apikey"] = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Content-Type"] = "application/json",
        },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or type(res) ~= "table" or not res.Body then return nil, "网络请求失败" end
    local dok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not dok then return nil, "返回解析失败" end
    if res.StatusCode and res.StatusCode >= 400 then
        return nil, (data and data.message) or ("HTTP " .. tostring(res.StatusCode))
    end
    return data
end

-- ============================ 主题 ============================
local Themes = {
    dark = {
        bg = Color3.fromRGB(9, 9, 10), panel = Color3.fromRGB(15, 15, 16),
        card = Color3.fromRGB(21, 21, 22), cardHov = Color3.fromRGB(31, 31, 33),
        border = Color3.fromRGB(38, 38, 40), borderHov = Color3.fromRGB(78, 78, 82),
        text = Color3.fromRGB(236, 236, 238), dim = Color3.fromRGB(138, 138, 144),
        ph = Color3.fromRGB(104, 104, 112),
        inv = Color3.fromRGB(10, 10, 11), invBg = Color3.fromRGB(238, 238, 240),
        ok = Color3.fromRGB(120, 220, 150), danger = Color3.fromRGB(255, 96, 96),
    },
    light = {
        bg = Color3.fromRGB(244, 244, 246), panel = Color3.fromRGB(255, 255, 255),
        card = Color3.fromRGB(250, 250, 252), cardHov = Color3.fromRGB(236, 236, 240),
        border = Color3.fromRGB(216, 216, 222), borderHov = Color3.fromRGB(150, 150, 158),
        text = Color3.fromRGB(26, 26, 30), dim = Color3.fromRGB(122, 122, 132),
        ph = Color3.fromRGB(158, 158, 166),
        inv = Color3.fromRGB(255, 255, 255), invBg = Color3.fromRGB(22, 22, 26),
        ok = Color3.fromRGB(34, 150, 88), danger = Color3.fromRGB(210, 55, 55),
    },
}
local themeName = DEFAULT_THEME
local bindings = {}
local function C(k) return Themes[themeName][k] end
local function bind(obj, prop, k)
    table.insert(bindings, { obj = obj, prop = prop, key = k })
    obj[prop] = Themes[themeName][k]
    return obj
end
local function applyTheme(animate)
    for _, b in ipairs(bindings) do
        pcall(function()
            if not b.obj or not b.obj.Parent then return end
            local target = Themes[themeName][b.key]
            if animate and (b.prop == "BackgroundColor3" or b.prop == "TextColor3" or b.prop == "Color") then
                TweenService:Create(b.obj, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [b.prop] = target }):Play()
            else
                b.obj[b.prop] = target
            end
        end)
    end
end
local function saveTheme() if hasWrite then pcall(function() writefile(THEME_FILE, themeName) end) end end
local function loadTheme()
    if not hasRead then return end
    local ok, v = pcall(function() return readfile(THEME_FILE) end)
    if ok and (v == "dark" or v == "light") then themeName = v end
end
loadTheme()

-- ============================ 工具 ============================
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function round(r, obj) return mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, obj) end
local function stroke(obj, k, th) return bind(mk("UIStroke", { Thickness = th or 1 }, obj), "Color", k or "border") end
local function tw(obj, time, props, style)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play(); return t
end
local function newGui(name)
    local pg = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild(name); if old then old:Destroy() end
    return mk("ScreenGui", { Name = name, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
end

local SFX_CLICK  = "rbxasset://sounds/electronicpingshort.wav"
local SFX_TOGGLE = "rbxasset://sounds/switch.wav"
local SFX_HOVER  = "rbxasset://sounds/clickfast.wav"
local function sfx(parent, id, vol)
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id; s.Volume = vol or 0.22; s.Parent = parent
        s:Play()
        task.delay(2, function() pcall(function() s:Destroy() end) end)
    end)
end

-- 简约图标（几何绘制）
local function iconSun(parent, size, out)
    local box = mk("Frame", {
        Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    }, parent)
    local c = mk("Frame", {
        Size = UDim2.new(0, size * 0.44, 0, size * 0.44),
        Position = UDim2.new(0.5, -size * 0.22, 0.5, -size * 0.22), BackgroundTransparency = 1,
    }, box)
    round(size, c)
    bind(mk("UIStroke", { Thickness = 1.5 }, c), "Color", "text")
    for i = 0, 3 do
        local holder = mk("Frame", {
            Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 1, Rotation = i * 90,
        }, box)
        bind(mk("Frame", {
            Size = UDim2.new(0, 1.6, 0, size * 0.17),
            Position = UDim2.new(0, -0.8, 0, -size * 0.46), BorderSizePixel = 0,
        }, holder), "BackgroundColor3", "text")
    end
    if out then out.sun = box end
    return box
end
local function iconMoon(parent, size, out)
    local box = mk("Frame", {
        Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    }, parent)
    local base = mk("Frame", {
        Size = UDim2.new(0, size * 0.54, 0, size * 0.54),
        Position = UDim2.new(0.5, -size * 0.27, 0.5, -size * 0.27), BorderSizePixel = 0,
    }, box)
    round(size, base)
    bind(base, "BackgroundColor3", "text")
    local cut = mk("Frame", {
        Size = UDim2.new(0, size * 0.48, 0, size * 0.48),
        Position = UDim2.new(0.5, -size * 0.15, 0.5, -size * 0.35), BorderSizePixel = 0,
    }, box)
    round(size, cut)
    bind(cut, "BackgroundColor3", "panel")
    if out then out.moon = box; out.cut = cut end
    return box
end

-- ============================ 登录界面 ============================
local function loginGui(onOk)
    local gui = newGui("NexusHubLogin")
    local box = mk("Frame", {
        Size = UDim2.new(0, 330, 0, 214), Position = UDim2.new(0.5, -165, 0.5, -95),
        BackgroundColor3 = C("panel"), BorderSizePixel = 0, BackgroundTransparency = 1,
    }, gui)
    round(12, box); stroke(box)

    local title = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 18), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 20, Text = "NEXUS", TextTransparency = 1,
    }, box)
    bind(title, "TextColor3", "text")
    local sub = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 50), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 10, Text = "脚本中心 · 请输入卡密", TextTransparency = 1,
    }, box)
    bind(sub, "TextColor3", "dim")

    local input = mk("TextBox", {
        Size = UDim2.new(1, -48, 0, 36), Position = UDim2.new(0, 24, 0, 78),
        BackgroundColor3 = C("bg"), BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 13,
        PlaceholderText = "输入卡密...", PlaceholderColor3 = C("ph"),
        ClearTextOnFocus = false, Text = "", BackgroundTransparency = 1, TextTransparency = 1,
    }, box)
    round(8, input)
    local ist = stroke(input)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 12) }, input)

    local status = mk("TextLabel", {
        Size = UDim2.new(1, -48, 0, 16), Position = UDim2.new(0, 24, 0, 120), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 10, Text = "", TextXAlignment = Enum.TextXAlignment.Center,
        TextTransparency = 1,
    }, box)
    bind(status, "TextColor3", "danger")

    local btn = mk("TextButton", {
        Size = UDim2.new(1, -96, 0, 34), Position = UDim2.new(0, 48, 0, 148),
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12, Text = "验证并进入",
        AutoButtonColor = false, BackgroundTransparency = 1, TextTransparency = 1,
    }, box)
    round(8, btn)
    bind(btn, "BackgroundColor3", "invBg")
    bind(btn, "TextColor3", "inv")

    tw(box, 0.30, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -165, 0.5, -107) }, Enum.EasingStyle.Quint)
    tw(input, 0.30, { BackgroundTransparency = 0, TextTransparency = 0 })
    for _, o in ipairs({ title, sub, status }) do tw(o, 0.30, { TextTransparency = 0 }) end
    tw(btn, 0.30, { BackgroundTransparency = 0, TextTransparency = 0 })
    input.PlaceholderColor3 = C("ph")

    local busy = false
    btn.MouseEnter:Connect(function() sfx(gui, SFX_HOVER, 0.1); tw(btn, 0.15, { BackgroundColor3 = C("text") }) end)
    btn.MouseLeave:Connect(function() tw(btn, 0.18, { BackgroundColor3 = C("invBg") }) end)
    btn.MouseButton1Click:Connect(function()
        if busy then return end
        sfx(gui, SFX_CLICK, 0.3)
        local k = input.Text:upper():gsub("%s+", "")
        if k == "" then status.TextColor3 = C("danger"); status.Text = "请输入卡密"; return end
        busy = true; btn.Text = "验证中..."
        status.TextColor3 = C("ph"); status.Text = "正在连接服务器..."
        task.spawn(function()
            local res, err = postRPC("start_session", { p_key = k, p_hwid = HWID, p_script = HUB_SCRIPT })
            busy = false; btn.Text = "验证并进入"
            if not res then status.TextColor3 = C("danger"); status.Text = err or "无法连接服务器"; return end
            if res.success ~= true then status.TextColor3 = C("danger"); status.Text = res.message or "验证失败"; return end
            if SAVE_KEY and hasWrite then pcall(function() writefile(KEY_FILE, k) end) end
            status.TextColor3 = C("ok"); status.Text = "验证成功"
            task.wait(0.2)
            tw(box, 0.18, { BackgroundTransparency = 1 })
            task.wait(0.18); gui:Destroy()
            onOk(k, res.token)
        end)
    end)
    input.FocusLost:Connect(function(enter) if enter and input.Text ~= "" then btn.MouseButton1Click:Fire() end end)
    input.Focused:Connect(function() tw(ist, 0.15, { Color = C("borderHov") }) end)
    input.FocusLost:Connect(function() tw(ist, 0.2, { Color = C("border") }) end)
    return gui
end

-- ============================ Hub 界面 ============================
local PLAN_NAME = { trial = "试用", day = "日卡", week = "周卡", month = "月卡", perm = "永久", custom = "自定义" }

local function fmtTimeStr(s)
    if type(s) ~= "string" then return "-" end
    local y, mo, d, h, mi = s:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
    if not y then return s end
    return string.format("%s-%s-%s %s:%s", y, mo, d, h, mi)
end
local function fmtLeft(secs)
    if secs == nil then return "永久" end
    secs = tonumber(secs) or 0
    if secs <= 0 then return "已过期" end
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    if d > 0 then return string.format("%d 天 %d 小时", d, h) end
    if h > 0 then return string.format("%d 小时 %d 分", h, m) end
    return string.format("%d 分", m)
end

local function openHub(cardKey, token)
    local gui = newGui("NexusHub")
    local W, H = 700, 480
    local SIDE_W = 150
    local RIGHT_X = 24 + SIDE_W + 16

    local win = mk("Frame", {
        Size = UDim2.new(0, W * 0.94, 0, H * 0.94), Position = UDim2.new(0.5, -W * 0.47, 0.5, -H * 0.45),
        BackgroundColor3 = C("bg"), BorderSizePixel = 0, BackgroundTransparency = 1,
    }, gui)
    round(14, win)
    bind(win, "BackgroundColor3", "bg")
    local wst = stroke(win)
    tw(win, 0.30, { BackgroundTransparency = 0, Size = UDim2.new(0, W, 0, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2) }, Enum.EasingStyle.Quint)

    local INFO_W = 340
    local infoOpen = false
    local closeInfo
    local renderList
    local showView
    local markAnnSeen
    local renderAnns
    local servers = {}
    local anns = {}
    local curView = "servers"

    local dismiss = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 0, BorderSizePixel = 0,
    }, win)
    dismiss.MouseButton1Click:Connect(function()
        if infoOpen and closeInfo then closeInfo() end
    end)

    local function fadeIn(objs, delay)
        for _, o in ipairs(objs) do o.BackgroundTransparency = 1 end
        task.delay(delay or 0.10, function() for _, o in ipairs(objs) do tw(o, 0.28, { BackgroundTransparency = 0 }) end end)
    end

    -- ============================ 顶栏 ============================
    local title = mk("TextLabel", {
        Size = UDim2.new(0, 300, 0, 22), Position = UDim2.new(0, 24, 0, 16), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 15, Text = "NEXUS 脚本中心",
        TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1,
    }, win)
    bind(title, "TextColor3", "text")
    local sub = mk("TextLabel", {
        Size = UDim2.new(0, 300, 0, 14), Position = UDim2.new(0, 24, 0, 38), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 10, Text = "选择服务器加载",
        TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1,
    }, win)
    bind(sub, "TextColor3", "dim")
    task.delay(0.12, function() tw(title, 0.3, { TextTransparency = 0 }); tw(sub, 0.3, { TextTransparency = 0 }) end)

    local close = mk("TextButton", {
        Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -40, 0, 15), BackgroundTransparency = 1,
        Text = "×", Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, TextTransparency = 1,
    }, win)
    bind(close, "TextColor3", "dim")
    task.delay(0.12, function() tw(close, 0.3, { TextTransparency = 0 }) end)
    close.MouseEnter:Connect(function() tw(close, 0.15, { TextColor3 = C("text"), Rotation = 90 }) end)
    close.MouseLeave:Connect(function() tw(close, 0.2, { TextColor3 = C("dim"), Rotation = 0 }) end)
    close.MouseButton1Click:Connect(function()
        sfx(gui, SFX_CLICK, 0.25)
        tw(win, 0.18, { BackgroundTransparency = 1, Size = UDim2.new(0, W * 0.96, 0, H * 0.96) })
        task.wait(0.2); gui:Destroy()
    end)

    -- 主题切换
    local themeIcons = {}
    local tbtn = mk("TextButton", {
        Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -76, 0, 13),
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
    }, win)
    round(9, tbtn)
    bind(tbtn, "BackgroundColor3", "panel")
    local tst = stroke(tbtn)
    iconSun(tbtn, 17, themeIcons)
    iconMoon(tbtn, 17, themeIcons)
    themeIcons.sun.Visible = (themeName == "dark")
    themeIcons.moon.Visible = (themeName == "light")
    fadeIn({ tbtn }, 0.14)
    tbtn.MouseEnter:Connect(function() tw(tbtn, 0.15, { BackgroundColor3 = C("cardHov") }); tw(tst, 0.15, { Color = C("borderHov") }) end)
    tbtn.MouseLeave:Connect(function() tw(tbtn, 0.2, { BackgroundColor3 = C("panel") }); tw(tst, 0.2, { Color = C("border") }) end)
    tbtn.MouseButton1Click:Connect(function()
        sfx(gui, SFX_TOGGLE, 0.3)
        themeName = (themeName == "dark") and "light" or "dark"
        saveTheme(); applyTheme(true)
        local show, hide = themeIcons.sun, themeIcons.moon
        if themeName == "light" then show, hide = themeIcons.moon, themeIcons.sun end
        tw(hide, 0.14, { Rotation = -90 })
        task.delay(0.14, function()
            hide.Visible = false; hide.Rotation = 0
            show.Visible = true; show.Rotation = 90
            tw(show, 0.2, { Rotation = 0 })
        end)
        if renderList then task.defer(function() if renderList then renderList() end end) end
        if showView then task.defer(function() showView(curView, true) end) end
    end)

    local divider = mk("Frame", { Size = UDim2.new(1, -48, 0, 1), Position = UDim2.new(0, 24, 0, 60), BorderSizePixel = 0 }, win)
    bind(divider, "BackgroundColor3", "border")

    -- ============================ 左侧导航 ============================
    local side = mk("Frame", {
        Size = UDim2.new(0, SIDE_W, 1, -96), Position = UDim2.new(0, 24, 0, 72), BackgroundTransparency = 1,
    }, win)
    local navScroll = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -74), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, side)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, navScroll)

    local navItems = {}
    local function addNav(key, label, order)
        local btn = mk("TextButton", {
            Size = UDim2.new(1, -4, 0, 34), BorderSizePixel = 0, Text = "", AutoButtonColor = false,
            LayoutOrder = order, BackgroundTransparency = 1,
        }, navScroll)
        round(8, btn)
        bind(btn, "BackgroundColor3", "card")
        local st = stroke(btn)
        local bar = mk("Frame", {
            Size = UDim2.new(0, 2, 0, 0), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0, BackgroundTransparency = 1,
        }, btn)
        round(2, bar)
        bind(bar, "BackgroundColor3", "inv")
        local txt = mk("TextLabel", {
            Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = label, TextTransparency = 1,
        }, btn)
        local badge = mk("TextLabel", {
            Size = UDim2.new(0, 20, 0, 16), Position = UDim2.new(1, -26, 0.5, -8), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 10, Text = "", TextXAlignment = Enum.TextXAlignment.Right,
        }, btn)
        bind(badge, "TextColor3", "danger")
        local entry = { key = key, btn = btn, st = st, txt = txt, bar = bar, badge = badge, active = false }
        navItems[key] = entry
        task.delay(0.05 * order, function()
            tw(btn, 0.25, { BackgroundTransparency = 0 })
            tw(txt, 0.25, { TextTransparency = 0 })
        end)
        btn.MouseEnter:Connect(function()
            if not entry.active then
                sfx(gui, SFX_HOVER, 0.07)
                tw(btn, 0.15, { BackgroundColor3 = C("cardHov") })
                tw(st, 0.15, { Color = C("borderHov") })
                tw(txt, 0.15, { TextColor3 = C("text") })
            end
        end)
        btn.MouseLeave:Connect(function()
            if not entry.active then
                tw(btn, 0.2, { BackgroundColor3 = C("card") })
                tw(st, 0.2, { Color = C("border") })
                tw(txt, 0.2, { TextColor3 = C("dim") })
            end
        end)
        btn.MouseButton1Click:Connect(function()
            sfx(gui, SFX_CLICK, 0.22)
            if showView then showView(key) end
        end)
        return entry
    end

    addNav("servers", "服务器", 1)
    local annEntry = addNav("ann", "公告", 2)
    local qqEntry = addNav("qq", "QQ 群", 3)

    -- 头像卡片
    local userCard = mk("TextButton", {
        Size = UDim2.new(1, -4, 0, 58), Position = UDim2.new(0, 2, 1, -58),
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
    }, side)
    round(10, userCard)
    bind(userCard, "BackgroundColor3", "panel")
    local ust = stroke(userCard)
    fadeIn({ userCard }, 0.2)
    local avatar = mk("ImageLabel", {
        Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 10, 0, 11),
        BorderSizePixel = 0, Image = "",
    }, userCard)
    round(18, avatar)
    bind(avatar, "BackgroundColor3", "card")
    pcall(function()
        avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LP.UserId) .. "&w=150&h=150"
    end)
    local uname = mk("TextLabel", {
        Size = UDim2.new(1, -56, 0, 15), Position = UDim2.new(0, 54, 0, 12), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(LP.Name), TextTransparency = 1,
    }, userCard)
    bind(uname, "TextColor3", "text")
    local udisp = mk("TextLabel", {
        Size = UDim2.new(1, -56, 0, 13), Position = UDim2.new(0, 54, 0, 29), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = "查看卡密信息", TextTransparency = 1,
    }, userCard)
    bind(udisp, "TextColor3", "dim")
    task.delay(0.24, function() tw(uname, 0.3, { TextTransparency = 0 }); tw(udisp, 0.3, { TextTransparency = 0 }) end)
    userCard.MouseEnter:Connect(function() tw(userCard, 0.15, { BackgroundColor3 = C("cardHov") }); tw(ust, 0.15, { Color = C("borderHov") }) end)
    userCard.MouseLeave:Connect(function() tw(userCard, 0.2, { BackgroundColor3 = C("panel") }); tw(ust, 0.2, { Color = C("border") }) end)

    -- ============================ 右侧内容区 ============================
    local rightW = W - RIGHT_X - 24
    local search = mk("TextBox", {
        Size = UDim2.new(0, rightW, 0, 34), Position = UDim2.new(0, RIGHT_X, 0, 72),
        BackgroundColor3 = C("panel"), BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 12,
        PlaceholderText = "搜索服务器...", PlaceholderColor3 = C("ph"),
        ClearTextOnFocus = false, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, TextTransparency = 1,
    }, win)
    round(9, search)
    bind(search, "BackgroundColor3", "panel")
    local sst = stroke(search)
    search.PlaceholderColor3 = C("ph")
    mk("UIPadding", { PaddingLeft = UDim.new(0, 14) }, search)
    fadeIn({ search }, 0.14)
    task.delay(0.12, function() tw(search, 0.3, { TextTransparency = 0 }) end)
    search.Focused:Connect(function() tw(sst, 0.15, { Color = C("borderHov") }) end)
    search.FocusLost:Connect(function() tw(sst, 0.2, { Color = C("border") }) end)

    local CONTENT_Y = 118
    local CONTENT_H = H - CONTENT_Y - 52

    local serversScroll = mk("ScrollingFrame", {
        Size = UDim2.new(0, rightW, 0, CONTENT_H), Position = UDim2.new(0, RIGHT_X, 0, CONTENT_Y),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, win)
    bind(serversScroll, "ScrollBarImageColor3", "border")
    mk("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, serversScroll)

    local annScroll = mk("ScrollingFrame", {
        Size = UDim2.new(0, rightW, 0, CONTENT_H), Position = UDim2.new(0, RIGHT_X, 0, CONTENT_Y),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, win)
    bind(annScroll, "ScrollBarImageColor3", "border")
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, annScroll)

    local qqFrame = mk("Frame", {
        Size = UDim2.new(0, rightW, 0, 190), Position = UDim2.new(0, RIGHT_X, 0, CONTENT_Y),
        BorderSizePixel = 0, BackgroundTransparency = 1, Visible = false,
    }, win)
    local qqCard = mk("TextButton", {
        Size = UDim2.new(0, rightW, 0, 150), BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        BackgroundTransparency = 1,
    }, qqFrame)
    round(12, qqCard)
    bind(qqCard, "BackgroundColor3", "card")
    local qst = stroke(qqCard)
    local qqTitle = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 22), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 11, Text = "NEXUS 官方交流群",
    }, qqCard)
    bind(qqTitle, "TextColor3", "dim")
    local qqNum = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 48), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 30, Text = QQ_GROUP,
    }, qqCard)
    bind(qqNum, "TextColor3", "text")
    local qqHint = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 96), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 10, Text = "点击复制群号",
    }, qqCard)
    bind(qqHint, "TextColor3", "dim")
    qqCard.MouseEnter:Connect(function() tw(qqCard, 0.15, { BackgroundColor3 = C("cardHov") }); tw(qst, 0.15, { Color = C("borderHov") }) end)
    qqCard.MouseLeave:Connect(function() tw(qqCard, 0.2, { BackgroundColor3 = C("card") }); tw(qst, 0.2, { Color = C("border") }) end)
    qqCard.MouseButton1Click:Connect(function()
        sfx(gui, SFX_CLICK, 0.26)
        local ok = pcall(function() setclipboard(tostring(QQ_GROUP)) end)
        qqHint.Text = ok and "已复制群号 ✓" or ("请手动记下：" .. tostring(QQ_GROUP))
        task.delay(1.6, function() qqHint.Text = "点击复制群号" end)
    end)

    -- 状态栏
    local status = mk("TextLabel", {
        Size = UDim2.new(0, rightW, 0, 16), Position = UDim2.new(0, RIGHT_X, 1, -40), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 10, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
    }, win)
    bind(status, "TextColor3", "dim")

    -- ============================ 视图切换 ============================
    local lastSyncedView = nil
    showView = function(view, force)
        if view == curView and not force then return end
        curView = view
        for k, e in pairs(navItems) do
            e.active = (k == view)
            if e.active then
                tw(e.btn, 0.16, { BackgroundColor3 = C("invBg") })
                tw(e.txt, 0.16, { TextColor3 = C("inv") })
                tw(e.st, 0.16, { Color = C("invBg") })
                tw(e.bar, 0.18, { Size = UDim2.new(0, 2, 0, 20) })
            else
                tw(e.btn, 0.16, { BackgroundColor3 = C("card") })
                tw(e.txt, 0.16, { TextColor3 = C("dim") })
                tw(e.st, 0.16, { Color = C("border") })
                tw(e.bar, 0.15, { Size = UDim2.new(0, 2, 0, 0) })
            end
        end
        serversScroll.Visible = (view == "servers")
        search.Visible = (view == "servers")
        annScroll.Visible = (view == "ann")
        qqFrame.Visible = (view == "qq")
        if view == "ann" then
            markAnnSeen()
            renderAnns()
            status.Text = "共 " .. #anns .. " 条公告"
        elseif view == "qq" then
            status.Text = "官方交流群"
        else
            renderList()
        end
    end

    -- ============================ 卡密信息弹窗 ============================
    local info = mk("Frame", {
        Size = UDim2.new(0, INFO_W, 0, 0), Position = UDim2.new(0, RIGHT_X, 1, -46),
        BackgroundColor3 = C("panel"), BorderSizePixel = 0, Visible = false, ClipsDescendants = true,
    }, win)
    round(12, info)
    bind(info, "BackgroundColor3", "panel")
    local ist2 = stroke(info)
    local infoHolder = mk("Frame", { Size = UDim2.new(1, -28, 0, 0), Position = UDim2.new(0, 14, 0, 12), BackgroundTransparency = 1 }, info)
    mk("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, infoHolder)

    local function infoRow(label, value, order)
        local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1, LayoutOrder = order }, infoHolder)
        local l = mk("TextLabel", {
            Size = UDim2.new(0, 76, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 10, Text = label, TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        bind(l, "TextColor3", "dim")
        local v = mk("TextLabel", {
            Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 80, 0, 0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium, TextSize = 10, Text = tostring(value),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
        bind(v, "TextColor3", "text")
    end
    local function clearInfo()
        for _, c in ipairs(infoHolder:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
    end
    local function fitInfo()
        local n = 0
        for _, c in ipairs(infoHolder:GetChildren()) do
            if c:IsA("Frame") then n = n + 1 end
        end
        local h = 24 + n * 17 + math.max(0, n - 1) * 7
        tw(info, 0.2, { Size = UDim2.new(0, INFO_W, 0, h) }, Enum.EasingStyle.Quint)
    end

    closeInfo = function()
        infoOpen = false
        tw(info, 0.18, { Size = UDim2.new(0, INFO_W, 0, 0) })
        task.delay(0.2, function() info.Visible = false end)
    end

    local function openInfo()
        infoOpen = true
        sfx(gui, SFX_CLICK, 0.22)
        info.Visible = true
        clearInfo()
        infoRow("卡密", cardKey, 1)
        infoRow("状态", "查询中...", 2)
        infoRow("类型", "-", 3)
        infoRow("到期", "-", 4)
        infoRow("剩余", "-", 5)
        infoRow("设备", "-", 6)
        infoRow("使用次数", "-", 7)
        infoRow("最近登录", "-", 8)
        info.Size = UDim2.new(0, INFO_W, 0, 0)
        fitInfo()
        task.spawn(function()
            local r, err = postRPC("license_info", { p_token = token })
            if not infoOpen then return end
            clearInfo()
            if not r or r.success ~= true then
                infoRow("卡密", cardKey, 1)
                infoRow("状态", (r and r.message) or err or "查询失败", 2)
            else
                local d = r.data or {}
                infoRow("卡密", tostring(d.key or cardKey), 1)
                infoRow("状态", d.enabled == false and "已禁用" or "正常", 2)
                infoRow("类型", PLAN_NAME[d.plan] or tostring(d.plan or "-"), 3)
                infoRow("到期", d.expires_at and fmtTimeStr(d.expires_at) or "永久", 4)
                infoRow("剩余", fmtLeft(d.secs_left), 5)
                infoRow("设备", tostring(d.devices or 0) .. " / " .. tostring(d.hwid_limit or 1), 6)
                infoRow("使用次数", tostring(d.uses or 0) .. ((d.max_uses and (" / " .. tostring(d.max_uses))) or " 次"), 7)
                infoRow("最近登录", d.last_login and fmtTimeStr(d.last_login) or "首次使用", 8)
            end
            fitInfo()
        end)
    end

    userCard.MouseButton1Click:Connect(function()
        if infoOpen then closeInfo() else openInfo() end
    end)

    -- ============================ 公告 ============================
    local ANN_SEEN_FILE = "nexus_hub_ann_seen.txt"
    local function readSeen()
        if not hasRead then return 0 end
        local ok, v = pcall(function() return readfile(ANN_SEEN_FILE) end)
        if ok and v then return tonumber(v) or 0 end
        return 0
    end
    markAnnSeen = function()
        local maxId = 0
        for _, a in ipairs(anns) do
            local id = tonumber(a.id) or 0
            if id > maxId then maxId = id end
        end
        if maxId > 0 and hasWrite then pcall(function() writefile(ANN_SEEN_FILE, tostring(maxId)) end) end
        annEntry.badge.Text = ""
    end
    local function updateBadge()
        local seen = readSeen()
        local n = 0
        for _, a in ipairs(anns) do
            if (tonumber(a.id) or 0) > seen then n = n + 1 end
        end
        annEntry.badge.Text = (n > 0) and tostring(n) or ""
    end
    local function annRow(a, order)
        local cardW = rightW - 8
        local content = tostring(a.content or "")
        local hContent = 20
        pcall(function()
            local ts = TextService:GetTextSize(content, 11, Enum.Font.Gotham, Vector2.new(cardW - 28, 10000))
            hContent = math.max(18, ts.Y)
        end)
        local cardH = 16 + 20 + hContent + 30
        local card = mk("Frame", {
            Size = UDim2.new(0, cardW, 0, cardH), BorderSizePixel = 0, BackgroundTransparency = 1,
            LayoutOrder = order,
        }, annScroll)
        round(10, card)
        bind(card, "BackgroundColor3", "card")
        local st = stroke(card)
        local t = mk("TextLabel", {
            Size = UDim2.new(1, -28, 0, 18), Position = UDim2.new(0, 14, 0, 14), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(a.title or "公告"), TextTransparency = 1,
        }, card)
        bind(t, "TextColor3", "text")
        local d = mk("TextLabel", {
            Size = UDim2.new(1, -28, 0, 14), Position = UDim2.new(0, 14, 0, 33), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
            Text = fmtTimeStr(a.created_at) .. "   #" .. tostring(a.id or ""), TextTransparency = 1,
        }, card)
        bind(d, "TextColor3", "dim")
        local c = mk("TextLabel", {
            Size = UDim2.new(1, -28, 0, hContent), Position = UDim2.new(0, 14, 0, 52), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = content, TextTransparency = 1,
        }, card)
        bind(c, "TextColor3", "text")
        task.delay(0.03 * order, function()
            if not card.Parent then return end
            tw(card, 0.24, { BackgroundTransparency = 0 })
            tw(t, 0.24, { TextTransparency = 0 })
            tw(d, 0.24, { TextTransparency = 0 })
            tw(c, 0.24, { TextTransparency = 0 })
        end)
        card.MouseEnter:Connect(function() tw(card, 0.15, { BackgroundColor3 = C("cardHov") }); tw(st, 0.15, { Color = C("borderHov") }) end)
        card.MouseLeave:Connect(function() tw(card, 0.2, { BackgroundColor3 = C("card") }); tw(st, 0.2, { Color = C("border") }) end)
    end
    renderAnns = function()
        for _, o in ipairs(annScroll:GetChildren()) do
            if o:IsA("Frame") then o:Destroy() end
        end
        if #anns == 0 then
            local e = mk("TextLabel", {
                Size = UDim2.new(1, -8, 0, 60), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                TextSize = 11, Text = "暂无公告", TextXAlignment = Enum.TextXAlignment.Left,
            }, annScroll)
            bind(e, "TextColor3", "dim")
            return
        end
        for i, a in ipairs(anns) do annRow(a, i) end
    end

    -- ============================ 服务器列表 ============================
    local loading, dots = false, 0
    task.spawn(function()
        while gui.Parent do
            task.wait(0.35)
            dots = loading and ((dots % 3) + 1) or 0
        end
    end)

    local function matches(s, q)
        if q == "" then return true end
        local hay = string.lower(tostring(s.slug or "") .. " " .. tostring(s.title or "") .. " " .. tostring(s.game or "") .. " " .. tostring(s.description or ""))
        return string.find(hay, q, 1, true) ~= nil
    end

    local function doLoad(slug, tname)
        if loading then return end
        loading = true
        status.Text = "正在加载 " .. tostring(tname) .. " ..."
        task.spawn(function()
            local r, err = postRPC("use_script", { p_token = token, p_slug = slug })
            if not r or r.success ~= true then
                loading = false; status.TextColor3 = C("danger")
                status.Text = (r and r.message) or err or "无法加载"; return
            end
            local chunks = tonumber(r.chunks) or 0
            local parts = {}
            for i = 0, chunks - 1 do
                status.Text = string.format("正在加载 %s   %d/%d%s", tostring(tname), i + 1, chunks, string.rep("·", dots))
                local c = postRPC("get_chunk", { p_token = token, p_index = i })
                if not c or c.success ~= true then
                    task.wait(0.25)
                    c = postRPC("get_chunk", { p_token = token, p_index = i })
                end
                if not c or c.success ~= true then
                    loading = false; status.TextColor3 = C("danger")
                    status.Text = (c and c.message) or "分片拉取失败"; return
                end
                parts[#parts + 1] = c.content or ""
            end
            local code = table.concat(parts)
            getgenv().NEXUS_LICENSE = {
                key = cardKey, hwid = HWID, token = token,
                script = slug, version = r.version, verified_at = os.time(),
            }
            if OBF_SALT ~= "" then pcall(function() getgenv().SALT_KEY = OBF_SALT end) end
            local fn, cerr = loadstring(code)
            if not fn then
                loading = false; status.TextColor3 = C("danger")
                status.Text = "编译失败: " .. tostring(cerr); return
            end
            status.TextColor3 = C("ok"); status.Text = "已加载 " .. tostring(tname)
            tw(win, 0.18, { BackgroundTransparency = 1 })
            task.wait(0.2); gui:Destroy()
            local ok, e = pcall(fn)
            if not ok then warn("[Nexus Hub] 脚本运行出错: " .. tostring(e)) end
        end)
    end

    renderList = function()
        for _, c in ipairs(serversScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local q = string.lower(search.Text)
        local shown, idx = 0, 0
        for _, s in ipairs(servers) do
            if matches(s, q) then
                shown = shown + 1; idx = idx + 1
                local row = mk("TextButton", {
                    Size = UDim2.new(1, -6, 0, 56), BorderSizePixel = 0, Text = "",
                    AutoButtonColor = false, BackgroundTransparency = 1,
                }, serversScroll)
                round(9, row)
                bind(row, "BackgroundColor3", "card")
                local st = stroke(row)
                local icon = mk("Frame", {
                    Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(0, 11, 0, 11),
                    BorderSizePixel = 0, BackgroundTransparency = 1,
                }, row)
                round(8, icon)
                bind(icon, "BackgroundColor3", "panel")
                local ilbl = mk("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
                    TextSize = 14, Text = tostring(s.icon or "🎮"), TextTransparency = 1,
                }, icon)
                bind(ilbl, "TextColor3", "text")
                local rtitle = mk("TextLabel", {
                    Size = UDim2.new(1, -152, 0, 18), Position = UDim2.new(0, 56, 0, 10), BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(s.title or s.slug), TextTransparency = 1,
                }, row)
                bind(rtitle, "TextColor3", "text")
                local rsub = mk("TextLabel", {
                    Size = UDim2.new(1, -152, 0, 14), Position = UDim2.new(0, 56, 0, 30), BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = tostring(s.game or "未分类") .. "   ·   " .. tostring(s.latest_version or ""), TextTransparency = 1,
                }, row)
                bind(rsub, "TextColor3", "dim")
                local go = mk("TextLabel", {
                    Size = UDim2.new(0, 62, 1, 0), Position = UDim2.new(1, -72, 0, 0), BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold, TextSize = 11, Text = "加载 ›",
                    TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1,
                }, row)
                bind(go, "TextColor3", "dim")
                task.delay(0.03 * idx, function()
                    if not row.Parent then return end
                    tw(row, 0.24, { BackgroundTransparency = 0 })
                    tw(icon, 0.24, { BackgroundTransparency = 0 })
                    tw(ilbl, 0.24, { TextTransparency = 0 })
                    tw(rtitle, 0.24, { TextTransparency = 0 })
                    tw(rsub, 0.24, { TextTransparency = 0 })
                    tw(go, 0.24, { TextTransparency = 0 })
                end)
                row.MouseEnter:Connect(function()
                    sfx(gui, SFX_HOVER, 0.06)
                    tw(row, 0.16, { BackgroundColor3 = C("cardHov") })
                    tw(st, 0.16, { Color = C("borderHov") })
                    tw(go, 0.16, { TextColor3 = C("text"), Position = UDim2.new(1, -66, 0, 0) })
                end)
                row.MouseLeave:Connect(function()
                    tw(row, 0.2, { BackgroundColor3 = C("card") })
                    tw(st, 0.2, { Color = C("border") })
                    tw(go, 0.2, { TextColor3 = C("dim"), Position = UDim2.new(1, -72, 0, 0) })
                end)
                row.MouseButton1Click:Connect(function()
                    if infoOpen and closeInfo then closeInfo() end
                    sfx(gui, SFX_CLICK, 0.26)
                    tw(row, 0.08, { BackgroundColor3 = C("invBg") })
                    task.delay(0.1, function() tw(row, 0.2, { BackgroundColor3 = C("cardHov") }) end)
                    doLoad(s.slug, s.title or s.slug)
                end)
            end
        end
        if shown == 0 then
            status.Text = (#servers == 0) and "没有可用的服务器（后台未上架或卡密权限不足）" or "没有匹配的服务器"
        else
            status.Text = (q ~= "") and ("搜索到 " .. shown .. " 个") or ("共 " .. shown .. " 个服务器")
        end
    end

    search:GetPropertyChangedSignal("Text"):Connect(renderList)

    -- 初始进入「服务器」
    showView("servers", true)

    task.spawn(function()
        status.Text = "正在获取服务器列表..."
        local r, err = postRPC("hub_list", { p_token = token })
        if not r then status.TextColor3 = C("danger"); status.Text = err or "获取失败"; return end
        if r.success ~= true then status.TextColor3 = C("danger"); status.Text = r.message or "获取失败"; return end
        servers = r.data or {}
        renderList()
    end)

    task.spawn(function()
        local r = postRPC("hub_announcements", { p_token = token })
        if r and r.success == true then
            anns = r.data or {}
            updateBadge()
            if curView == "ann" then renderAnns() end
        end
    end)
end

-- ============================ 启动 ============================
pcall(function()
    local g = getgenv and getgenv()
    if g and OBF_SALT ~= "" and (type(g.SALT_KEY) ~= "string" or g.SALT_KEY == "") then
        g.SALT_KEY = OBF_SALT
    end
end)

local function readSavedKey()
    if not (SAVE_KEY and hasRead) then return nil end
    local ok, v = pcall(function() return readfile(KEY_FILE) end)
    if ok and type(v) == "string" then
        v = v:gsub("%s+", "")
        if v ~= "" then return v end
    end
    return nil
end

local RUNTIME_KEY = nil
local function resolveKey()
    if type(key) == "string" and key ~= "" then return key end
    if RUNTIME_KEY and RUNTIME_KEY ~= "" then return RUNTIME_KEY end
    local g = getgenv and getgenv()
    if g and type(g.NEXUS_KEY) == "string" and g.NEXUS_KEY ~= "" then return g.NEXUS_KEY end
    if type(_G.NEXUS_KEY) == "string" and _G.NEXUS_KEY ~= "" then return _G.NEXUS_KEY end
    return readSavedKey()
end

local function boot()
    local k = resolveKey()
    if k then
        k = tostring(k):upper():gsub("%s+", "")
        log("检测到卡密，自动登录中...")
        local res, err = postRPC("start_session", { p_key = k, p_hwid = HWID, p_script = HUB_SCRIPT })
        if res and res.success == true then
            log("自动登录成功")
            openHub(k, res.token)
            return
        end
        log("自动登录失败:", (res and res.message) or err)
    end
    loginGui(function(k2, t) openHub(k2, t) end)
end

task.defer(function()
    task.wait()
    boot()
end)

return function(k)
    if k ~= nil and tostring(k) ~= "" then RUNTIME_KEY = tostring(k) end
end
