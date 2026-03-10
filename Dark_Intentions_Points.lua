-- ============================================================
-- Dark Intentions Points
-- EP (Effort Points), GP (Gear Points), PR = EP/GP
-- ============================================================

local ADDON_NAME = "Dark_Intentions_Points"
local DEFAULT_GP = 2

local POINT_VALUES  = {}
local BUTTON_LABELS = {}
local EP_HDR_LABELS = {}
local EP_KEY_ORDER  = {}
local EP_BUILTIN    = {}
local BUTTON_COLORS = {}
local GP_LABELS     = {}
local GP_HDR_LABELS = {}
local GP_KEY_ORDER  = {}
local GP_BUILTIN    = {}
local GP_VALUES     = {}

-- ============================================================
-- DB
-- ============================================================
local function InitDB()
    if not DarkIntentionsPointsDB                then DarkIntentionsPointsDB         = {} end
    if not DarkIntentionsPointsDB.roster         then DarkIntentionsPointsDB.roster  = {} end
    if not DarkIntentionsPointsDB.ep             then DarkIntentionsPointsDB.ep      = {} end
    if not DarkIntentionsPointsDB.gp             then DarkIntentionsPointsDB.gp      = {} end
    if not DarkIntentionsPointsDB.history        then DarkIntentionsPointsDB.history = {} end
    if not DarkIntentionsPointsDB.settings       then DarkIntentionsPointsDB.settings = {} end
    local s = DarkIntentionsPointsDB.settings
    if not s.permissions then s.permissions = {} end
    if not s.permissions.rankAccess then s.permissions.rankAccess = {} end
    if not s.permissions.charAccess then s.permissions.charAccess = {} end
    if DarkIntentionsPointsDB.points then
        for k,v in pairs(DarkIntentionsPointsDB.points) do
            if not DarkIntentionsPointsDB.ep[k] then DarkIntentionsPointsDB.ep[k] = v end
        end
        DarkIntentionsPointsDB.points = nil
    end
    -- Load custom EP buttons (stored as ordered list)
    if not s.ep_custom then s.ep_custom = {} end
    for _,def in ipairs(s.ep_custom) do
        local k = def.key
        if k and not POINT_VALUES[k] then
            POINT_VALUES[k]  = def.value or 1
            BUTTON_LABELS[k] = def.btnLabel or k
            EP_HDR_LABELS[k] = def.hdrLabel or k
            table.insert(EP_KEY_ORDER, k)
        end
    end
    -- Load custom GP buttons
    if not s.gp_custom then s.gp_custom = {} end
    for _,def in ipairs(s.gp_custom) do
        local k = def.key
        if k and not GP_VALUES[k] then
            GP_VALUES[k]     = def.value or 1
            GP_LABELS[k]     = def.btnLabel or k
            GP_HDR_LABELS[k] = def.hdrLabel or k
            table.insert(GP_KEY_ORDER, k)
        end
    end
end

-- ============================================================
-- Accessors
-- ============================================================
local function GetEP(n)
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.ep then return 0 end
    return DarkIntentionsPointsDB.ep[n] or 0
end
local function GetGP(n)
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.gp then return DEFAULT_GP end
    return DarkIntentionsPointsDB.gp[n] or DEFAULT_GP
end
local function GetPR(n)
    local gp = GetGP(n)
    if gp == 0 then return 0 end
    return GetEP(n) / gp
end

-- ============================================================
-- History
-- ============================================================
local function RecordHistory(charName, epDelta, gpDelta, reason)
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.history then return end
    if not DarkIntentionsPointsDB.history[charName] then
        DarkIntentionsPointsDB.history[charName] = {}
    end
    table.insert(DarkIntentionsPointsDB.history[charName], {
        ep=epDelta, gp=gpDelta, reason=reason, date=date("%Y-%m-%d %H:%M"),
    })
end

-- ============================================================
-- Mutations
-- ============================================================
local ShowUnsavedWarning  -- defined later, after BuildMainFrame
local function AddEP(charName, pointType)
    InitDB()
    if not DarkIntentionsPointsDB.ep[charName] then DarkIntentionsPointsDB.ep[charName] = 0 end
    local pts = POINT_VALUES[pointType]
    DarkIntentionsPointsDB.ep[charName] = DarkIntentionsPointsDB.ep[charName] + pts
    RecordHistory(charName, pts, 0, BUTTON_LABELS[pointType])
    ShowUnsavedWarning()
    return DarkIntentionsPointsDB.ep[charName]
end

local function AddCustomEP(charName, pts, reason)
    InitDB()
    if not DarkIntentionsPointsDB.ep[charName] then DarkIntentionsPointsDB.ep[charName] = 0 end
    DarkIntentionsPointsDB.ep[charName] = DarkIntentionsPointsDB.ep[charName] + pts
    local label = (reason and reason ~= "") and reason or ("Custom EP "..(pts>=0 and "+" or "")..pts)
    RecordHistory(charName, pts, 0, label)
    ShowUnsavedWarning()
    return DarkIntentionsPointsDB.ep[charName]
end

local function SetGP(charName, newGP, reason)
    InitDB()
    local old = GetGP(charName)
    DarkIntentionsPointsDB.gp[charName] = newGP
    RecordHistory(charName, 0, newGP - old, reason or ("GP set to "..newGP))
    ShowUnsavedWarning()
end

local function ResetEP(charName)
    InitDB()
    local old = GetEP(charName)
    DarkIntentionsPointsDB.ep[charName] = 0
    RecordHistory(charName, -old, 0, "EP Reset to 0")
    ShowUnsavedWarning()
end

-- ============================================================
-- Roster helpers
-- ============================================================
local function IsInRoster(n)
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.roster then return false end
    for _,name in ipairs(DarkIntentionsPointsDB.roster) do if name==n then return true end end
    return false
end

local function AddToRoster(n)
    InitDB()
    if IsInRoster(n) then return false end
    table.insert(DarkIntentionsPointsDB.roster, n)
    if not DarkIntentionsPointsDB.ep[n] then DarkIntentionsPointsDB.ep[n] = 0 end
    if not DarkIntentionsPointsDB.gp[n] then DarkIntentionsPointsDB.gp[n] = DEFAULT_GP end
    ShowUnsavedWarning()
    return true
end

local function RemoveFromRoster(n)
    for i,name in ipairs(DarkIntentionsPointsDB.roster) do
        if name==n then
            table.remove(DarkIntentionsPointsDB.roster, i)
            DarkIntentionsPointsDB.ep[n] = nil
            DarkIntentionsPointsDB.gp[n] = nil
            DarkIntentionsPointsDB.history[n] = nil
            ShowUnsavedWarning()
            return true
        end
    end
    return false
end

-- ============================================================
-- Guild Master & Permissions
-- ============================================================
local function IsGuildMaster()
    local guildName, guildRank, guildRankIndex = C_GuildInfo.GetMyGuildInfo()
    if not guildName then return false end
    return guildRankIndex == 0
end

local function GetPlayerRankIndex()
    local guildName, guildRank, guildRankIndex = C_GuildInfo.GetMyGuildInfo()
    if not guildName then return -1 end
    return guildRankIndex
end

local function CanViewTab(tabName)
    if tabName == "roster" then return true end
    if IsGuildMaster() then return true end

    InitDB()
    local playerName = UnitName("player")
    local rankIdx = GetPlayerRankIndex()
    local perms = DarkIntentionsPointsDB.settings.permissions

    if tabName == "admin" then
        return false
    end

    if perms.charAccess[playerName] then return true end
    if rankIdx >= 0 and perms.rankAccess[rankIdx] then return true end

    return false
end

local function GetRosterByEP()
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.roster then return {} end
    local t = {}
    for _,n in ipairs(DarkIntentionsPointsDB.roster) do table.insert(t,n) end
    table.sort(t, function(a,b) return GetEP(a)>GetEP(b) end)
    return t
end

local function GetRosterByPR()
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.roster then return {} end
    local t = {}
    for _,n in ipairs(DarkIntentionsPointsDB.roster) do table.insert(t,n) end
    table.sort(t, function(a,b) return GetPR(a)>GetPR(b) end)
    return t
end

-- ============================================================
-- Layout constants
-- ============================================================
local GRP = { rosterRows={}, summaryRows={}, gpRows={}, guildRows={}, activeTab="summary" }

local ROW_H   = 32
local NAME_W  = 140
local BTN_W   = 118
local BTN_H   = 22
local BTN_GAP = 4
local PTS_W   = 54
local ICO_W   = 24
local ICO_GAP = 2
local TAB_H   = 34

local TOTAL_ROW_W = NAME_W + (BTN_W+BTN_GAP)*4 + PTS_W+4 + (ICO_W+ICO_GAP)*3 + ICO_W+4
local FRAME_W     = TOTAL_ROW_W + 30

-- Summary column widths
local S_NAME_W = 200
local S_EP_W   = 100
local S_GP_W   = 100
local S_PR_W   = 100

-- ============================================================
-- Widget helpers
-- ============================================================
local function StyledBtn(parent, lbl, w, h, r,g,b)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w,h) ; btn:SetText(lbl)
    btn:GetFontString():SetTextColor(1,1,1)
    local nt = btn:GetNormalTexture()     ; if nt then nt:SetVertexColor(r,g,b,0.85) end
    local hl = btn:GetHighlightTexture()  ; if hl then hl:SetVertexColor(r,g,b,1.0)  end
    return btn
end

local function IcoBtn(parent, lbl, tip, r,g,b)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(ICO_W, ICO_W) ; btn:SetText(lbl)
    btn:GetFontString():SetTextColor(1,1,1)
    btn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    local nt = btn:GetNormalTexture()    ; if nt then nt:SetVertexColor(r,g,b,0.85) end
    local hl = btn:GetHighlightTexture() ; if hl then hl:SetVertexColor(r,g,b,1.0)  end
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s,"ANCHOR_RIGHT") ; GameTooltip:SetText(tip,1,1,1) ; GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

local function GetClassColor(charName)
    for j=1,GetNumGuildMembers() do
        local name,_,_,_,_,_,_,_,_,_,classEN = GetGuildRosterInfo(j)
        if name then
            local sn = name:match("([^%-]+)")
            if sn==charName then
                local cc = RAID_CLASS_COLORS[classEN]
                if cc then return cc.r, cc.g, cc.b end
            end
        end
    end
    return 1,1,1
end

