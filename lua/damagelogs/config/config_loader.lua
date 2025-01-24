--[[
When adding new configuration options:
1. Add it to lua\damagelogs\config\config.lua
Damagelog.MyNewProperty = "hello"

2. Add it to this file
In Damagelog:getConfig
config.MyNewProperty = DamageLog.MyNewProperty

In Damagelog:loadConfig
DamageLog.MyNewProperty = config.MyNewProperty

]]


function Damagelog:getConfig()
    local config = {}
    --Permissions
    config.Permissions = {}
    for user,right in pairs(Damagelog.User_rights) do    
        config.Permissions[user] = {}
        config.Permissions[user].access_level = right
        config.Permissions[user].can_access_rdm_manager = Damagelog.RDM_Manager_Rights[user]
    end
    config.Key = Damagelog.Key
    config.AbuseMessageMode = Damagelog.AbuseMessageMode
    config.RDM_Manager_Enabled = Damagelog.RDM_Manager_Enabled
    --Commands
    config.Commands = {}
    config.Commands.RDM_Manager_Command = Damagelog.RDM_Manager_Command
    config.Commands.Respond_Command = Damagelog.Respond_Command
    config.AutoRespond = Damagelog.AutoRespond
    config.Use_MySQL = Damagelog.Use_MySQL
    --Autoslay stuff
    config.Autoslay = {}
    config.Autoslay.ShowRemainingSlays = Damagelog.ShowRemainingSlays
    config.Autoslay.ULX_AutoslayMode = Damagelog.ULX_AutoslayMode
    config.Autoslay.ULX_Autoslay_ForceRole = Damagelog.ULX_Autoslay_ForceRole
    config.Autoslay.Autoslay_CheckCustom = Damagelog.Autoslay_CheckCustom
    config.Autoslay.DefaultReason = Damagelog.Autoslay_DefaultReason
    config.Autoslay.DefaultReason1 = Damagelog.Autoslay_DefaultReason1
    config.Autoslay.DefaultReason2 = Damagelog.Autoslay_DefaultReason2
    config.Autoslay.DefaultReason3 = Damagelog.Autoslay_DefaultReason3
    config.Autoslay.DefaultReason4 = Damagelog.Autoslay_DefaultReason4
    config.Autoslay.DefaultReason5 = Damagelog.Autoslay_DefaultReason5
    config.Autoslay.DefaultReason6 = Damagelog.Autoslay_DefaultReason6
    config.Autoslay.DefaultReason7 = Damagelog.Autoslay_DefaultReason7
    config.Autoslay.DefaultReason8 = Damagelog.Autoslay_DefaultReason8
    config.Autoslay.DefaultReason9 = Damagelog.Autoslay_DefaultReason9
    config.Autoslay.DefaultReason10 = Damagelog.Autoslay_DefaultReason10
    config.Autoslay.DefaultReason11 = Damagelog.Autoslay_DefaultReason11
    config.Autoslay.DefaultReason12 = Damagelog.Autoslay_DefaultReason12
    --Ban Stuff
    config.Ban = {}
    config.Ban.DefaultReason1 = Damagelog.Ban_DefaultReason1
    config.Ban.DefaultReason2 = Damagelog.Ban_DefaultReason2
    config.Ban.DefaultReason3 = Damagelog.Ban_DefaultReason3
    config.Ban.DefaultReason4 = Damagelog.Ban_DefaultReason4
    config.Ban.DefaultReason5 = Damagelog.Ban_DefaultReason5
    config.Ban.DefaultReason6 = Damagelog.Ban_DefaultReason6
    config.Ban.DefaultReason7 = Damagelog.Ban_DefaultReason7
    config.Ban.DefaultReason8 = Damagelog.Ban_DefaultReason8
    config.Ban.DefaultReason9 = Damagelog.Ban_DefaultReason9
    config.Ban.DefaultReason10 = Damagelog.Ban_DefaultReason10
    config.Ban.DefaultReason11 = Damagelog.Ban_DefaultReason11
    config.Ban.DefaultReason12 = Damagelog.Ban_DefaultReason12
    config.Ban.AllowBanningThruManager = Damagelog.AllowBanningThruManager
    
    config.LogDays = Damagelog.LogDays
    config.HideDonateButton = Damagelog.HideDonateButton
    config.UseWorkshop = Damagelog.UseWorkshop
    config.ForcedLanguage = Damagelog.ForcedLanguage
    --Report stuff
    config.Reports = {}
    config.Reports.NoStaffReports = Damagelog.NoStaffReports
    config.Reports.MoreReportsPerRound = Damagelog.MoreReportsPerRound
    config.Reports.ReportsBeforePlaying = Damagelog.ReportsBeforePlaying

    config.PrivateMessagePrefix = Damagelog.PrivateMessagePrefix
    config.DiscordWebhookMode = Damagelog.DiscordWebhookMode

    return config
end

function Damagelog:saveConfig()
    local config = Damagelog:getConfig()
    file.Write("damagelog/config.json",util.TableToJSON(config,true))
end

function Damagelog:loadConfig()
    if not file.Exists("damagelog/config.json", "DATA") then --If no config exists save the default config (config.lua) and return as if we loaded one.
        Damagelog:saveConfig()
        return
    end
    local loaded_config = util.JSONToTable(file.Read("damagelog/config.json", "DATA"))
    if not loaded_config then
        ErrorNoHalt("Damagelogs: ERROR - Config Exists but is not valid JSON! Using default config.") 
        return
    end
    
    Damagelog:loadConfigFromTable(loaded_config)
