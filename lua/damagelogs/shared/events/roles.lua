if SERVER then
    --Global Variables Unavailable? find how to hook later
    --if CR_VERSION then
    Damagelog:EventHook("TTTPlayerRoleChanged")
    Damagelog:EventHook("TTTPlayerRoleChangedByItem")
    --elseif TTT2 then
        --TODO
    --else
        --UNUSED
    --end
    Damagelog:EventHook("PlayerSpawn")
else
    Damagelog:AddFilter("filter_show_roles", DAMAGELOG_FILTER_BOOL, true)
    Damagelog:AddColor("color_roles", Color(128, 64, 0))
end
local event = {}
event.Type = "ROLE"

function event:TTTPlayerRoleChanged(ply, oldRole, newRole)
    if oldRole == nil or oldRole == ROLE_NONE or oldRole == newRole or newRole == ROLE_NONE then return end
    self.CallEvent({
        [1] = 1,
        [2] = ply:GetDamagelogID(),
        [3] = oldRole,
        [4] = newRole
    })
    Damagelog:UpdateRecentRole(ply, newRole)
end

function event:TTTPlayerRoleChangedByItem(ply, tgt, item)
    if not IsValid(item) then return end
    self.CallEvent({
        [1] = 2,
        [2] = ply:GetDamagelogID(),
        [3] = tgt:GetDamagelogID(),
        [4] = IsEntity(item) and item:GetClass() or item
    })
end

function event:PlayerSpawn(ply)
    self.CallEvent({
        [1] = 3,
        [2] = ply:GetDamagelogID(),
    })
end


function event:ToString(v, roles)
    local ply = Damagelog:InfoFromID(roles, v[2])

    if v[1] == 1 then
        return string.format(TTTLogTranslate(GetDMGLogLang, "role_change"), ply.nick, Damagelog:StrRole(v[3]), Damagelog:StrRole(v[4]))
    elseif v[1] == 2 then
        local tgt = Damagelog:InfoFromID(roles, v[3])
        return string.format(TTTLogTranslate(GetDMGLogLang, "role_item"), ply.nick, Damagelog:StrRole(ply.role),  Damagelog:GetWeaponName(v[4]), tgt.nick, Damagelog:StrRole(tgt.role))
    elseif v[1] == 3 then
        return string.format(TTTLogTranslate(GetDMGLogLang, "revive"), ply.nick, Damagelog:StrRole(ply.role))
    end
end

function event:IsAllowed(tbl)
    return Damagelog.filter_settings["filter_show_roles"]
end

function event:Highlight(line, tbl, text)
    return table.HasValue(Damagelog.Highlighted, tbl[1])
end

function event:GetColor(tbl)
    return Damagelog:GetColor("color_roles")
end

function event:RightClick(line, tbl, roles, text)
    line:ShowTooLong(true)
    local ply = Damagelog:InfoFromID(roles, tbl[2])
    if tbl[1] == 2 then
        local tgt = Damagelog:InfoFromID(roles, tbl[3])
        line:ShowCopy(true, {ply.nick, util.SteamIDFrom64(ply.steamid64)}, {tgt.nick, util.SteamIDFrom64(tgt.steamid64)})
        return
    end
    line:ShowCopy(true, {ply.nick, util.SteamIDFrom64(ply.steamid64)})
end

Damagelog:AddEvent(event)