-- ============================================================
-- History Frame
-- ============================================================
local function ShowHistoryFrame(charName)
    if not GRP.historyFrame then
        local hf = CreateFrame("Frame","DIPHistoryFrame",UIParent,"BackdropTemplate")
        hf:SetSize(500,420)
        hf:SetPoint("CENTER",UIParent,"CENTER",80,0)
        hf:SetMovable(true) ; hf:EnableMouse(true)
        hf:RegisterForDrag("LeftButton")
        hf:SetScript("OnDragStart",hf.StartMoving)
        hf:SetScript("OnDragStop", hf.StopMovingOrSizing)
        hf:SetFrameStrata("HIGH")
        hf:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
            tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})

        hf.titleText = hf:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        hf.titleText:SetPoint("TOP",hf,"TOP",0,-20)

        local cb = CreateFrame("Button",nil,hf,"UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT",hf,"TOPRIGHT",-4,-4)
        cb:SetScript("OnClick",function() hf:Hide() end)

        local function H(txt,x,w,r,g,b)
            local fs = hf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            fs:SetPoint("TOPLEFT",hf,"TOPLEFT",x,-44)
            fs:SetWidth(w) ; fs:SetJustifyH("CENTER")
            fs:SetTextColor(r or 1,g or 1,b or 1) ; fs:SetText(txt)
        end
        H("Date / Time",18,140) ; H("Reason",162,210)
        H("EP",378,44,.4,.9,.4) ; H("GP",426,44,.9,.7,.2)

        local sep = hf:CreateTexture(nil,"BACKGROUND")
        sep:SetPoint("TOPLEFT",hf,"TOPLEFT",14,-56)
        sep:SetPoint("TOPRIGHT",hf,"TOPRIGHT",-14,-56)
        sep:SetHeight(1) ; sep:SetColorTexture(.4,.4,.5,.8)

        local sc = CreateFrame("ScrollFrame","DIPHistoryScroll",hf,"UIPanelScrollFrameTemplate")
        sc:SetPoint("TOPLEFT",hf,"TOPLEFT",14,-60)
        sc:SetPoint("BOTTOMRIGHT",hf,"BOTTOMRIGHT",-30,46)
        local child = CreateFrame("Frame",nil,sc)
        child:SetWidth(460) ; child:SetHeight(300) ; sc:SetScrollChild(child)
        hf.scrollChild = child

        hf.totalText = hf:CreateFontString(nil,"OVERLAY","GameFontNormal")
        hf.totalText:SetPoint("BOTTOMLEFT",hf,"BOTTOMLEFT",18,18)
        hf.totalText:SetTextColor(1,.85,0)

        hf.clearBtn = StyledBtn(hf,"Clear History",110,22,.6,.2,.2)
        hf.clearBtn:SetPoint("BOTTOMRIGHT",hf,"BOTTOMRIGHT",-14,14)
        hf.lines = {}
        GRP.historyFrame = hf
    end

    local hf = GRP.historyFrame
    hf.titleText:SetText("|cffffd700History: "..charName.."|r")
    hf.totalText:SetText(
        "EP:|cff00ff00 "..GetEP(charName).."|r  "..
        "GP:|cffffaa00 "..GetGP(charName).."|r  "..
        "PR:|cffffd700 "..string.format("%.2f",GetPR(charName)).."|r")
    hf.clearBtn:SetScript("OnClick",function()
        DarkIntentionsPointsDB.history[charName] = {}
        ShowHistoryFrame(charName)
    end)

    local hist = DarkIntentionsPointsDB.history[charName] or {}
    local rev  = {}
    for i=#hist,1,-1 do table.insert(rev,hist[i]) end

    local LH = 20
    hf.scrollChild:SetHeight(math.max(#rev*LH+10,60))

    while #hf.lines < #rev do
        local i = #hf.lines+1
        local y = -((i-1)*LH)-4
        local bg = hf.scrollChild:CreateTexture(nil,"BACKGROUND")
        bg:SetPoint("TOPLEFT", hf.scrollChild,"TOPLEFT", 2,y)
        bg:SetPoint("TOPRIGHT",hf.scrollChild,"TOPRIGHT",-2,y)
        bg:SetHeight(LH-1)
        if i%2==0 then bg:SetColorTexture(.12,.12,.18,.6) else bg:SetColorTexture(.08,.08,.12,.4) end
        local function FS(x,w,jh)
            local f = hf.scrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            f:SetPoint("TOPLEFT",hf.scrollChild,"TOPLEFT",x,y-3)
            f:SetWidth(w) ; f:SetJustifyH(jh or "LEFT")
            return f
        end
        table.insert(hf.lines,{bg=bg, d=FS(6,140), r=FS(150,210), ep=FS(364,44,"CENTER"), gp=FS(412,44,"CENTER")})
    end

    for i,ln in ipairs(hf.lines) do
        if i<=#rev then
            local e = rev[i]
            ln.d:SetText(e.date or "") ; ln.r:SetText(e.reason or "")
            local ev = e.ep or 0
            if ev>0 then ln.ep:SetText("|cff00ff00+"..ev.."|r")
            elseif ev<0 then ln.ep:SetText("|cffff4444"..ev.."|r")
            else ln.ep:SetText("|cffffffff\226\128\148|r") end
            local gv = e.gp or 0
            if gv>0 then ln.gp:SetText("|cffffaa00+"..gv.."|r")
            elseif gv<0 then ln.gp:SetText("|cffff8844"..gv.."|r")
            else ln.gp:SetText("|cffffffff\226\128\148|r") end
            ln.bg:Show() ; ln.d:Show() ; ln.r:Show() ; ln.ep:Show() ; ln.gp:Show()
        else
            ln.bg:Hide() ; ln.d:Hide() ; ln.r:Hide() ; ln.ep:Hide() ; ln.gp:Hide()
        end
    end
    hf:Show()
end

-- ============================================================
-- Custom Points Frame
-- ============================================================
local function ShowCustomFrame(charName, onConfirm, mode)
    -- mode: "ep" (default) or "gp"
    if not GRP.customFrame then
        local cf = CreateFrame("Frame","DIPCustomFrame",UIParent,"BackdropTemplate")
        cf:SetSize(360,230)
        cf:SetPoint("CENTER",UIParent,"CENTER",0,60)
        cf:SetMovable(true) ; cf:EnableMouse(true)
        cf:RegisterForDrag("LeftButton")
        cf:SetScript("OnDragStart",cf.StartMoving)
        cf:SetScript("OnDragStop", cf.StopMovingOrSizing)
        cf:SetFrameStrata("DIALOG")
        cf:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
            tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})

        cf.titleFS = cf:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        cf.titleFS:SetPoint("TOP",cf,"TOP",0,-20)

        local cb = CreateFrame("Button",nil,cf,"UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT",cf,"TOPRIGHT",-4,-4)
        cb:SetScript("OnClick",function() cf:Hide() end)

        local function Lbl(txt,y)
            local f = cf:CreateFontString(nil,"OVERLAY","GameFontNormal")
            f:SetPoint("TOPLEFT",cf,"TOPLEFT",18,y) ; f:SetText(txt)
            return f
        end
        local function Box(name,y)
            local b = CreateFrame("EditBox",name,cf,"InputBoxTemplate")
            b:SetSize(70,24) ; b:SetPoint("TOPRIGHT",cf,"TOPRIGHT",-18,y)
            b:SetAutoFocus(false) ; b:SetMaxLetters(7)
            return b
        end

        cf.epLbl = Lbl("|cff44ff44EP|r adjust (+/-):            ",  -52)
        cf.epBox = Box("DIPCustomEPBox", -48)
        cf.gpLbl = Lbl("|cffffaa00GP|r adjust (+/-):            ", -88)
        cf.gpBox = Box("DIPCustomGPBox", -84)

        local rl = cf:CreateFontString(nil,"OVERLAY","GameFontNormal")
        rl:SetPoint("TOPLEFT",cf,"TOPLEFT",18,-124) ; rl:SetText("Reason (optional):")
        cf.reasonBox = CreateFrame("EditBox","DIPCustomReasonBox",cf,"InputBoxTemplate")
        cf.reasonBox:SetSize(200,24)
        cf.reasonBox:SetPoint("TOPRIGHT",cf,"TOPRIGHT",-18,-120)
        cf.reasonBox:SetAutoFocus(false) ; cf.reasonBox:SetMaxLetters(64)

        cf.epBox:SetScript(    "OnEnterPressed", function() cf.gpBox:SetFocus() end)
        cf.gpBox:SetScript(    "OnEnterPressed", function() cf.reasonBox:SetFocus() end)
        cf.reasonBox:SetScript("OnEnterPressed", function() if cf.okBtn then cf.okBtn:Click() end end)

        cf.okBtn = StyledBtn(cf,"Confirm",100,24,.2,.7,.2)
        cf.okBtn:SetPoint("BOTTOMLEFT",cf,"BOTTOMLEFT",18,16)
        local cancel = StyledBtn(cf,"Cancel",80,24,.6,.2,.2)
        cancel:SetPoint("BOTTOMRIGHT",cf,"BOTTOMRIGHT",-18,16)
        cancel:SetScript("OnClick",function() cf:Hide() end)
        GRP.customFrame = cf
    end

    local cf = GRP.customFrame
    cf.titleFS:SetText("|cffffd700Edit: "..charName.."|r")
    cf.epBox:SetText("") ; cf.gpBox:SetText("") ; cf.reasonBox:SetText("")
    if mode == "gp" then
        cf.epLbl:Hide() ; cf.epBox:Hide()
        cf.gpLbl:Show() ; cf.gpBox:Show() ; cf.gpBox:SetText("")
    else
        cf.epLbl:Show() ; cf.epBox:Show()
        cf.gpLbl:Hide() ; cf.gpBox:Hide()
    end
    cf.okBtn:SetScript("OnClick",function()
        local er = cf.epBox:GetText()
        local gr = cf.gpBox:GetText()
        local rs = cf.reasonBox:GetText()
        local ed = er~="" and tonumber(er) or nil
        local gd = gr~="" and tonumber(gr) or nil
        if er~="" and not ed then print("|cffff4444[DIP]|r Invalid EP.") ; return end
        if gr~="" and not gd then print("|cffff4444[DIP]|r Invalid GP.") ; return end
        cf:Hide() ; onConfirm(ed,gd,rs)
    end)
    cf:Show() ; cf.epBox:SetFocus()
end

-- ============================================================
-- Forward declarations
-- ============================================================
local RefreshRoster
local RefreshSummary
local RefreshGP
local RefreshSettings
local RefreshGuildBrowser

ShowUnsavedWarning = function()
    if GRP.warnBar then GRP.warnBar:Show() end
end
local ShowTab

-- ============================================================
-- Effort Points roster rows
-- ============================================================
local function CreateRosterRow(parent, yOff)
    local row = {}
    row.bg = parent:CreateTexture(nil,"BACKGROUND")
    row.bg:SetHeight(ROW_H-2)
    row.bg:SetPoint("TOPLEFT", parent,"TOPLEFT",  4, yOff+1)
    row.bg:SetPoint("TOPRIGHT",parent,"TOPRIGHT", -4, yOff+1)
    row.bg:SetColorTexture(.1,.1,.15,.6)

    row.rank = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.rank:SetWidth(24)
    row.rank:SetPoint("TOPLEFT",parent,"TOPLEFT",8,yOff-6)
    row.rank:SetTextColor(1,1,1)

    row.name = parent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    row.name:SetWidth(NAME_W-30)
    row.name:SetPoint("TOPLEFT",parent,"TOPLEFT",32,yOff-6)
    row.name:SetJustifyH("LEFT")

    local x = NAME_W+4
    row.epBtns = {}
    for _,key in ipairs(EP_KEY_ORDER) do
        local r,g,b = 0.5,0.5,0.5
        if BUTTON_COLORS[key] then r,g,b = unpack(BUTTON_COLORS[key]) end
        local btn = StyledBtn(parent,BUTTON_LABELS[key],BTN_W,BTN_H,r,g,b)
        btn:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5)
        x = x+BTN_W+BTN_GAP
        row.epBtns[key] = btn
    end

    row.epBg = parent:CreateTexture(nil,"BACKGROUND")
    row.epBg:SetSize(PTS_W,ROW_H-6)
    row.epBg:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff+2)
    row.epBg:SetColorTexture(.05,.05,.1,.8)
    row.epTxt = parent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    row.epTxt:SetWidth(PTS_W)
    row.epTxt:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-6)
    row.epTxt:SetJustifyH("CENTER") ; row.epTxt:SetTextColor(.4,.9,.4)
    x = x+PTS_W+4

    row.bH  = IcoBtn(parent,"H",  "View history",      .3,.5,.9)
    row.bH:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5) ; x=x+ICO_W+ICO_GAP
    row.bC  = IcoBtn(parent,"+-","Edit EP",              .6,.3,.9)
    row.bC:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5) ; x=x+ICO_W+ICO_GAP
    row.bR  = IcoBtn(parent,"R", "Reset EP to 0",       .9,.4,.1)
    row.bR:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5)

    row.Hide = function(self)
        self.bg:Hide() ; self.rank:Hide() ; self.name:Hide()
        for _,b in pairs(self.epBtns) do b:Hide() end
        self.epBg:Hide() ; self.epTxt:Hide()
        self.bH:Hide() ; self.bC:Hide() ; self.bR:Hide()
    end
    row.Show = function(self)
        self.bg:Show() ; self.rank:Show() ; self.name:Show()
        for _,b in pairs(self.epBtns) do b:Show() end
        self.epBg:Show() ; self.epTxt:Show()
        self.bH:Show() ; self.bC:Show() ; self.bR:Show()
    end
    return row
