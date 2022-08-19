util.AddNetworkString("DL_SlayMessage")
util.AddNetworkString("DL_AutoSlay")
util.AddNetworkString("DL_AutoslaysLeft")
util.AddNetworkString("DL_PlayerLeft")
util.AddNetworkString("DL_SendJails")
local mode = Damagelog.ULX_AutoslayMode
if mode ~= 1 and mode ~= 2 then return end
local aslay = mode == 1

if not sql.TableExists("damagelog_autoslay") then
    Damagelog.SQLiteDatabase.Query([[CREATE TABLE damagelog_autoslay (
		ply varchar(32) NOT NULL,
		admins tinytext NOT NULL,
		slays SMALLINT UNSIGNED NOT NULL,
		reason varchar(255) NOT NULL,
		time BIGINT UNSIGNED NOT NULL);
	]])
end

if not sql.TableExists("damagelog_names") then
    Damagelog.SQLiteDatabase.Query([[CREATE TABLE damagelog_names (
		steamid varchar(32),
		name varchar(255));
	]])
end

hook.Add("PlayerAuthed", "DamagelogNames", function(ply, steamid)
    for _, v in ipairs(player.GetHumans()) do
        if v ~= ply then
            net.Start("DL_AutoslaysLeft")
            net.WriteEntity(v)
            net.WriteUInt(v.AutoslaysLeft or 0, 32)
            net.Broadcast()
        end
    end

    local safeSteamID = sql.SQLStr(steamid)
    local name = ply:Nick()
    local safeName = sql.SQLStr(name)
    local query = Damagelog.SQLiteDatabase.QueryValue(string.format("SELECT name FROM damagelog_names WHERE steamid = %s", safeSteamID))

    if not query then
        Damagelog.SQLiteDatabase.Query(string.format("INSERT INTO damagelog_names (`steamid`, `name`) VALUES(%s, %s)", safeSteamID, safeName))
    elseif query ~= name then
        Damagelog.SQLiteDatabase.Query(string.format("UPDATE damagelog_names SET name = %s WHERE steamid = %s", safeName, safeSteamID))
    end

    local remainingAutoslays = Damagelog.SQLiteDatabase.QueryValue(string.format("SELECT slays FROM damagelog_autoslay WHERE ply = %s", safeSteamID))

    if not tonumber(remainingAutoslays) then
        remainingAutoslays = 0
    end

    ply.AutoslaysLeft = remainingAutoslays
    net.Start("DL_AutoslaysLeft")
    net.WriteEntity(ply)
    net.WriteUInt(remainingAutoslays, 32)
    net.Broadcast()
end)

function Damagelog:GetName(steamid)
    for _, v in ipairs(player.GetHumans()) do
        if v:SteamID() == steamid then return v:Nick() end
    end

    local query = Damagelog.SQLiteDatabase.QueryValue(string.format("SELECT name FROM damagelog_names WHERE steamid = %s", sql.SQLStr(steamid)))

    return query or "<Error>"
end

function Damagelog.SlayMessage(ply, message)
    net.Start("DL_SlayMessage")
    net.WriteString(message)
    net.Send(ply)
end

function Damagelog:CreateSlayList(tbl)
    if #tbl == 1 then
        return self:GetName(tbl[1])
    else
        local result = ""

        for i = 1, #tbl do
            if i == #tbl then
                result = result .. " and " .. self:GetName(tbl[i])
            elseif i == 1 then
                result = self:GetName(tbl[i])
            else
                result = result .. ", " .. self:GetName(tbl[i])
            end
        end

        return result
    end
end

-- ty evolve
function Damagelog:FormatTime(t)
    if t < 0 then
        -- 24 * 3600
        -- 24 * 3600 * 7
        -- 24 * 3600 * 30
        return "Forever"
    elseif t < 60 then
        if t == 1 then
            return "one second"
        else
            return t .. " seconds"
        end
    elseif t < 3600 then
        if math.Round(t / 60) == 1 then
            return "one minute"
        else
            return math.Round(t / 60) .. " minutes"
        end
    elseif t < 86400 then
        if math.Round(t / 3600) == 1 then
            return "one hour"
        else
            return math.Round(t / 3600) .. " hours"
        end
    elseif t < 604800 then
        if math.Round(t / 86400) == 1 then
            return "one day"
        else
            return math.Round(t / 86400) .. " days"
        end
    elseif t < 2592000 then
        if math.Round(t / 604800) == 1 then
            return "one week"
        else
            return math.Round(t / 604800) .. " weeks"
        end
    else
        if math.Round(t / 2592000) == 1 then
            return "one month"
        else
            return math.Round(t / 2592000) .. " months"
        end
    end