end

function Damagelog:loadConfigFromTable(loaded_config)
    local config = Damagelog:getConfig()    
    
    --Clear out current users and rights
    Damagelog.User_rights = {}
    Damagelog.RDM_Manager_Rights = {}
    if loaded_config.Permissions != nil then  --Have to handle Perms a bit different then other config value since we don't want to use the defaults if someone has their own configured in the json config.
        for user,data in pairs(loaded_config.Permissions) do
            if data.access_level != nil and data.can_access_rdm_manager != nil then --Need to check for nils 
                Damagelog:AddUser(user,data.access_level,data.can_access_rdm_manager)
            end
        end
    else --If they don't have a valid Permission section in their JSON use the lua config / default.
        for user,data in pairs(config.Permissions) do
            Damagelog:AddUser(user,data.access_level,data.can_access_rdm_manager)
        end
    end
    
    table.Merge(config,loaded_config) --Merge loaded json config into the lua config.

    Damagelog.Key = config.Key
    Damagelog.AbuseMessageMode = config.AbuseMessageMode
    Damagelog.RDM_Manager_Enabled = config.RDM_Manager_Enabled
    Damagelog.RDM_Manager_Command = config.Commands.RDM_Manager_Command
    Damagelog.Respond_Command = config.Commands.Respond_Command
    Damagelog.AutoRespond = config.AutoRespond
    Damagelog.Use_MySQL = Damagelog.Use_MySQL
    
    Damagelog.ShowRemainingSlays = config.Autoslay.ShowRemainingSlays

    Damagelog.ULX_AutoslayMode = config.Autoslay.ULX_AutoslayMode
    Damagelog.ULX_Autoslay_ForceRole = config.Autoslay.ULX_Autoslay_ForceRole
    Damagelog.Autoslay_CheckCustom = config.Autoslay.Autoslay_CheckCustom

    Damagelog.Autoslay_DefaultReason = config.Autoslay.DefaultReason
    Damagelog.Autoslay_DefaultReason1 = config.Autoslay.DefaultReason1
    Damagelog.Autoslay_DefaultReason2 = config.Autoslay.DefaultReason2
    Damagelog.Autoslay_DefaultReason3 = config.Autoslay.DefaultReason3
    Damagelog.Autoslay_DefaultReason4 = config.Autoslay.DefaultReason4
    Damagelog.Autoslay_DefaultReason5 = config.Autoslay.DefaultReason5
    Damagelog.Autoslay_DefaultReason6 = config.Autoslay.DefaultReason6
    Damagelog.Autoslay_DefaultReason7 = config.Autoslay.DefaultReason7
    Damagelog.Autoslay_DefaultReason8 = config.Autoslay.DefaultReason8
    Damagelog.Autoslay_DefaultReason9 = config.Autoslay.DefaultReason9
    Damagelog.Autoslay_DefaultReason10 = config.Autoslay.DefaultReason10
    Damagelog.Autoslay_DefaultReason11 = config.Autoslay.DefaultReason11

    Damagelog.AllowBanningThruManager = config.Ban.AllowBanningThruManager

    Damagelog.Ban_DefaultReason1 = config.Ban.DefaultReason1
    Damagelog.Ban_DefaultReason2 = config.Ban.DefaultReason2
    Damagelog.Ban_DefaultReason3 = config.Ban.DefaultReason3
    Damagelog.Ban_DefaultReason4 = config.Ban.DefaultReason4
    Damagelog.Ban_DefaultReason5 = config.Ban.DefaultReason5
    Damagelog.Ban_DefaultReason6 = config.Ban.DefaultReason6
    Damagelog.Ban_DefaultReason7 = config.Ban.DefaultReason7
    Damagelog.Ban_DefaultReason8 = config.Ban.DefaultReason8
    Damagelog.Ban_DefaultReason9 = config.Ban.DefaultReason9
    Damagelog.Ban_DefaultReason10 = config.Ban.DefaultReason10
    Damagelog.Ban_DefaultReason11 = config.Ban.DefaultReason11
    Damagelog.Ban_DefaultReason12 = config.Ban.DefaultReason12

    Damagelog.NoStaffReports = config.Reports.NoStaffReports

    Damagelog.MoreReportsPerRound = config.Reports.MoreReportsPerRound

    Damagelog.ReportsBeforePlaying = config.Reports.ReportsBeforePlaying

    Damagelog.LogDays = config.LogDays

    Damagelog.HideDonateButton = config.HideDonateButton

    Damagelog.UseWorkshop = config.UseWorkshop

    Damagelog.ForcedLanguage = config.ForcedLanguage

    Damagelog.PrivateMessagePrefix = config.PrivateMessagePrefix

    Damagelog.DiscordWebhookMode = config.DiscordWebhookMode
    
end

function Damagelog:loadMySQLConfig()
    if not file.Exists("damagelog/mysql.json", "DATA") then --If no mysql config exists save the default and return as if we loaded one.
        Damagelog:saveMySQLConfig()
        return
    end
    local config = util.JSONToTable(file.Read("damagelog/mysql.json", "DATA"))
    if not config then
        ErrorNoHalt("Damagelogs: ERROR - MySQL Config Exists but is not valid JSON!")
        return
    end
    Damagelog.MySQL_Informations = config

end

function Damagelog:saveMySQLConfig()
    file.Write("damagelog/mysql.json",util.TableToJSON(Damagelog.MySQL_Informations,true))
end