end

RefreshRoster = function()
    if not GRP.epScrollChild then return end
    local roster = GetRosterByEP()
    local n = #roster
    GRP.epScrollChild:SetHeight(math.max(n*ROW_H+10,100))

    -- invalidate old rows when button count changes
    if GRP.rosterRows._keyCount ~= #EP_KEY_ORDER then
        for _,row in ipairs(GRP.rosterRows) do row:Hide() end
        GRP.rosterRows = { _keyCount = #EP_KEY_ORDER }
    end

    while #GRP.rosterRows < n do
        local i = #GRP.rosterRows+1
        table.insert(GRP.rosterRows, CreateRosterRow(GRP.epScrollChild, -((i-1)*ROW_H)-4))
    end

    for i,row in ipairs(GRP.rosterRows) do
        if i<=n then
            local cn = roster[i]
            row.rank:SetText(i..".") ; row.name:SetText(cn) ; row.epTxt:SetText(GetEP(cn))
            local r,g,b = GetClassColor(cn) ; row.name:SetTextColor(r,g,b)

            for _,key in ipairs(EP_KEY_ORDER) do
                local btn = row.epBtns[key]
                if btn then
                    btn:SetText(BUTTON_LABELS[key])
                    btn:SetScript("OnClick", function()
                        local ep = AddEP(cn,key)
                        row.epTxt:SetText(ep)
                        print("|cff00ff00[DIP]|r +"..POINT_VALUES[key].." EP ("..BUTTON_LABELS[key]..") for "..cn.."  EP:"..ep)
                        RefreshSummary()
                    end)
                end
            end

            row.bH:SetScript("OnClick", function() ShowHistoryFrame(cn) end)
            row.bC:SetScript("OnClick", function()
                ShowCustomFrame(cn, function(ed,gd,rs)
                    local msg = ""
                    if ed then
                        local ep = AddCustomEP(cn,ed,rs)
                        row.epTxt:SetText(ep)
                        msg = msg..(ed>=0 and "+" or "")..ed.." EP"
                    end
                    if gd then SetGP(cn,gd) ; msg = msg.."  GP->"..gd end
                    local rsn = (rs and rs~="") and (" ["..rs.."]") or ""
                    print("|cffbb88ff[DIP]|r "..cn..": "..msg..rsn)
                    RefreshRoster() ; RefreshSummary()
                end, false)
            end)
            row.bR:SetScript("OnClick", function()
                StaticPopupDialogs["DIP_RESET"] = {
                    text    = "Reset EP for |cffffd700"..cn.."|r to 0?",
                    button1 = "Reset", button2 = "Cancel",
                    OnAccept = function()
                        ResetEP(cn)
                        print("|cffffff00[DIP]|r EP reset for "..cn)
                        RefreshRoster() ; RefreshSummary()
                    end,
                    timeout=0, whileDead=true, hideOnEscape=true,
                }
                StaticPopup_Show("DIP_RESET")
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================================
-- Summary rows
-- ============================================================
local function CreateSummaryRow(parent, yOff)
    local row = {}

    row.bg = parent:CreateTexture(nil,"BACKGROUND")
    row.bg:SetHeight(ROW_H-2)
    row.bg:SetPoint("TOPLEFT", parent,"TOPLEFT",  4, yOff+1)
    row.bg:SetPoint("TOPRIGHT",parent,"TOPRIGHT", -4, yOff+1)

    row.rank = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.rank:SetWidth(28)
    row.rank:SetPoint("TOPLEFT",parent,"TOPLEFT",8,yOff-7)
    row.rank:SetTextColor(1,1,1)

    row.name = parent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    row.name:SetWidth(S_NAME_W)
    row.name:SetPoint("TOPLEFT",parent,"TOPLEFT",38,yOff-7)
    row.name:SetJustifyH("LEFT")

    local x = 38+S_NAME_W+6
    row.ep = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.ep:SetWidth(S_EP_W)
    row.ep:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-7)
    row.ep:SetJustifyH("CENTER") ; row.ep:SetTextColor(.4,.9,.4)
    x = x+S_EP_W+6

    row.gp = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.gp:SetWidth(S_GP_W)
    row.gp:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-7)
    row.gp:SetJustifyH("CENTER") ; row.gp:SetTextColor(1,.7,.2)
    x = x+S_GP_W+6

    row.pr = parent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    row.pr:SetWidth(S_PR_W)
    row.pr:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-7)
    row.pr:SetJustifyH("CENTER") ; row.pr:SetTextColor(1,.85,0)
    x = x+S_PR_W+6

    row.you = parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.you:SetWidth(42)
    row.you:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-7)
    row.you:SetTextColor(.4,1,1)
    x = x+42+4

    row.bX = IcoBtn(parent,"X","Remove from roster", .7,.1,.1)
    row.bX:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-6)

    local ALL = {"bg","rank","name","ep","gp","pr","you","bX"}
    row.Hide = function(self) for _,k in ipairs(ALL) do self[k]:Hide() end end
    row.Show = function(self) for _,k in ipairs(ALL) do self[k]:Show() end end
    return row
end

RefreshSummary = function()
    if not GRP.sumScrollChild then return end

    local player = UnitName("player")
    local byPR   = GetRosterByPR()

    -- pin player to top
    local playerInRoster = false
    for _,n in ipairs(byPR) do if n==player then playerInRoster=true ; break end end
    local ordered = {}
    if playerInRoster then
        table.insert(ordered,player)
        for _,n in ipairs(byPR) do if n~=player then table.insert(ordered,n) end end
    else
        ordered = byPR
    end

    local n = #ordered
    GRP.sumScrollChild:SetHeight(math.max(n*ROW_H+10,100))

    while #GRP.summaryRows < n do
        local i = #GRP.summaryRows+1
        table.insert(GRP.summaryRows, CreateSummaryRow(GRP.sumScrollChild, -((i-1)*ROW_H)-4))
    end

    -- build PR-rank lookup
    local prRank = {}
    for i,nm in ipairs(byPR) do prRank[nm]=i end

    for i,row in ipairs(GRP.summaryRows) do
        if i<=n then
            local cn  = ordered[i]
            local isMe = (cn==player)

            if isMe then
                row.bg:SetColorTexture(.22,.18,.05,.9)
            elseif i%2==0 then
                row.bg:SetColorTexture(.10,.10,.16,.6)
            else
                row.bg:SetColorTexture(.07,.07,.12,.4)
            end

            if isMe then
                row.rank:SetText("\226\152\133") -- ★
                row.rank:SetTextColor(1,.85,0)
            else
                row.rank:SetText((prRank[cn] or i)..".") ; row.rank:SetTextColor(1,1,1)
            end

            local r,g,b = GetClassColor(cn)
            row.name:SetText(cn) ; row.name:SetTextColor(r,g,b)
            row.ep:SetText(GetEP(cn))
            row.gp:SetText(GetGP(cn))
            row.pr:SetText(string.format("%.2f",GetPR(cn)))
            row.you:SetText(isMe and "< You" or "")
            row.bX:SetScript("OnClick", function()
                StaticPopupDialogs["DIP_REMOVE"] = {
                    text    = "Remove |cffffd700"..cn.."|r from the roster?",
                    button1 = "Remove", button2 = "Cancel",
                    OnAccept = function()
                        RemoveFromRoster(cn)
                        print("|cffffff00[DIP]|r Removed "..cn.." from roster.")
                        RefreshSummary() ; RefreshRoster() ; RefreshGP()
                    end,
                    timeout=0, whileDead=true, hideOnEscape=true,
                }
                StaticPopup_Show("DIP_REMOVE")
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================================
-- Gear Points rows + refresh
-- ============================================================
local GP_BTN_W   = 132
local GP_BTN_GAP = 4
local GP_VAL_W   = 60

local function CreateGPRow(parent, yOff)
    local row = {}

    row.bg = parent:CreateTexture(nil,"BACKGROUND")
    row.bg:SetHeight(ROW_H-2)
    row.bg:SetPoint("TOPLEFT", parent,"TOPLEFT",  4, yOff+1)
    row.bg:SetPoint("TOPRIGHT",parent,"TOPRIGHT", -4, yOff+1)
    row.bg:SetColorTexture(.1,.08,.04,.6)

    row.rank = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    row.rank:SetWidth(24)
    row.rank:SetPoint("TOPLEFT",parent,"TOPLEFT",8,yOff-6)
    row.rank:SetTextColor(1,1,1)

    row.name = parent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    row.name:SetWidth(NAME_W-30)
    row.name:SetPoint("TOPLEFT",parent,"TOPLEFT",32,yOff-6)
    row.name:SetJustifyH("LEFT")

    local x = NAME_W+4
    row.gpBtns = {}
    local colors = { {.3,.7,.3}, {.8,.5,.1}, {.5,.3,.8}, {.2,.7,.8}, {.8,.2,.4} }
    for ci,key in ipairs(GP_KEY_ORDER) do
        local rc = colors[ci] or {1,1,1}
        local btn = StyledBtn(parent,GP_LABELS[key],GP_BTN_W,BTN_H,rc[1],rc[2],rc[3])
        btn:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5)
        x = x+GP_BTN_W+GP_BTN_GAP
        row.gpBtns[key] = btn
    end

    row.gpBg = parent:CreateTexture(nil,"BACKGROUND")
    row.gpBg:SetSize(GP_VAL_W,ROW_H-6)
    row.gpBg:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff+2)
    row.gpBg:SetColorTexture(.1,.06,.02,.8)

    row.gpTxt = parent:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    row.gpTxt:SetWidth(GP_VAL_W)
    row.gpTxt:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-6)
    row.gpTxt:SetJustifyH("CENTER")
    row.gpTxt:SetTextColor(1,.7,.2)
    x = x+GP_VAL_W+4

    row.bH = IcoBtn(parent,"H",  "View history",        .3,.5,.9)
    row.bH:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5) ; x=x+ICO_W+ICO_GAP

    row.bE = IcoBtn(parent,"+-","Edit GP",               .6,.3,.9)
    row.bE:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5) ; x=x+ICO_W+ICO_GAP+2

    row.bR = IcoBtn(parent,"R", "Reset GP to default ("..DEFAULT_GP..")", .9,.4,.1)
    row.bR:SetPoint("TOPLEFT",parent,"TOPLEFT",x,yOff-5)

    row.Hide = function(self)
        self.bg:Hide() ; self.rank:Hide() ; self.name:Hide()
        for _,b in pairs(self.gpBtns) do b:Hide() end
        self.gpBg:Hide() ; self.gpTxt:Hide()
        self.bH:Hide() ; self.bE:Hide() ; self.bR:Hide()
    end
    row.Show = function(self)
        self.bg:Show() ; self.rank:Show() ; self.name:Show()
        for _,b in pairs(self.gpBtns) do b:Show() end
        self.gpBg:Show() ; self.gpTxt:Show()
        self.bH:Show() ; self.bE:Show() ; self.bR:Show()
    end
    return row
end

local function GetRosterByGP()
    if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.roster then return {} end
    local t = {}
    for _,n in ipairs(DarkIntentionsPointsDB.roster) do table.insert(t,n) end
    table.sort(t, function(a,b) return GetGP(a) > GetGP(b) end)
    return t
end