end

local function NetworkSlays(steamid, number)
    for _, v in ipairs(player.GetHumans()) do
        if v:SteamID() == steamid then
            v.AutoslaysLeft = number
            net.Start("DL_AutoslaysLeft")
            net.WriteEntity(v)
            net.WriteUInt(number, 32)
            net.Broadcast()

            return
        end
    end
end

function Damagelog:SetSlays(admin, steamid, slays, reason, target)
    if reason == "" then
        reason = Damagelog.Autoslay_DefaultReason
    end

    if slays == 0 then

        Damagelog.SQLiteDatabase.Query("DELETE FROM damagelog_autoslay WHERE ply = '" .. (IsValid(target) and target:SteamID() or steamid) .. "';")

        if ulx then
            if target then
                ulx.fancyLogAdmin(admin, aslay and "#A removed the autoslays of #T." or "#A removed the autojails of #T.", target)
            else
                ulx.fancyLogAdmin(admin, aslay and "#A removed the autoslays of #s." or "#A removed the jails of #s.", steamid)
            end
        elseif sam then
            if target then
                sam.player.send_message(nil, "{A} removed the slays of {T}.", {
                    A = admin:Nick(),
                    T = target:Nick()
                })
            else
                sam.player.send_message(nil, "{A} removed the slays of {T}.", {
                    A = admin:Nick(),
                    T = steamid
                })
            end
        end

        NetworkSlays(steamid, 0)
    else
        local data = Damagelog.SQLiteDatabase.QuerySingle(string.format("SELECT * FROM damagelog_autoslay WHERE ply = %s", sql.SQLStr(steamid)))

        if data then
            local adminid, admin_nick

            if IsValid(admin) and type(admin) == "Player" then
                adminid = admin:SteamID()
                admin_nick = admin:Nick()
            else
                adminid = "Console"
                admin_nick = "Console"
            end

            local old_slays = tonumber(data.slays)
            local old_steamids = util.JSONToTable(data.admins) or {}
            local new_steamids = table.Copy(old_steamids)

            if not table.HasValue(new_steamids, adminid) then
                table.insert(new_steamids, adminid)
            end

            if old_slays == slays then
                local list = self:CreateSlayList(old_steamids)
                local msg

                if target then
                    if ulx then
                        if aslay then
                            msg = "#T was already autoslain "
                        else
                            msg = "#T was already autojailed "
                        end

                        ulx.fancyLogAdmin(admin, msg .. slays .. " time(s) by #A for #s.", target, list, reason)
                    elseif sam then
                        sam.player.send_message(admin, "{T} was already {V_1} {V} time(s) by {A} for {V_2}.", {
                            T = target:Nick(),
                            V = slays,
                            V_1 = string.format("%s", aslay and "autoslain" or "autojailed"),
                            A = list,
                            V_2 = reason
                        })
                    end
                else
                    if ulx then
                        if aslay then
                            msg = "#s was already autoslain "
                        else
                            msg = "#s was already autojailed "
                        end

                        ulx.fancyLogAdmin(admin, msg .. slays .. " time(s) by #A for #s.", steamid, list, reason)
                    elseif sam then
                        sam.player.send_message(admin, "{T} was already {V_1} {V} time(s) by {A} for {V_2}.", {
                            T = steamid,
                            V = slays,
                            V_1 = string.format("%s", aslay and "autoslain" or "autojailed"),
                            A = list,
                            V_2 = reason
                        })
                    end
                end
            else
                local difference = slays - old_slays

                Damagelog.SQLiteDatabase.Query(string.format(
                    "UPDATE damagelog_autoslay SET admins = %s, slays = %i, reason = %s, time = %s WHERE ply = %s",
                    sql.SQLStr(admin_nick),
                    slays,
                    sql.SQLStr(reason),
                    tostring(os.time()),
                    sql.SQLStr(steamid)
                ))

                local list = self:CreateSlayList(old_steamids)
                local msg

                if target then
                    if ulx then
                        if aslay then
                            msg = " autoslays to #T (#s). He was previously autoslain "
                        else
                            msg = " autojails to #T (#s). He was previously autojailed "
                        end

                        ulx.fancyLogAdmin(admin, "#A " .. (difference > 0 and "added " or "removed ") .. math.abs(difference) .. msg .. old_slays .. " time(s) by #s.", target, reason, list)
                    elseif sam then

                        sam.player.send_message(nil, "{A} {V_1} {V} {V_2} {T} for {A_2}. They were previously {V_3} {V_4} time(s) by {V_5}.", {
                            A = admin_nick,
                            V_1 = difference > 0 and "added " or "removed ",
                            V = math.abs(difference),
                            V_2 = aslay and " autoslays to " or " autojails to ",
                            T = target:Nick(),
                            A_2 = reason,
                            V_3 = aslay and " autoslain " or " autojailed ",
                            V_4 = old_slays,
                            V_5 = list
                        })
                    end
                else
                    if ulx then
                        if aslay then
                            msg = " autoslays to #T (#s). He was previously autoslain "
                        else
                            msg = " autojails to #T (#s). He was previously autojailed "
                        end

                        ulx.fancyLogAdmin(admin, "#A " .. (difference > 0 and "added " or "removed ") .. math.abs(difference) .. msg .. old_slays .. " time(s) by #s.", steamid, reason, list)
                    elseif sam then
                        sam.player.send_message(nil, "{A} {V_1} {V} {V_2} {T} for {A_2}. They were previously {V_3} {V_4} time(s) by {V_5}.", {
                            A = admin_nick,
                            V_1 = difference > 0 and "added " or "removed ",
                            V = math.abs(difference),
                            V_2 = aslay and " autoslays to " or " autojails to ",
                            T = steamid,
                            A_2 = reason,
                            V_3 = aslay and " autoslain " or " autojailed ",
                            V_4 = old_slays,
                            V_5 = list
                        })
                    end
                end

                NetworkSlays(steamid, slays)
            end
        else
            local admins, admin_nick

            if IsValid(admin) and type(admin) == "Player" then
                admins = util.TableToJSON({admin:SteamID()})
                admin_nick = admin:Nick()
            else
                admins = util.TableToJSON({"Console"})
                admin_nick = "Console"
            end

            Damagelog.SQLiteDatabase.Query(string.format("INSERT INTO damagelog_autoslay (`admins`, `ply`, `slays`, `reason`, `time`) VALUES (%s, '%s', %i, %s, %s);", sql.SQLStr(admins), steamid, slays, sql.SQLStr(reason), tostring(os.time())))
            local msg

            if target then
                if ulx then
                    if aslay then
                        msg = " autoslays to #T (#s)"
                    else
                        msg = " autojails to #T (#s)"
                    end

                    ulx.fancyLogAdmin(admin, "#A added " .. slays .. msg, target, reason)
                elseif sam then
                    sam.player.send_message(nil, "{A} added {V} " .. (aslay and "autoslays" or "autojails") .. " to {T} ({V_2}).", {
                        A = admin_nick,
                        V = slays,
                        T = target:Nick(),
                        V_2 = reason
                    })
                end
            else
                if ulx then
                    if aslay then
                        msg = " autoslays to #s (#s)"
                    else
                        msg = " autojails to #s (#s)"
                    end

                    ulx.fancyLogAdmin(admin, "#A added " .. slays .. msg, steamid, reason)
                elseif sam then
                    sam.player.send_message(nil, "{A} added {V} " .. (aslay and "autoslays" or "autojails") .. " to {T} ({V_2}).", {
                        A = admin_nick,
                        V = slays,
                        T = steamid,
                        V_2 = reason
                    })
                end
            end

            NetworkSlays(steamid, slays)
        end
    end
