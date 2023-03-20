if SERVER then
    AddCSLuaFile()
    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_spir.vmt")
end

function ROLE:PreInitialize()
    self.index = ROLE_SPIRIT
    self.color = Color(197, 209, 175, 255)
    self.abbr = "spir"

    self.defaultTeam = TEAM_INNOCENT
    self.score.killsMultiplier = 2
    self.score.teamKillsMultiplier = -8
    self.unknownTeam = true

    self.conVarData = {
        pct = 0.15,       -- necessary: percentage of getting this role selected (per player)
        maximum = 1,      -- maximum amount of roles in a round
        minPlayers = 3,   -- minimum amount of players until this role is able to get selected
        togglable = true, -- option to toggle a role for a client if possible (F1 menu)
        random = 20
    }
end

function ROLE:Initialize()
    roles.SetBaseRole(self, ROLE_INNOCENT)
end

-- Spawn a translucent player model as the spectator's child when their corpse gets confirmed.
-- The model gets removed if the player somehow respawns before the round restarts.
if SERVER then
    local function spawn_spirit(ply)
        if not IsValid(ply) then return end
        if ply:GetSubRole() ~= ROLE_SPIRIT then return end
        if IsValid(ply:GetNW2Entity("ttt2_spirit_entity")) then return end

        local spirit_ent = ents.Create("prop_dynamic")
        spirit_ent:SetModel(ply:GetModel())
        spirit_ent:SetPos(ply:GetPos() - Vector(0, 0, 64))
        spirit_ent:SetAngles(Angle(0, ply:GetAngles().yaw, 0))
        spirit_ent:SetNotSolid(true)
        spirit_ent:Spawn()
        spirit_ent:SetColor(Color(245, 245, 245, 100))
        spirit_ent:SetRenderMode(RENDERMODE_GLOW)
        spirit_ent:SetMoveType(MOVETYPE_NONE)
        spirit_ent:SetParent(ply)

        ply:SetNW2Entity("ttt2_spirit_entity", spirit_ent)
    end

    hook.Add("PlayerSpawn", "Spirit/ResetSpiritEntity", function(ply)
        if not IsValid(ply) then return end
        local spirit_ent = ply:GetNW2Entity("ttt2_spirit_entity")
        if not IsValid(spirit_ent) then return end
        spirit_ent:Remove()
    end)

    hook.Add("TTT2Initialize", "Spirit/OverrideConfirmPlayer", function()
        local plymeta = FindMetaTable("Player")
        local old_ConfirmPlayer = plymeta.ConfirmPlayer
        function plymeta:ConfirmPlayer(announceRole)
            old_ConfirmPlayer(self, announceRole)
            spawn_spirit(self)
        end
    end)
end

-- Player angles are not properly networked while they're in spectator mode.
-- Other clients do not seem to get any angle updates and the server only receives the yaw value for whatever reason.
-- This is why we manually network the yaw value of spirit spectators from the server to all clients.
-- The spirit model will therefore not rotate very smoothly and won't look up or down (pitch = 0).
-- (In my opinion that's completely fine though, almost adds to the effect...)
if SERVER then
    hook.Add("Think", "Spirit/SetNWAngle", function()
        for _, ply in ipairs(player.GetAll()) do
            if not ply:Alive() then
                local spirit_ent = ply:GetNW2Entity("ttt2_spirit_entity")
                if IsValid(spirit_ent) then
                    spirit_ent:SetNW2Angle("ttt2_spirit_angle", Angle(0, spirit_ent:GetAngles().yaw, 0))
                end
            end
        end
    end)
elseif CLIENT then
    hook.Add("Think", "Spirit/ApplyNWAngleUpdate", function()
        for _, ply in ipairs(player.GetAll()) do
            if not ply:Alive() then
                local spirit_ent = ply:GetNW2Entity("ttt2_spirit_entity")
                if IsValid(spirit_ent) then
                    spirit_ent:SetAngles(spirit_ent:GetNW2Angle("ttt2_spirit_angle"))
                end
            end
        end
    end)
end