RefreshGP = function()
    if not GRP.gpScrollChild then return end
    local roster = GetRosterByGP()
    local n = #roster
    GRP.gpScrollChild:SetHeight(math.max(n*ROW_H+10,100))

    -- invalidate old rows when button count changes
    if GRP.gpRows._keyCount ~= #GP_KEY_ORDER then
        for _,row in ipairs(GRP.gpRows) do row:Hide() end
        GRP.gpRows = { _keyCount = #GP_KEY_ORDER }
    end

    while #GRP.gpRows < n do
        local i = #GRP.gpRows+1
        table.insert(GRP.gpRows, CreateGPRow(GRP.gpScrollChild, -((i-1)*ROW_H)-4))
    end

    for i,row in ipairs(GRP.gpRows) do
        if i<=n then
            local cn = roster[i]
            row.rank:SetText(i..".")
            row.name:SetText(cn)
            local r,g,b = GetClassColor(cn) ; row.name:SetTextColor(r,g,b)
            row.gpTxt:SetText(GetGP(cn))

            for _,key in ipairs(GP_KEY_ORDER) do
                local btn = row.gpBtns[key]
                if btn then
                    btn:SetText(GP_LABELS[key])
                    local val = GP_VALUES[key] or 1
                    btn:SetScript("OnClick", function()
                        InitDB()
                        local newGP = GetGP(cn) + val
                        SetGP(cn, newGP, GP_LABELS[key])
                        row.gpTxt:SetText(newGP)
                        print("|cffffaa00[DIP]|r +"..val.." GP ("..GP_LABELS[key]..") for "..cn.."  GP:"..newGP)
                        RefreshSummary()
                    end)
                end
            end

            row.bH:SetScript("OnClick", function()
                ShowHistoryFrame(cn)
            end)
            row.bE:SetScript("OnClick", function()
                ShowCustomFrame(cn, function(ed,gd,rs)
                    local msg = ""
                    if gd then
                        SetGP(cn,gd)
                        row.gpTxt:SetText(gd)
                        msg = msg.."GP->"..gd
                    end
                    local rsn = (rs and rs~="") and (" ["..rs.."]") or ""
                    print("|cffbb88ff[DIP]|r "..cn..": "..msg..rsn)
                    RefreshGP() ; RefreshSummary()
                end, "gp")
            end)
            row.bR:SetScript("OnClick", function()
                StaticPopupDialogs["DIP_RESET_GP"] = {
                    text    = "Reset GP for |cffffd700"..cn.."|r to default ("..DEFAULT_GP..")?",
                    button1 = "Reset", button2 = "Cancel",
                    OnAccept = function()
                        InitDB()
                        SetGP(cn, DEFAULT_GP)
                        print("|cffffff00[DIP]|r GP reset to "..DEFAULT_GP.." for "..cn)
                        RefreshGP() ; RefreshSummary()
                    end,
                    timeout=0, whileDead=true, hideOnEscape=true,
                }
                StaticPopup_Show("DIP_RESET_GP")
            end)

            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================================
-- Tab button builder  (fully custom — no UIPanelButtonTemplate)
-- ============================================================
local function MakeTabBtn(parent, label, xLeft)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(126, TAB_H-4)
    btn:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",xLeft,13)
    btn:SetFrameLevel(parent:GetFrameLevel()+5)

    -- inactive background
    local bgTex = btn:CreateTexture(nil,"BACKGROUND")
    bgTex:SetAllPoints(btn)
    bgTex:SetColorTexture(.15,.12,.28,.95)
    btn._bg = bgTex

    -- hover highlight
    local hl = btn:CreateTexture(nil,"HIGHLIGHT")
    hl:SetAllPoints(btn) ; hl:SetColorTexture(.3,.24,.50,.6)

    -- borders (top + left + right)
    local function Border(p1,p2,isH)
        local t = btn:CreateTexture(nil,"BORDER")
        t:SetPoint(p1,btn,p1,0,0) ; t:SetPoint(p2,btn,p2,0,0)
        if isH then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(.45,.35,.65,.7)
    end
    Border("TOPLEFT","TOPRIGHT",true)
    Border("TOPLEFT","BOTTOMLEFT",false)
    Border("TOPRIGHT","BOTTOMRIGHT",false)

    -- active gold underline
    local ul = btn:CreateTexture(nil,"OVERLAY")
    ul:SetPoint("BOTTOMLEFT", btn,"BOTTOMLEFT", 3,2)
    ul:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-3,2)
    ul:SetHeight(3) ; ul:SetColorTexture(1,.82,0,1) ; ul:Hide()
    btn._ul = ul

    -- label font string
    local lbl = btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    lbl:SetAllPoints(btn) ; lbl:SetJustifyH("CENTER") ; lbl:SetJustifyV("MIDDLE")
    lbl:SetText(label) ; lbl:SetTextColor(1,1,1)
    btn._lbl = lbl

    function btn:SetActive(on)
        if on then
            self._bg:SetColorTexture(.28,.22,.48,.98)
            self._lbl:SetTextColor(1,.85,0)
            self._ul:Show()
        else
            self._bg:SetColorTexture(.15,.12,.28,.95)
            self._lbl:SetTextColor(1,1,1)
            self._ul:Hide()
        end
    end

    return btn
end

-- ============================================================
-- Tab switcher
-- ============================================================
ShowTab = function(name)
    if not CanViewTab(name) then
        name = "roster"
    end
    GRP.activeTab = name
    if not GRP.summaryPanel or not GRP.epPanel or not GRP.gpPanel or not GRP.guildPanel or not GRP.settingsPanel or not GRP.adminPanel then return end

    GRP.summaryPanel:Hide() ; GRP.epPanel:Hide() ; GRP.gpPanel:Hide()
    GRP.guildPanel:Hide()   ; GRP.settingsPanel:Hide() ; GRP.adminPanel:Hide()
    if GRP.tabSummary  then GRP.tabSummary:SetActive(false)  end
    if GRP.tabEP       then GRP.tabEP:SetActive(false)       end
    if GRP.tabGP       then GRP.tabGP:SetActive(false)       end
    if GRP.tabGuild    then GRP.tabGuild:SetActive(false)    end
    if GRP.tabSettings then GRP.tabSettings:SetActive(false) end
    if GRP.tabAdmin    then GRP.tabAdmin:SetActive(false)    end

    if name == "summary" then
        GRP.summaryPanel:Show()
        if GRP.tabSummary then GRP.tabSummary:SetActive(true) end
        RefreshSummary()
    elseif name == "gearpoints" then
        GRP.gpPanel:Show()
        if GRP.tabGP then GRP.tabGP:SetActive(true) end
        RefreshGP()
    elseif name == "guild" then
        GRP.guildPanel:Show()
        if GRP.tabGuild then GRP.tabGuild:SetActive(true) end
        C_GuildInfo.GuildRoster()
        C_Timer.After(0.3, RefreshGuildBrowser)
    elseif name == "settings" then
        GRP.settingsPanel:Show()
        if GRP.tabSettings then GRP.tabSettings:SetActive(true) end
        RefreshSettings()
    elseif name == "admin" then
        GRP.adminPanel:Show()
        if GRP.tabAdmin then GRP.tabAdmin:SetActive(true) end
        RefreshAdmin()
    else
        GRP.epPanel:Show()
        if GRP.tabEP then GRP.tabEP:SetActive(true) end
        RefreshRoster()
    end
end

-- ============================================================
-- Tab Visibility Management
-- ============================================================
local function UpdateTabVisibility()
    local tabsInfo = {
        {"summary", GRP.tabSummary},
        {"effortpoints", GRP.tabEP},
        {"gearpoints", GRP.tabGP},
        {"guild", GRP.tabGuild},
        {"settings", GRP.tabSettings},
        {"admin", GRP.tabAdmin}
    }

    for _,info in ipairs(tabsInfo) do
        local tabName, tabBtn = info[1], info[2]
        if tabBtn then
            if CanViewTab(tabName) then
                tabBtn:Show()
            else
                tabBtn:Hide()
            end
        end
    end

    if not CanViewTab(GRP.activeTab) then
        ShowTab("roster")
    end
end