end

local mdl1 = Model("models/props_building_details/Storefront_Template001a_Bars.mdl")

local jail = {
    {
        pos = Vector(0, 0, -5),
        ang = Angle(90, 0, 0),
        mdl = mdl1
    },
    {
        pos = Vector(0, 0, 97),
        ang = Angle(90, 0, 0),
        mdl = mdl1
    },
    {
        pos = Vector(21, 31, 46),
        ang = Angle(0, 90, 0),
        mdl = mdl1
    },
    {
        pos = Vector(21, -31, 46),
        ang = Angle(0, 90, 0),
        mdl = mdl1
    },
    {
        pos = Vector(-21, 31, 46),
        ang = Angle(0, 90, 0),
        mdl = mdl1
    },
    {
        pos = Vector(-21, -31, 46),
        ang = Angle(0, 90, 0),
        mdl = mdl1
    },
    {
        pos = Vector(-52, 0, 46),
        ang = Angle(0, 0, 0),
        mdl = mdl1
    },
    {
        pos = Vector(52, 0, 46),
        ang = Angle(0, 0, 0),
        mdl = mdl1
    }
}

hook.Add("TTTBeginRound", "Damagelog_AutoSlay", function()
    for _, v in ipairs(player.GetHumans()) do
        if v:IsActive() then
            timer.Simple(1, function()
                v:SetNWBool("PlayedSRound", true)
            end)

            local data = Damagelog.SQLiteDatabase.QuerySingle(string.format("SELECT * FROM damagelog_autoslay WHERE ply = %s", sql.SQLStr(v:SteamID())))

            if data then
                if aslay then
                    timer.Simple(0.5, function()
                        hook.Run("DL_AslayHook", v)
                    end)

                    v:Kill()
                else
                    local pos = v:GetPos()
                    local walls = {}

                    for _, info in ipairs(jail) do
                        local ent = ents.Create("prop_physics")
                        ent:SetModel(info.mdl)
                        ent:SetPos(pos + info.pos)
                        ent:SetAngles(info.ang)
                        ent:Spawn()
                        ent:GetPhysicsObject():EnableMotion(false)
                        ent:SetCustomCollisionCheck(true)
                        ent.jailWall = true
                        table.insert(walls, ent)
                    end

                    timer.Simple(1, function()
                        net.Start("DL_SendJails")
                        net.WriteUInt(#walls, 32)

                        for _, v2 in ipairs(walls) do
                            net.WriteEntity(v2)
                        end

                        local filter = RecipientFilter()
                        filter:AddAllPlayers()

                        if IsValid(v) then
                            filter:RemovePlayer(v)
                        end

                        net.Send(filter)
                    end)

                    local function unjail()
                        for _, ent in ipairs(walls) do
                            if IsValid(ent) then
                                ent:Remove()
                            end
                        end

                        if not IsValid(v) then return end
                        v.jail = nil
                    end

                    v.jail = {
                        pos = pos,
                        unjail = unjail
                    }
                end

                local admins = util.JSONToTable(data.admins) or {}
                local slays = data.slays
                local reason = data.reason
                local _time = data.time
                slays = slays - 1

                if slays <= 0 then
                    Damagelog.SQLiteDatabase.Query("DELETE FROM damagelog_autoslay WHERE ply = '" .. v:SteamID() .. "';")
                    NetworkSlays(steamid, 0)
                    v.AutoslaysLeft = 0
                else
                    Damagelog.SQLiteDatabase.Query("UPDATE damagelog_autoslay SET slays = slays - 1 WHERE ply = '" .. v:SteamID() .. "';")
                    NetworkSlays(steamid, slays - 1)

                    if tonumber(v.AutoslaysLeft) then
                        v.AutoslaysLeft = v.AutoslaysLeft - 1
                    end
                end

                local list = Damagelog:CreateSlayList(admins)
                net.Start("DL_AutoSlay")
                net.WriteEntity(v)
                net.WriteString(list)
                net.WriteString(reason)
                net.WriteString(Damagelog:FormatTime(tonumber(os.time()) - tonumber(_time)))
                net.Broadcast()

                if Damagelog.ShowRemainingSlays then
                    local slaycounter = (slays > 0 and slays) or "no"

                    for m, n in pairs(player.GetHumans()) do
                        n:PrintMessage(HUD_PRINTTALK, v:Name() .. " has " .. slaycounter .. " remaining autoslays.")
                    end
                end

                if IsValid(v.server_ragdoll) then
                    local ply = player.GetBySteamID(v.server_ragdoll.sid)
                    if not IsValid(ply) then return end
                    ply:SetCleanRound(false)
                    ply:SetNWBool("body_found", true)

                    if ply:GetRole() == ROLE_TRAITOR
                      or TTT2 and ply:GetTeam() == TEAM_TRAITOR
                      or CR_VERSION and ply:IsTraitorTeam() then
                        SendConfirmedTraitors(GetInnocentFilter(false))
                    end

                    CORPSE.SetFound(v.server_ragdoll, true)
                    v.server_ragdoll:Remove()
                end
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "Autoslay_Message", function(ply)
    if ply.AutoslaysLeft and tonumber(ply.AutoslaysLeft) > 0 then
        net.Start("DL_PlayerLeft")
        net.WriteString(ply:Nick())
        net.WriteString(ply:SteamID())
        net.WriteUInt(ply.AutoslaysLeft, 32)
        net.Broadcast()
    end
end)

if Damagelog.ULX_Autoslay_ForceRole then
    hook.Add("Initialize", "Autoslay_ForceRole", function()
        if not TTT2 and not CR_VERSION then
            local function GetTraitorCount(ply_count)
                local traitor_count = math.floor(ply_count * GetConVar("ttt_traitor_pct"):GetFloat())
                traitor_count = math.Clamp(traitor_count, 1, GetConVar("ttt_traitor_max"):GetInt())

                return traitor_count
            end

            local function GetDetectiveCount(ply_count)
                if ply_count < GetConVar("ttt_detective_min_players"):GetInt() then return 0 end
                local det_count = math.floor(ply_count * GetConVar("ttt_detective_pct"):GetFloat())
                det_count = math.Clamp(det_count, 1, GetConVar("ttt_detective_max"):GetInt())

                return det_count
            end

            function SelectRoles()
                local choices = {}

                local prev_roles = {
                    [ROLE_INNOCENT] = {},
                    [ROLE_TRAITOR] = {},
                    [ROLE_DETECTIVE] = {}
                }

                if not GAMEMODE.LastRole then
                    GAMEMODE.LastRole = {}
                end

                for _, v in ipairs(player.GetHumans()) do
                    if IsValid(v) and (not v:IsSpec()) and not (v.AutoslaysLeft and tonumber(v.AutoslaysLeft) > 0) then
                        local r = GAMEMODE.LastRole[v:SteamID()] or v:GetRole() or ROLE_INNOCENT
                        table.insert(prev_roles[r], v)
                        table.insert(choices, v)
                    end

                    v:SetRole(ROLE_INNOCENT)
                end

                local choice_count = #choices
                local traitor_count = GetTraitorCount(choice_count)
                local det_count = GetDetectiveCount(choice_count)
                if choice_count == 0 then return end
                local ts = 0

                while ts < traitor_count do
                    local pick = math.random(1, #choices)
                    local pply = choices[pick]

                    if IsValid(pply) and ((not table.HasValue(prev_roles[ROLE_TRAITOR], pply)) or (math.random(1, 3) == 2)) then
                        pply:SetRole(ROLE_TRAITOR)
                        table.remove(choices, pick)
                        ts = ts + 1
                    end
                end

                local ds = 0
                local min_karma = GetConVar("ttt_detective_karma_min"):GetInt()

                while ds < det_count and #choices >= 1 do
                    if #choices <= (det_count - ds) then
                        for _, pply in pairs(choices) do
                            if IsValid(pply) then
                                pply:SetRole(ROLE_DETECTIVE)
                            end
                        end

                        break
                    end

                    local pick = math.random(1, #choices)
                    local pply = choices[pick]

                    if IsValid(pply) and (pply:GetBaseKarma() > min_karma and table.HasValue(prev_roles[ROLE_INNOCENT], pply) or math.random(1, 3) == 2) then
                        if not pply:GetAvoidDetective() then
                            pply:SetRole(ROLE_DETECTIVE)
                            ds = ds + 1
                        end

                        table.remove(choices, pick)
                    end
                end

                GAMEMODE.LastRole = {}

                for _, ply in ipairs(player.GetHumans()) do
                    ply:SetDefaultCredits()
                    GAMEMODE.LastRole[ply:SteamID()] = ply:GetRole()
                end
            end
        end
    end)
end