-- ============================================================
-- Build Main Frame
-- ============================================================
local function BuildMainFrame()
    if GRP.mainFrame then GRP.mainFrame:Show() ; return end

    local f = CreateFrame("Frame","DIPMainFrame",UIParent,"BackdropTemplate")
    f:SetSize(FRAME_W+360, 520+TAB_H)
    f:SetPoint("CENTER",UIParent,"CENTER")
    f:SetMovable(true) ; f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("MEDIUM")
    f:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})

    -- title bar
    local tbg = f:CreateTexture(nil,"BACKGROUND")
    tbg:SetPoint("TOPLEFT",f,"TOPLEFT",12,-12)
    tbg:SetPoint("TOPRIGHT",f,"TOPRIGHT",-12,-12)
    tbg:SetHeight(28) ; tbg:SetColorTexture(.08,.08,.18,.95)

    local ttl = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    ttl:SetPoint("TOP",f,"TOP",0,-20)
    ttl:SetText("|cffffd700Dark Intentions Points|r")

    local cb = CreateFrame("Button",nil,f,"UIPanelCloseButton")
    cb:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4)
    cb:SetScript("OnClick",function() f:Hide() end)

    -- tab bar strip
    local tabBg = f:CreateTexture(nil,"BACKGROUND")
    tabBg:SetPoint("BOTTOMLEFT", f,"BOTTOMLEFT",  12,12)
    tabBg:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT", -12,12)
    tabBg:SetHeight(TAB_H) ; tabBg:SetColorTexture(.04,.04,.09,.98)

    local tabLine = f:CreateTexture(nil,"BORDER")
    tabLine:SetPoint("BOTTOMLEFT", f,"BOTTOMLEFT",  12,12+TAB_H)
    tabLine:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,12+TAB_H)
    tabLine:SetHeight(1) ; tabLine:SetColorTexture(.45,.35,.65,.8)

    -- tab buttons  (6 tabs, each 126px wide with ~4px gap = 130 steps)
    GRP.tabSummary  = MakeTabBtn(f,"Raid Roster",   18)
    GRP.tabEP       = MakeTabBtn(f,"Effort Points", 148)
    GRP.tabGP       = MakeTabBtn(f,"Gear Points",   278)
    GRP.tabGuild    = MakeTabBtn(f,"Guild",         408)
    GRP.tabSettings = MakeTabBtn(f,"Settings",      538)
    GRP.tabAdmin    = MakeTabBtn(f,"Admin",         668)
    GRP.tabSummary:SetScript( "OnClick",function() ShowTab("summary")      end)
    GRP.tabEP:SetScript(      "OnClick",function() ShowTab("effortpoints") end)
    GRP.tabGP:SetScript(      "OnClick",function() ShowTab("gearpoints")   end)
    GRP.tabGuild:SetScript(   "OnClick",function() ShowTab("guild")        end)
    GRP.tabSettings:SetScript("OnClick",function() ShowTab("settings")     end)
    GRP.tabAdmin:SetScript(   "OnClick",function() ShowTab("admin")        end)

    -- ── unsaved-changes warning bar ───────────────────────────
    local warnBar = CreateFrame("Frame",nil,f)
    warnBar:SetPoint("TOPLEFT", f,"TOPLEFT",  12,-44)
    warnBar:SetPoint("TOPRIGHT",f,"TOPRIGHT", -12,-44)
    warnBar:SetHeight(26)
    warnBar:Hide()

    local warnBg = warnBar:CreateTexture(nil,"BACKGROUND")
    warnBg:SetAllPoints(warnBar)
    warnBg:SetColorTexture(.35,.18,.02,.95)

    local warnTxt = warnBar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    warnTxt:SetPoint("LEFT",warnBar,"LEFT",10,0)
    warnTxt:SetText("|cffffcc00⚠|r  Changes are not saved until you log out or reload.")
    warnTxt:SetTextColor(1,.85,.4)

    local reloadBtn = StyledBtn(warnBar,"Reload To Save Changes",170,20,.5,.25,.02)
    reloadBtn:SetPoint("RIGHT",warnBar,"RIGHT",-6,0)
    reloadBtn:SetScript("OnClick", function() ReloadUI() end)

    GRP.warnBar = warnBar

    -- content area (sits below warnBar when visible, below title otherwise)
    local content = CreateFrame("Frame","DIPContent",f)
    content:SetPoint("TOPLEFT",    f,"TOPLEFT",   12,-44)
    content:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-12,12+TAB_H+2)

    -- push content down when warning bar shows
    local function ApplyWarnLayout()
        content:SetPoint("TOPLEFT","DIPMainFrame","TOPLEFT",12, warnBar:IsShown() and -72 or -44)
    end
    warnBar:SetScript("OnShow", ApplyWarnLayout)
    warnBar:SetScript("OnHide", ApplyWarnLayout)

    -- ============================================================
    -- SUMMARY PANEL
    -- ============================================================
    local sumPanel = CreateFrame("Frame","DIPSummaryPanel",content)
    sumPanel:SetAllPoints(content)

    local function SHdr(txt,x,w,r,g,b)
        local h = sumPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        h:SetPoint("TOPLEFT",sumPanel,"TOPLEFT",x,-2)
        h:SetWidth(w) ; h:SetJustifyH("CENTER")
        h:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
        h:SetTextColor(r or 1,g or 1,b or 1) ; h:SetText(txt)
        h:SetWordWrap(false)
    end
    SHdr("Character",38,S_NAME_W, 1,1,1)
    local sx = 38+S_NAME_W+6
    SHdr("EP (Effort Pts)", sx,S_EP_W,.4,.9,.4) ; sx=sx+S_EP_W+6
    SHdr("GP (Gear Pts)",   sx,S_GP_W,1,.7,.2)  ; sx=sx+S_GP_W+6
    SHdr("PR (EP / GP)",    sx,S_PR_W,1,.85,0)  ; sx=sx+S_PR_W+6+42+4

    local sHdrSep = sumPanel:CreateTexture(nil,"BACKGROUND")
    sHdrSep:SetPoint("TOPLEFT", sumPanel,"TOPLEFT", 0,-20)
    sHdrSep:SetPoint("TOPRIGHT",sumPanel,"TOPRIGHT",0,-20)
    sHdrSep:SetHeight(1) ; sHdrSep:SetColorTexture(.4,.4,.5,.6)

    local sumScroll = CreateFrame("ScrollFrame","DIPSumScroll",sumPanel,"UIPanelScrollFrameTemplate")
    sumScroll:SetPoint("TOPLEFT",    sumPanel,"TOPLEFT",   2,-24)
    sumScroll:SetPoint("BOTTOMRIGHT",sumPanel,"BOTTOMRIGHT",-20,4)
    local sumChild = CreateFrame("Frame","DIPSumChild",sumScroll)
    sumChild:SetWidth(600) ; sumChild:SetHeight(400)
    sumScroll:SetScrollChild(sumChild)
    GRP.sumScrollChild = sumChild
    GRP.summaryPanel   = sumPanel

    -- ============================================================
    -- EFFORT POINTS PANEL
    -- ============================================================
    local epPanel = CreateFrame("Frame","DIPEPPanel",content)
    epPanel:SetAllPoints(content)

    local function EHdr(txt,x,w,r,g,b)
        local h = epPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        h:SetPoint("TOPLEFT",epPanel,"TOPLEFT",x,-2)
        h:SetWidth(w) ; h:SetJustifyH("CENTER")
        h:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
        h:SetTextColor(r or 1,g or 1,b or 1) ; h:SetText(txt)
        h:SetWordWrap(false)
    end
    EHdr("Character",2,NAME_W, 1,1,1)
    GRP.epHdrs = {}
    GRP.epHdrParent = epPanel
    GRP.epHdrBaseX  = NAME_W+2

    local epTrailingHdrs = {}
    local function RebuildEPHeaders()
        for _,h in pairs(GRP.epHdrs) do h:Hide() end
        for _,h in ipairs(epTrailingHdrs) do h:Hide() end
        GRP.epHdrs = {} ; epTrailingHdrs = {}
        if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.roster or #DarkIntentionsPointsDB.roster == 0 then return end
        local ex = GRP.epHdrBaseX
        for _,key in ipairs(EP_KEY_ORDER) do
            local h = GRP.epHdrParent:CreateFontString(nil,"OVERLAY","GameFontNormal")
            h:SetPoint("TOPLEFT",GRP.epHdrParent,"TOPLEFT",ex,-2)
            h:SetWidth(BTN_W) ; h:SetJustifyH("CENTER")
            h:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
            h:SetTextColor(1,1,1) ; h:SetText(EP_HDR_LABELS[key]) ; h:SetWordWrap(false)
            GRP.epHdrs[key] = h
            ex = ex+BTN_W+BTN_GAP
        end
        local eh = GRP.epHdrParent:CreateFontString(nil,"OVERLAY","GameFontNormal")
        eh:SetPoint("TOPLEFT",GRP.epHdrParent,"TOPLEFT",ex,-2)
        eh:SetWidth(PTS_W) ; eh:SetJustifyH("CENTER")
        eh:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
        eh:SetTextColor(.4,.9,.4) ; eh:SetText("EP") ; eh:SetWordWrap(false)
        table.insert(epTrailingHdrs, eh)
    end
    RebuildEPHeaders()
    GRP.RebuildEPHeaders = RebuildEPHeaders

    local eHdrSep = epPanel:CreateTexture(nil,"BACKGROUND")
    eHdrSep:SetPoint("TOPLEFT", epPanel,"TOPLEFT", 0,-20)
    eHdrSep:SetPoint("TOPRIGHT",epPanel,"TOPRIGHT",0,-20)
    eHdrSep:SetHeight(1) ; eHdrSep:SetColorTexture(.4,.4,.5,.6)

    local epScroll = CreateFrame("ScrollFrame","DIPRosterScroll",epPanel,"UIPanelScrollFrameTemplate")
    epScroll:SetPoint("TOPLEFT",    epPanel,"TOPLEFT",   2,-24)
    epScroll:SetPoint("BOTTOMRIGHT",epPanel,"BOTTOMRIGHT",-20,4)
    local epChild = CreateFrame("Frame","DIPRosterChild",epScroll)
    epChild:SetWidth(FRAME_W-20) ; epChild:SetHeight(400)
    epScroll:SetScrollChild(epChild)
    GRP.epScrollChild = epChild
    GRP.epPanel       = epPanel

    GRP.mainFrame = f

    -- ============================================================
    -- GEAR POINTS PANEL
    -- ============================================================
    local gpPanel = CreateFrame("Frame","DIPGPPanel",content)
    gpPanel:SetAllPoints(content)

    local function GHdr(txt,x,w,r,g,b)
        local h = gpPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        h:SetPoint("TOPLEFT",gpPanel,"TOPLEFT",x,-2)
        h:SetWidth(w) ; h:SetJustifyH("CENTER")
        h:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
        h:SetTextColor(r or 1,g or 1,b or 1) ; h:SetText(txt)
        h:SetWordWrap(false)
    end
    GHdr("Character",  2,  NAME_W, 1,1,1)
    GRP.gpHdrs = {}
    GRP.gpHdrParent = gpPanel
    GRP.gpHdrBaseX  = NAME_W+2

    local gpTrailingHdrs = {}
    local function RebuildGPHeaders()
        for _,h in pairs(GRP.gpHdrs) do h:Hide() end
        for _,h in ipairs(gpTrailingHdrs) do h:Hide() end
        GRP.gpHdrs = {} ; gpTrailingHdrs = {}
        if not DarkIntentionsPointsDB or not DarkIntentionsPointsDB.roster or #DarkIntentionsPointsDB.roster == 0 then return end
        local colors = { {.3,.8,.3}, {.9,.6,.1}, {.6,.4,.9}, {.2,.8,.8}, {.9,.3,.5} }
        local gx = GRP.gpHdrBaseX
        for ci,key in ipairs(GP_KEY_ORDER) do
            local rc = colors[ci] or {.7,.7,.7}
            local h = GRP.gpHdrParent:CreateFontString(nil,"OVERLAY","GameFontNormal")
            h:SetPoint("TOPLEFT",GRP.gpHdrParent,"TOPLEFT",gx,-2)
            h:SetWidth(GP_BTN_W) ; h:SetJustifyH("CENTER")
            h:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
            h:SetTextColor(rc[1],rc[2],rc[3]) ; h:SetText(GP_HDR_LABELS[key]) ; h:SetWordWrap(false)
            GRP.gpHdrs[key] = h
            gx = gx+GP_BTN_W+GP_BTN_GAP
        end
        local gh = GRP.gpHdrParent:CreateFontString(nil,"OVERLAY","GameFontNormal")
        gh:SetPoint("TOPLEFT",GRP.gpHdrParent,"TOPLEFT",gx,-2)
        gh:SetWidth(GP_VAL_W) ; gh:SetJustifyH("CENTER")
        gh:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
        gh:SetTextColor(1,.7,.2) ; gh:SetText("GP") ; gh:SetWordWrap(false)
        table.insert(gpTrailingHdrs, gh)
    end
    RebuildGPHeaders()
    GRP.RebuildGPHeaders = RebuildGPHeaders

    local gpHdrSep = gpPanel:CreateTexture(nil,"BACKGROUND")
    gpHdrSep:SetPoint("TOPLEFT", gpPanel,"TOPLEFT", 0,-20)
    gpHdrSep:SetPoint("TOPRIGHT",gpPanel,"TOPRIGHT",0,-20)
    gpHdrSep:SetHeight(1) ; gpHdrSep:SetColorTexture(.4,.4,.5,.6)

    local gpScroll = CreateFrame("ScrollFrame","DIPGPScroll",gpPanel,"UIPanelScrollFrameTemplate")
    gpScroll:SetPoint("TOPLEFT",    gpPanel,"TOPLEFT",   2,-24)
    gpScroll:SetPoint("BOTTOMRIGHT",gpPanel,"BOTTOMRIGHT",-20,4)
    local gpChild = CreateFrame("Frame","DIPGPChild",gpScroll)
    gpChild:SetWidth(FRAME_W-20) ; gpChild:SetHeight(400)
    gpScroll:SetScrollChild(gpChild)
    GRP.gpScrollChild = gpChild
    GRP.gpPanel       = gpPanel

    -- ============================================================
    -- SETTINGS PANEL
    -- ============================================================
    local stPanel = CreateFrame("Frame","DIPSettingsPanel",content)
    stPanel:SetAllPoints(content)
    stPanel:Hide()

    -- scrollable body
    local stScroll = CreateFrame("ScrollFrame","DIPStScroll",stPanel,"UIPanelScrollFrameTemplate")
    stScroll:SetPoint("TOPLEFT",    stPanel,"TOPLEFT",   0, -4)
    stScroll:SetPoint("BOTTOMRIGHT",stPanel,"BOTTOMRIGHT",-20, 4)
    local stChild = CreateFrame("Frame",nil,stScroll)
    stChild:SetWidth(600) ; stChild:SetHeight(1200)
    stScroll:SetScrollChild(stChild)

    local function StLabel(parent,txt,x,y)
        local fs = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
        fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
        fs:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        fs:SetText(txt) ; fs:SetTextColor(1,.85,0)
        return fs
    end

    local function StSep(parent,y)
        local s = parent:CreateTexture(nil,"BACKGROUND")
        s:SetPoint("TOPLEFT", parent,"TOPLEFT",0,y)
        s:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,y)
        s:SetHeight(1) ; s:SetColorTexture(.4,.4,.5,.5)
    end

    -- "Add button" popup builder (reused for EP and GP)
    local function ShowAddButtonPopup(forEP, onConfirm)
        local pf = CreateFrame("Frame","DIPAddBtnPopup",UIParent,"BackdropTemplate")
        pf:SetSize(420,200)
        pf:SetPoint("CENTER")
        pf:SetFrameStrata("DIALOG")
        pf:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
            tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
        pf:SetMovable(true) ; pf:EnableMouse(true)
        pf:RegisterForDrag("LeftButton")
        pf:SetScript("OnDragStart",pf.StartMoving)
        pf:SetScript("OnDragStop", pf.StopMovingOrSizing)

        local title = pf:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOP",pf,"TOP",0,-14)
        title:SetText(forEP and "|cff88ddffAdd EP Button|r" or "|cffffaa44Add GP Button|r")

        local function FieldRow(parent, lbl, y)
            local fs = parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            fs:SetPoint("TOPLEFT",parent,"TOPLEFT",14,y)
            fs:SetWidth(100) ; fs:SetJustifyH("LEFT") ; fs:SetTextColor(.8,.8,.8) ; fs:SetText(lbl)
            local box = CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
            box:SetPoint("TOPLEFT",parent,"TOPLEFT",120,y+3)
            box:SetSize(270,22) ; box:SetAutoFocus(false) ; box:SetMaxLetters(64)
            return box
        end

        local btnBox = FieldRow(pf,"Button text:", -42)
        local hdrBox = FieldRow(pf,"Header text:", -70)
        local valBox = FieldRow(pf,"Point value:", -98)
        valBox:SetText("1") ; valBox:SetCursorPosition(0)

        local ok = StyledBtn(pf,"Add",80,24,.2,.6,.2)
        ok:SetPoint("BOTTOMLEFT",pf,"BOTTOMLEFT",14,12)
        ok:SetScript("OnClick",function()
            local btnTxt = btnBox:GetText()
            local hdrTxt = hdrBox:GetText()
            local val    = tonumber(valBox:GetText())
            if btnTxt=="" then print("|cffff4444[DIP]|r Button text required.") ; return end
            if not val    then print("|cffff4444[DIP]|r Point value must be a number.") ; return end
            hdrTxt = (hdrTxt~="" and hdrTxt) or btnTxt
            pf:Hide()
            onConfirm(btnTxt, hdrTxt, val)
        end)

        local cancel = StyledBtn(pf,"Cancel",80,24,.5,.2,.2)
        cancel:SetPoint("BOTTOMLEFT",pf,"BOTTOMLEFT",100,12)
        cancel:SetScript("OnClick",function() pf:Hide() end)

        btnBox:SetFocus()
    end

    -- pool of widget frames we can hide/show per rebuild
    GRP.stWidgets = {}

    local function ClearStWidgets()
        for _,w in ipairs(GRP.stWidgets) do w:Hide() end
        GRP.stWidgets = {}
        GRP.stEPBoxes    = {}
        GRP.stEPHdrBoxes = {}
        GRP.stGPBoxes    = {}
        GRP.stGPHdrBoxes = {}
    end

    -- helper: create a positioned frame child that auto-registers for cleanup
    local function StFrame(w,h,x,y)
        local f = CreateFrame("Frame",nil,stChild)
        f:SetSize(w,h) ; f:SetPoint("TOPLEFT",stChild,"TOPLEFT",x,y)
        table.insert(GRP.stWidgets,f) ; return f
    end
    local function StFS(txt,x,y,font,r,g,b)
        local fs = stChild:CreateFontString(nil,"OVERLAY",font or "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT",stChild,"TOPLEFT",x,y)
        fs:SetText(txt) ; if r then fs:SetTextColor(r,g,b) end
        table.insert(GRP.stWidgets,fs) ; return fs
    end
    local function StEditBox(x,y,w,txt)
        local box = CreateFrame("EditBox",nil,stChild,"InputBoxTemplate")
        box:SetPoint("TOPLEFT",stChild,"TOPLEFT",x,y)
        box:SetSize(w,22) ; box:SetAutoFocus(false) ; box:SetMaxLetters(64)
        box:SetText(txt or "") ; box:SetCursorPosition(0)
        table.insert(GRP.stWidgets,box) ; return box
    end
    local function StBtn(lbl,w,h,x,y,r,g,b)
        local btn = StyledBtn(stChild,lbl,w,h,r,g,b)
        btn:SetPoint("TOPLEFT",stChild,"TOPLEFT",x,y)
        table.insert(GRP.stWidgets,btn) ; return btn
    end
    local function StSepAt(y)
        local s = stChild:CreateTexture(nil,"BACKGROUND")
        s:SetPoint("TOPLEFT", stChild,"TOPLEFT",0,y)
        s:SetPoint("TOPRIGHT",stChild,"TOPRIGHT",0,y)
        s:SetHeight(1) ; s:SetColorTexture(.4,.4,.5,.5)
        table.insert(GRP.stWidgets,s)
    end

    GRP.settingsPanel = stPanel

    RefreshSettings = function()
        ClearStWidgets()

        if not IsGuildMaster() then
            local restrictMsg = stChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            restrictMsg:SetPoint("TOPLEFT",stChild,"TOPLEFT",12,-10)
            restrictMsg:SetText("|cffff6b6bSettings are only available to the Guild Master.|r")
            restrictMsg:SetWidth(400)
            restrictMsg:SetJustifyH("LEFT")
            restrictMsg:SetWordWrap(true)
            table.insert(GRP.stWidgets, restrictMsg)
            stChild:SetHeight(60)
            return
        end

        -- ─── EP section ──────────────────────────────────────────
        local epSecLbl = stChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        epSecLbl:SetPoint("TOPLEFT",stChild,"TOPLEFT",12,-10)
        epSecLbl:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        epSecLbl:SetText("Effort Point Buttons") ; epSecLbl:SetTextColor(1,.85,0)
        table.insert(GRP.stWidgets, epSecLbl)

        -- column sub-headers
        StFS("Button text",     16, -28, "GameFontNormalSmall", .6,.6,.6)
        StFS("Column header",  216, -28, "GameFontNormalSmall", .6,.6,.6)
        StFS("Pts",            418, -28, "GameFontNormalSmall", .6,.6,.6)

        local epY = -42
        for _,key in ipairs(EP_KEY_ORDER) do
            local btnBox = StEditBox(12, epY, 195, BUTTON_LABELS[key] or "")
            GRP.stEPBoxes[key] = btnBox
            btnBox:SetScript("OnTextChanged", function(self)
                local txt = self:GetText() ; if txt=="" then return end
                BUTTON_LABELS[key] = txt
                InitDB() ; DarkIntentionsPointsDB.settings["ep_"..key] = txt
                for _,row in ipairs(GRP.rosterRows) do
                    if row.epBtns and row.epBtns[key] then row.epBtns[key]:SetText(txt) end
                end
            end)

            local hdrBox = StEditBox(213, epY, 195, EP_HDR_LABELS[key] or "")
            GRP.stEPHdrBoxes[key] = hdrBox
            hdrBox:SetScript("OnTextChanged", function(self)
                local txt = self:GetText() ; if txt=="" then return end
                EP_HDR_LABELS[key] = txt
                InitDB() ; DarkIntentionsPointsDB.settings["eph_"..key] = txt
                if GRP.epHdrs and GRP.epHdrs[key] then GRP.epHdrs[key]:SetText(txt) end
            end)

            local valBox = StEditBox(414, epY, 52, tostring(POINT_VALUES[key] or 1))
            valBox:SetScript("OnTextChanged", function(self)
                local v = tonumber(self:GetText())
                if not v then return end
                POINT_VALUES[key] = v
                InitDB()
                local s = DarkIntentionsPointsDB.settings
                for _,def in ipairs(s.ep_custom) do
                    if def.key==key then def.value=v ; break end
                end
            end)

            local delBtn = StBtn("X",24,22,472,epY,.8,.2,.2)
            delBtn:SetScript("OnClick",function()
                local btnLabel = BUTTON_LABELS[key] or key
                StaticPopupDialogs["DIP_DEL_EP_BTN"] = {
                    text    = "Delete EP button |cffffd700"..btnLabel.."|r?",
                    button1 = "Delete", button2 = "Cancel",
                    OnAccept = function()
                        for j,k in ipairs(EP_KEY_ORDER) do
                            if k==key then table.remove(EP_KEY_ORDER,j) ; break end
                        end
                        POINT_VALUES[key]=nil ; BUTTON_LABELS[key]=nil ; EP_HDR_LABELS[key]=nil
                        local s = DarkIntentionsPointsDB.settings
                        for j,def in ipairs(s.ep_custom) do
                            if def.key==key then table.remove(s.ep_custom,j) ; break end
                        end
                        s["ep_"..key]=nil ; s["eph_"..key]=nil
                        ShowUnsavedWarning()
                        for _,row in ipairs(GRP.rosterRows) do row:Hide() end
                        GRP.rosterRows = {}
                        if GRP.RebuildEPHeaders then GRP.RebuildEPHeaders() end
                        RefreshRoster() ; RefreshSettings()
                    end,
                    timeout=0, whileDead=true, hideOnEscape=true,
                }
                StaticPopup_Show("DIP_DEL_EP_BTN")
            end)

            epY = epY - 30
        end

        if #EP_KEY_ORDER == 0 then
            StFS("|cff888888No EP buttons yet. Add one below.|r", 12, epY, "GameFontNormalSmall")
            epY = epY - 20
        end

        local addEPBtn = StBtn("+ Add EP Button",140,24,12,epY-4,.2,.5,.3)
        addEPBtn:SetScript("OnClick",function()
            ShowAddButtonPopup(true, function(btnTxt,hdrTxt,val)
                local key = "ep_custom_"..math.floor(GetTime()*1000)
                POINT_VALUES[key]  = val
                BUTTON_LABELS[key] = btnTxt
                EP_HDR_LABELS[key] = hdrTxt
                table.insert(EP_KEY_ORDER, key)
                InitDB()
                table.insert(DarkIntentionsPointsDB.settings.ep_custom,
                    { key=key, value=val, btnLabel=btnTxt, hdrLabel=hdrTxt })
                ShowUnsavedWarning()
                if GRP.RebuildEPHeaders then GRP.RebuildEPHeaders() end
                for _,row in ipairs(GRP.rosterRows) do row:Hide() end
                GRP.rosterRows = {}
                RefreshRoster() ; RefreshSettings()
            end)
        end)

        local divY = epY - 34
        StSepAt(divY)

        -- ─── GP section ──────────────────────────────────────────
        local gpSecY = divY - 14
        local gpSecLbl = stChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        gpSecLbl:SetPoint("TOPLEFT",stChild,"TOPLEFT",12,gpSecY)
        gpSecLbl:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        gpSecLbl:SetText("Gear Point Buttons") ; gpSecLbl:SetTextColor(1,.85,0)
        table.insert(GRP.stWidgets, gpSecLbl)

        StFS("Button text",     16, gpSecY-18, "GameFontNormalSmall", .6,.6,.6)
        StFS("Column header",  216, gpSecY-18, "GameFontNormalSmall", .6,.6,.6)
        StFS("Pts",            418, gpSecY-18, "GameFontNormalSmall", .6,.6,.6)

        local gpY = gpSecY - 32
        for _,key in ipairs(GP_KEY_ORDER) do
            local btnBox = StEditBox(12, gpY, 195, GP_LABELS[key] or "")
            GRP.stGPBoxes[key] = btnBox
            btnBox:SetScript("OnTextChanged", function(self)
                local txt = self:GetText() ; if txt=="" then return end
                GP_LABELS[key] = txt
                InitDB() ; DarkIntentionsPointsDB.settings["gp_"..key] = txt
                for _,row in ipairs(GRP.gpRows) do
                    if row.gpBtns and row.gpBtns[key] then row.gpBtns[key]:SetText(txt) end
                end
            end)

            local hdrBox = StEditBox(213, gpY, 195, GP_HDR_LABELS[key] or "")
            GRP.stGPHdrBoxes[key] = hdrBox
            hdrBox:SetScript("OnTextChanged", function(self)
                local txt = self:GetText() ; if txt=="" then return end
                GP_HDR_LABELS[key] = txt
                InitDB() ; DarkIntentionsPointsDB.settings["gph_"..key] = txt
                if GRP.gpHdrs and GRP.gpHdrs[key] then GRP.gpHdrs[key]:SetText(txt) end
            end)

            local valBox = StEditBox(414, gpY, 52, tostring(GP_VALUES[key] or 1))
            valBox:SetScript("OnTextChanged", function(self)
                local v = tonumber(self:GetText())
                if not v then return end
                GP_VALUES[key] = v
                InitDB()
                local s = DarkIntentionsPointsDB.settings
                for _,def in ipairs(s.gp_custom) do
                    if def.key==key then def.value=v ; break end
                end
            end)

            local delBtn = StBtn("X",24,22,472,gpY,.8,.2,.2)
            delBtn:SetScript("OnClick",function()
                local btnLabel = GP_LABELS[key] or key
                StaticPopupDialogs["DIP_DEL_GP_BTN"] = {
                    text    = "Delete GP button |cffffd700"..btnLabel.."|r?",
                    button1 = "Delete", button2 = "Cancel",
                    OnAccept = function()
                        for j,k in ipairs(GP_KEY_ORDER) do
                            if k==key then table.remove(GP_KEY_ORDER,j) ; break end
                        end
                        GP_VALUES[key]=nil ; GP_LABELS[key]=nil ; GP_HDR_LABELS[key]=nil
                        local s = DarkIntentionsPointsDB.settings
                        for j,def in ipairs(s.gp_custom) do
                            if def.key==key then table.remove(s.gp_custom,j) ; break end
                        end
                        s["gp_"..key]=nil ; s["gph_"..key]=nil
                        ShowUnsavedWarning()
                        for _,row in ipairs(GRP.gpRows) do row:Hide() end
                        GRP.gpRows = {}
                        if GRP.RebuildGPHeaders then GRP.RebuildGPHeaders() end
                        RefreshGP() ; RefreshSettings()
                    end,
                    timeout=0, whileDead=true, hideOnEscape=true,
                }
                StaticPopup_Show("DIP_DEL_GP_BTN")
            end)

            gpY = gpY - 30
        end

        if #GP_KEY_ORDER == 0 then
            StFS("|cff888888No GP buttons yet. Add one below.|r", 12, gpY, "GameFontNormalSmall")
            gpY = gpY - 20
        end

        local addGPBtn = StBtn("+ Add GP Button",140,24,12,gpY-4,.4,.3,.1)
        addGPBtn:SetScript("OnClick",function()
            ShowAddButtonPopup(false, function(btnTxt,hdrTxt,val)
                local key = "gp_custom_"..math.floor(GetTime()*1000)
                GP_VALUES[key]     = val
                GP_LABELS[key]     = btnTxt
                GP_HDR_LABELS[key] = hdrTxt
                table.insert(GP_KEY_ORDER, key)
                InitDB()
                table.insert(DarkIntentionsPointsDB.settings.gp_custom,
                    { key=key, value=val, btnLabel=btnTxt, hdrLabel=hdrTxt })
                ShowUnsavedWarning()
                if GRP.RebuildGPHeaders then GRP.RebuildGPHeaders() end
                for _,row in ipairs(GRP.gpRows) do row:Hide() end
                GRP.gpRows = {}
                RefreshGP() ; RefreshSettings()
            end)
        end)

        stChild:SetHeight(math.abs(gpY) + 60)
    end

    -- ============================================================
    -- GUILD PANEL
    -- ============================================================
    local guildPanel = CreateFrame("Frame","DIPGuildPanel",content)
    guildPanel:SetAllPoints(content)
    guildPanel:Hide()

    -- filter bar background
    local gFilterBg = guildPanel:CreateTexture(nil,"BACKGROUND")
    gFilterBg:SetPoint("TOPLEFT", guildPanel,"TOPLEFT",  0,  0)
    gFilterBg:SetPoint("TOPRIGHT",guildPanel,"TOPRIGHT", 0,  0)
    gFilterBg:SetHeight(66) ; gFilterBg:SetColorTexture(.04,.04,.1,.9)

    -- refresh button
    local gRefBtn = StyledBtn(guildPanel,"Refresh",90,22,.3,.5,.7)
    gRefBtn:SetPoint("TOPRIGHT",guildPanel,"TOPRIGHT",-4,-6)
    gRefBtn:SetScript("OnClick",function()
        C_GuildInfo.GuildRoster()
        C_Timer.After(0.5, RefreshGuildBrowser)
    end)

    -- "showing non-roster members" note
    local gNote = guildPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    gNote:SetPoint("TOPLEFT",guildPanel,"TOPLEFT",8,-8)
    gNote:SetText("|cffaaaaaаAll guild members shown. Already on roster marked.|r")

    -- ── Rank filter ──────────────────────────────────────────
    local gRankLbl = guildPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    gRankLbl:SetPoint("TOPLEFT",guildPanel,"TOPLEFT",18,-22)
    gRankLbl:SetText("Rank:") ; gRankLbl:SetTextColor(.85,.85,.85)

    local rankDD = CreateFrame("Frame","DIPRankDropdown",guildPanel,"UIDropDownMenuTemplate")
    rankDD:SetPoint("TOPLEFT",guildPanel,"TOPLEFT",2,-34)
    UIDropDownMenu_SetWidth(rankDD,160) ; UIDropDownMenu_SetText(rankDD,"All Ranks")
    GRP.rankDropdown = rankDD ; GRP.filterRank = nil

    -- ── Class filter dropdown ─────────────────────────────────
    local CLASS_LIST = {"All","WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
                        "DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK","DRUID",
                        "DEMONHUNTER","EVOKER"}
    local CLASS_DISPLAY = {
        All="All Classes",  WARRIOR="Warrior",      PALADIN="Paladin",
        HUNTER="Hunter",    ROGUE="Rogue",           PRIEST="Priest",
        DEATHKNIGHT="Death Knight", SHAMAN="Shaman", MAGE="Mage",
        WARLOCK="Warlock",  MONK="Monk",             DRUID="Druid",
        DEMONHUNTER="Demon Hunter", EVOKER="Evoker",
    }
    local CLASS_COLORS = {
        WARRIOR={0.78,0.61,0.43}, PALADIN={0.96,0.55,0.73}, HUNTER={0.67,0.83,0.45},
        ROGUE={1,0.96,0.41},      PRIEST={1,1,1},            DEATHKNIGHT={0.77,0.12,0.23},
        SHAMAN={0,0.44,0.87},     MAGE={0.41,0.80,0.94},     WARLOCK={0.58,0.51,0.79},
        MONK={0,1,0.59},          DRUID={1,0.49,0.04},       DEMONHUNTER={0.64,0.19,0.79},
        EVOKER={0.20,0.58,0.50},
    }
    GRP.filterClass = nil

    local gClassLbl = guildPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    gClassLbl:SetPoint("TOPLEFT",guildPanel,"TOPLEFT",198,-22)
    gClassLbl:SetText("Class:") ; gClassLbl:SetTextColor(.85,.85,.85)

    local classDD = CreateFrame("Frame","DIPClassDropdown",guildPanel,"UIDropDownMenuTemplate")
    classDD:SetPoint("TOPLEFT",guildPanel,"TOPLEFT",182,-34)
    UIDropDownMenu_SetWidth(classDD,160) ; UIDropDownMenu_SetText(classDD,"All Classes")
    GRP.classDropdown = classDD

    UIDropDownMenu_Initialize(classDD, function(self, level)
        for _,cls in ipairs(CLASS_LIST) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = CLASS_DISPLAY[cls] or cls
            info.value = cls
            info.checked = (cls=="All" and GRP.filterClass==nil) or (GRP.filterClass==cls)
            local rc = CLASS_COLORS[cls]
            if rc then info.colorCode = string.format("|cff%02x%02x%02x", rc[1]*255, rc[2]*255, rc[3]*255) end
            info.func = function()
                GRP.filterClass = (cls=="All") and nil or cls
                UIDropDownMenu_SetText(classDD, CLASS_DISPLAY[cls] or cls)
                CloseDropDownMenus()
                RefreshGuildBrowser()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- separator
    local gSep = guildPanel:CreateTexture(nil,"BACKGROUND")
    gSep:SetPoint("TOPLEFT", guildPanel,"TOPLEFT",  0,-68)
    gSep:SetPoint("TOPRIGHT",guildPanel,"TOPRIGHT", 0,-68)
    gSep:SetHeight(1) ; gSep:SetColorTexture(.4,.4,.5,.6)

    -- column headers
    local function GuildHdr(txt,x,w,r,g,b)
        local h = guildPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        h:SetPoint("TOPLEFT",guildPanel,"TOPLEFT",x,-71)
        h:SetWidth(w) ; h:SetJustifyH("LEFT")
        h:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        h:SetTextColor(r or 1,g or 1,b or 1) ; h:SetText(txt) ; h:SetWordWrap(false)
    end
    GuildHdr("Character",  8,  160, 1,1,1)
    GuildHdr("Rank",       174, 130, .8,.8,.6)
    GuildHdr("Class",      310, 120, .6,.8,1)

    local gHdrSep = guildPanel:CreateTexture(nil,"BACKGROUND")
    gHdrSep:SetPoint("TOPLEFT", guildPanel,"TOPLEFT",  0,-86)
    gHdrSep:SetPoint("TOPRIGHT",guildPanel,"TOPRIGHT", 0,-86)
    gHdrSep:SetHeight(1) ; gHdrSep:SetColorTexture(.4,.4,.5,.5)

    local gScroll = CreateFrame("ScrollFrame","DIPGuildScroll",guildPanel,"UIPanelScrollFrameTemplate")
    gScroll:SetPoint("TOPLEFT",    guildPanel,"TOPLEFT",   2,-90)
    gScroll:SetPoint("BOTTOMRIGHT",guildPanel,"BOTTOMRIGHT",-20,4)
    local gChild = CreateFrame("Frame","DIPGuildChild",gScroll)
    gChild:SetWidth(700) ; gChild:SetHeight(400)
    gScroll:SetScrollChild(gChild)
    GRP.guildPanel       = guildPanel
    GRP.guildScrollChild = gChild

    RefreshGuildBrowser = function()
        if not GRP.guildScrollChild then return end
        local members = {}
        for i=1,GetNumGuildMembers() do
            local name,rank,ri,_,_,_,_,_,_,_,classEn = GetGuildRosterInfo(i)
            if name then
                local sn = name:match("([^%-]+)")
                if sn then
                    local passRank  = (GRP.filterRank  == nil or ri == GRP.filterRank)
                    local passCls   = (GRP.filterClass == nil or classEn == GRP.filterClass)
                    if passRank and passCls then
                        table.insert(members,{name=sn, rank=rank, rankIdx=ri, class=classEn})
                    end
                end
            end
        end
        table.sort(members, function(a,b) return a.name < b.name end)

        -- rebuild rank dropdown
        if GRP.rankDropdown then
            UIDropDownMenu_Initialize(GRP.rankDropdown, function(self,level)
                local info = UIDropDownMenu_CreateInfo()
                info.text="All Ranks" ; info.value=nil ; info.checked=(GRP.filterRank==nil)
                info.func=function()
                    GRP.filterRank=nil ; UIDropDownMenu_SetText(GRP.rankDropdown,"All Ranks") ; RefreshGuildBrowser()
                end
                UIDropDownMenu_AddButton(info,level)
                local seen,ranks={},{}
                for i2=1,GetNumGuildMembers() do
                    local _,rname,ridx = GetGuildRosterInfo(i2)
                    if rname and not seen[ridx] then seen[ridx]=true ; table.insert(ranks,{name=rname,index=ridx}) end
                end
                table.sort(ranks,function(a,b) return a.index<b.index end)
                for _,r in ipairs(ranks) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text=r.name ; info.value=r.index ; info.checked=(GRP.filterRank==r.index)
                    info.func=function()
                        GRP.filterRank=r.index ; UIDropDownMenu_SetText(GRP.rankDropdown,r.name) ; RefreshGuildBrowser()
                    end
                    UIDropDownMenu_AddButton(info,level)
                end
            end)
        end

        local ROW_H2 = 26
        local n = #members
        GRP.guildScrollChild:SetHeight(math.max(n*ROW_H2+10,100))

        while #GRP.guildRows < n do
            local i2 = #GRP.guildRows+1
            local y   = -((i2-1)*ROW_H2)-4
            local row = {}

            row.bg = GRP.guildScrollChild:CreateTexture(nil,"BACKGROUND")
            row.bg:SetHeight(ROW_H2-2)
            row.bg:SetPoint("TOPLEFT", GRP.guildScrollChild,"TOPLEFT",  2, y+1)
            row.bg:SetPoint("TOPRIGHT",GRP.guildScrollChild,"TOPRIGHT", -2, y+1)
            row.bg:SetColorTexture(.08,.08,.14,.6)

            row.nameTxt = GRP.guildScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
            row.nameTxt:SetWidth(160) ; row.nameTxt:SetPoint("TOPLEFT",GRP.guildScrollChild,"TOPLEFT",8,y-5)
            row.nameTxt:SetJustifyH("LEFT")

            row.rankTxt = GRP.guildScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.rankTxt:SetWidth(130) ; row.rankTxt:SetPoint("TOPLEFT",GRP.guildScrollChild,"TOPLEFT",174,y-5)
            row.rankTxt:SetJustifyH("LEFT") ; row.rankTxt:SetTextColor(.8,.8,.6)

            row.classTxt = GRP.guildScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.classTxt:SetWidth(120) ; row.classTxt:SetPoint("TOPLEFT",GRP.guildScrollChild,"TOPLEFT",310,y-5)
            row.classTxt:SetJustifyH("LEFT") ; row.classTxt:SetTextColor(.6,.8,1)

            row.addBtn = StyledBtn(GRP.guildScrollChild,"Add to Roster",100,20,.2,.6,.25)
            row.addBtn:SetPoint("TOPRIGHT",GRP.guildScrollChild,"TOPRIGHT",-4,y-3)

            row.inRosterLbl = GRP.guildScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.inRosterLbl:SetWidth(100)
            row.inRosterLbl:SetPoint("TOPRIGHT",GRP.guildScrollChild,"TOPRIGHT",-4,y-5)
            row.inRosterLbl:SetJustifyH("RIGHT") ; row.inRosterLbl:SetTextColor(.4,.8,.4)
            row.inRosterLbl:SetText("✓ On Roster")

            row.Hide = function(self)
                self.bg:Hide() ; self.nameTxt:Hide() ; self.rankTxt:Hide()
                self.classTxt:Hide() ; self.addBtn:Hide() ; self.inRosterLbl:Hide()
            end
            row.Show = function(self)
                self.bg:Show() ; self.nameTxt:Show() ; self.rankTxt:Show() ; self.classTxt:Show()
            end
            table.insert(GRP.guildRows, row)
        end

        for i,row in ipairs(GRP.guildRows) do
            if i<=n then
                local m  = members[i]
                local cn = m.name
                local cr,cg,cb2 = 1,1,1
                if CLASS_COLORS[m.class] then cr,cg,cb2 = unpack(CLASS_COLORS[m.class]) end
                row.nameTxt:SetText(cn) ; row.nameTxt:SetTextColor(cr,cg,cb2)
                row.rankTxt:SetText(m.rank or "")
                row.classTxt:SetText(CLASS_DISPLAY[m.class] or (m.class or ""))
                local onRoster = IsInRoster(cn)
                if onRoster then
                    row.addBtn:Hide() ; row.inRosterLbl:Show()
                else
                    row.inRosterLbl:Hide() ; row.addBtn:Show()
                    row.addBtn:SetScript("OnClick",function()
                        AddToRoster(cn)
                        RefreshRoster() ; RefreshSummary() ; RefreshGuildBrowser()
                        print("|cff00ff00[DIP]|r Added "..cn.." to roster.")
                    end)
                end
                row:Show()
            else
                row:Hide()
            end
        end
    end

    GRP.guildFrame = guildPanel  -- keep ref name compatible

    -- ============================================================
    -- ADMIN PANEL
    -- ============================================================
    local adminPanel = CreateFrame("Frame","DIPAdminPanel",content)
    adminPanel:SetAllPoints(content)
    adminPanel:Hide()

    -- Admin scrollable content
    local adminScroll = CreateFrame("ScrollFrame","DIPAdminScroll",adminPanel,"UIPanelScrollFrameTemplate")
    adminScroll:SetPoint("TOPLEFT",    adminPanel,"TOPLEFT",   2,-4)
    adminScroll:SetPoint("BOTTOMRIGHT",adminPanel,"BOTTOMRIGHT",-20,4)
    local adminChild = CreateFrame("Frame","DIPAdminChild",adminScroll)
    adminChild:SetWidth(600) ; adminChild:SetHeight(400)
    adminScroll:SetScrollChild(adminChild)
    GRP.adminPanel = adminPanel
    GRP.adminScrollChild = adminChild
    GRP.adminPermsUI = {}

    RefreshAdmin = function()
        if not GRP.adminScrollChild then return end
        for _,widget in ipairs(GRP.adminPermsUI) do widget:Hide() end
        GRP.adminPermsUI = {}

        local adminY = -10

        if not IsGuildMaster() then
            local noAccessMsg = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            noAccessMsg:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
            noAccessMsg:SetText("|cffff6b6bAdmin panel is only available to the Guild Master.|r")
            noAccessMsg:SetWidth(400)
            noAccessMsg:SetJustifyH("LEFT")
            noAccessMsg:SetWordWrap(true)
            table.insert(GRP.adminPermsUI, noAccessMsg)
            return
        end

        -- Header
        local titleLbl = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        titleLbl:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
        titleLbl:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        titleLbl:SetText("Permissions Management") ; titleLbl:SetTextColor(1,.85,0)
        table.insert(GRP.adminPermsUI, titleLbl)
        adminY = adminY - 30

        -- Guild Master Info
        local playerName = UnitName("player")
        local gmLabel = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        gmLabel:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
        gmLabel:SetText("Guild Master: |cffffffff"..playerName.."|r")
        table.insert(GRP.adminPermsUI, gmLabel)
        adminY = adminY - 20

        -- Rank-based access section
        local rankSecLbl = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        rankSecLbl:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
        rankSecLbl:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
        rankSecLbl:SetText("Grant All-Tab Access to Guild Ranks") ; rankSecLbl:SetTextColor(1,.85,0)
        table.insert(GRP.adminPermsUI, rankSecLbl)
        adminY = adminY - 24

        -- Get all guild ranks
        local guildName, guildRank, guildRankIndex = C_GuildInfo.GetMyGuildInfo()
        local guildRanks = {}
        for i=0, GetNumGuildRanks()-1 do
            local rankName = GetGuildRankInfo(i)
            if rankName then
                table.insert(guildRanks, {index=i, name=rankName})
            end
        end

        -- Create checkboxes for ranks
        InitDB()
        local perms = DarkIntentionsPointsDB.settings.permissions
        for _,rankInfo in ipairs(guildRanks) do
            local rankIdx = rankInfo.index
            local rankName = rankInfo.name
            local isChecked = perms.rankAccess[rankIdx] or false

            -- Checkbox
            local chkBtn = CreateFrame("CheckButton",nil,GRP.adminScrollChild,"ChatConfigCheckButtonTemplate")
            chkBtn:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
            chkBtn:SetChecked(isChecked)
            chkBtn:SetScript("OnClick",function(self)
                perms.rankAccess[rankIdx] = self:GetChecked()
                ShowUnsavedWarning()
            end)

            -- Label
            local lbl = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",35,adminY)
            lbl:SetText(rankName)
            table.insert(GRP.adminPermsUI, chkBtn)
            table.insert(GRP.adminPermsUI, lbl)
            adminY = adminY - 20
        end

        adminY = adminY - 10

        -- Character-based access section
        local charSecLbl = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormal")
        charSecLbl:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
        charSecLbl:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
        charSecLbl:SetText("Grant All-Tab Access to Characters") ; charSecLbl:SetTextColor(1,.85,0)
        table.insert(GRP.adminPermsUI, charSecLbl)
        adminY = adminY - 24

        -- Roster member list
        if DarkIntentionsPointsDB and DarkIntentionsPointsDB.roster then
            for _,charName in ipairs(DarkIntentionsPointsDB.roster) do
                local isChecked = perms.charAccess[charName] or false

                -- Checkbox
                local chkBtn = CreateFrame("CheckButton",nil,GRP.adminScrollChild,"ChatConfigCheckButtonTemplate")
                chkBtn:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",12,adminY)
                chkBtn:SetChecked(isChecked)
                chkBtn:SetScript("OnClick",function(self)
                    perms.charAccess[charName] = self:GetChecked()
                    ShowUnsavedWarning()
                end)

                -- Label
                local lbl = GRP.adminScrollChild:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                lbl:SetPoint("TOPLEFT",GRP.adminScrollChild,"TOPLEFT",35,adminY)
                lbl:SetText(charName)
                table.insert(GRP.adminPermsUI, chkBtn)
                table.insert(GRP.adminPermsUI, lbl)
                adminY = adminY - 20
            end
        end

        GRP.adminScrollChild:SetHeight(math.abs(adminY) + 40)
    end

    -- open on Raid Roster tab
    ShowTab("summary")
end

-- ============================================================
-- Slash commands
-- ============================================================
SLASH_DIP1 = "/dip"
SLASH_DIP2 = "/darkintentionspoints"
SlashCmdList["DIP"] = function(msg)
    local cmd = msg:lower():match("^%s*(%S*)")
    if cmd=="show" or cmd=="" then
        BuildMainFrame() ; UpdateTabVisibility() ; GRP.mainFrame:Show() ; ShowTab(GRP.activeTab)
    elseif cmd=="hide" then
        if GRP.mainFrame then GRP.mainFrame:Hide() end
    elseif cmd=="ep" then
        print("|cffffd700--- EP Rankings ---")
        for i,n in ipairs(GetRosterByEP()) do
            print(string.format("%d. %s  EP:%d  GP:%d  PR:%.2f",i,n,GetEP(n),GetGP(n),GetPR(n)))
        end
    elseif cmd=="pr" then
        print("|cffffd700--- PR Rankings ---")
        for i,n in ipairs(GetRosterByPR()) do
            print(string.format("%d. %s  EP:%d  GP:%d  PR:%.2f",i,n,GetEP(n),GetGP(n),GetPR(n)))
        end
    elseif cmd=="reset" then
        local t = msg:match("%S+%s+(%S+)")
        if t then
            ResetEP(t) ; print("|cffffff00[DIP]|r EP reset for "..t)
            RefreshRoster() ; RefreshSummary()
        else print("|cffffff00[DIP]|r Usage: /dip reset CharName") end
    elseif cmd=="history" then
        local t = msg:match("%S+%s+(%S+)")
        if t then BuildMainFrame() ; ShowHistoryFrame(t)
        else print("|cffffff00[DIP]|r Usage: /dip history CharName") end
    else
        print("|cffffd700Dark Intentions Points — Commands:|r")
        print("  |cff00ff00/dip|r — open window")
        print("  |cff00ff00/dip ep|r — EP rankings in chat")
        print("  |cff00ff00/dip pr|r — PR rankings in chat")
        print("  |cff00ff00/dip reset CharName|r")
        print("  |cff00ff00/dip history CharName|r")
    end
end

-- ============================================================
-- Events
-- ============================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:SetScript("OnEvent",function(self,event,...)
    if event=="ADDON_LOADED" and ...==ADDON_NAME then
        InitDB()
        GRP.playerName = UnitName("player")
        GRP.playerRankIndex = GetPlayerRankIndex()
        print("|cffffd700Dark Intentions Points|r loaded!  |cff00ff00/dip|r to open.")
    elseif event=="GUILD_ROSTER_UPDATE" then
        if GRP.guildPanel and GRP.guildPanel:IsShown() then RefreshGuildBrowser() end
    end
end)
