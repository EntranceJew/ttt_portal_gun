-- ------------------------------------------------------------------------
-- WEAPON PORTALGUN FOR GARRY'S MOD 13 --
-- WRITEN BY WHEATLEY AND JULIAN7752
-- ------------------------------------------------------------------------
AddCSLuaFile()

SWEP.Base = 'weapon_tttbase'
SWEP.Kind = WEAPON_EQUIP1

SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}

SWEP.AutoSpawnable = false
SWEP.InLoadoutFor = nil
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = true

if CLIENT then
    -- Path to the icon material
    SWEP.Icon = 'vgui/ttt/pg_wall' -- Text shown in the equip menu

    SWEP.EquipMenuData = {
        type = 'Weapon',
        desc = 'Makes holes. Not bullet holes.'
    }
end

if SERVER then
    resource.AddFile('materials/vgui/ttt/pg_wall.vmt')
end

CreateConVar('portalmod_shot_mask', tostring(MASK_SHOT_PORTAL), {FCVAR_NOTIFY, FCVAR_ARCHIVE})

-- //TTT Convertion Code \\
SWEP.Author = 'Wheatley, Port by Julian7752, Version 2.0 by Zu, Fixed by doodlezucc'
SWEP.Purpose = 'Makes holes. Not bullet holes.'
SWEP.Category = 'Portal'
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.AutoSwitchTo = true
SWEP.ViewModel = 'models/weapons/v_portalgunv2.mdl'
SWEP.WorldModel = 'models/weapons/w_models/w_portalgun/w_portalgunv2.mdl'
SWEP.HoldType = 'ar2'
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = true
SWEP.ViewModelFOV = 60
SWEP.ViewModelFlip = false
SWEP.RefireInterval = 0.415
SWEP.Weight = 2
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.PrintName = 'Portalgun'
SWEP.Slot = 8
SWEP.SlotPos = 4
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.CanFirePortal1 = true
SWEP.CanFirePortal2 = true
SWEP.HoldenProp = NULL
SWEP.NextAllowedPickup = 0
SWEP.PickupSound = nil
SWEP.LastPortal = false

SWEP.TPEnts = {'player',}

SWEP.BumpProps = {'models/props/portal_emitter.mdl'}

SWEP.BadSurfaces = {'prop_dynamic', 'prop_static', 'func_door', 'func_button', 'func_door_rotating',}

if SERVER then
    util.AddNetworkString('PORTALGUN_PICKUP_PROP')
    util.AddNetworkString('PORTALGUN_SHOOT_PORTAL')
end

net.Receive('PORTALGUN_SHOOT_PORTAL', function()
    local pl = net.ReadEntity()
    local port = net.ReadEntity()
    local ptype = ((net.ReadFloat() == 1) and true or false)

    if (ptype) then
        pl:SetNWEntity('PORTALGUN_PORTALS_RED', port)
    else
        pl:SetNWEntity('PORTALGUN_PORTALS_BLUE', port)
    end
end)

if SERVER then
    concommand.Add('portalmod_clearportals', function(ply)
        for i, v in pairs(ents.GetAll()) do
            if IsValid(v) and ply:GetNWEntity('PORTALGUN_PORTALS_RED') == v then
                SafeRemoveEntity(v)
            elseif IsValid(v) and ply:GetNWEntity('PORTALGUN_PORTALS_BLUE') == v then
                SafeRemoveEntity(v)
            end
        end
    end)
end

local function IsPickable(ent)
    if IsValid(ent) then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            return phys:GetMass() <= 35
        end
    end

    return false
end

hook.Add('AllowPlayerPickup', 'DisallowPickup', function(ply, ent)
    local hasgun = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == 'weapon_portalgun'
    if not hasgun or not IsPickable(ent) then return false end

    return true
end)

-- Tell Gmod to render all objects visible from any portal
hook.Add('SetupPlayerVisibility', 'PORTALGUN_PORTAL_SETUPVIS', function(ply, ent)
    for _, v in pairs(ents.GetAll()) do
        if v:GetClass() == 'portalgun_portal' then
            AddOriginToPVS(v:GetPos())
        end
    end
end)

function SWEP:Initialize()
    self:SetWeaponHoldType('shotgun')
end

function SWEP:Holster(wep)
    return true
end

local function PortalTraceFilter(ent)
    if IsValid(ent) then
        if ent:IsPlayer() then return false end -- players
        if ent:IsWeapon() then return false end
        if IsPickable(ent) then return false end -- some props
    end

    return true
end

local function PortalTrace(data)
    return util.TraceLine({
        start = data.start,
        endpos = data.endpos,
        mask = data.mask,
        filter = PortalTraceFilter
    })
end

local function TraceHit(gun)
    local owner = gun:GetOwner()

    if owner ~= NULL and owner:IsPlayer() then
        local maskString = GetConVar('portalmod_shot_mask'):GetString()

        return PortalTrace({
            start = owner:EyePos(),
            endpos = owner:EyePos() + (owner:EyeAngles():Forward()) * 30000,
            mask = tonumber(maskString)
        })
    else
        return PortalTrace({
            start = gun:GetPos(),
            endpos = gun:GetPos() + gun:GetAngles():Forward() * 30000,
        })
    end
end

function SWEP:DispatchSparkEffect()
    local hit = TraceHit(self)

    if CLIENT then return end
    local sprk = ents.Create('env_spark')
    sprk:SetPos(hit.HitPos)
    sprk:Spawn()
    sprk:Activate()
    sprk:EmitSound('weapons/portalgun/portal_invalid_surface_0' .. math.random(1, 4) .. '.wav')
    sprk:Fire('SparkOnce', 0, 0)

    timer.Simple(0.3, function()
        SafeRemoveEntity(sprk)
    end)
end

function SWEP:PerformAttack(canFire, ptype, sound_id)
    if not canFire or IsValid(self.HoldenProp) then return end
    self:SetNextPrimaryFire(CurTime() + self.RefireInterval)
    self:SetNextSecondaryFire(CurTime() + self.RefireInterval)

    if IsValid(self:GetOwner()) and self:GetOwner():WaterLevel() >= 3 then
        return self:PlayFizzleAnimation()
    end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:EmitSound('weapons/portalgun/wpn_portal_gun_fire_' .. sound_id .. '_0' .. math.random(1, 3) .. '.wav')

    if not self:CanPlacePortal(ptype) then
        return self:DispatchSparkEffect()
    end

    self.LastPortal = ptype
    self:CreateShootEffect(ptype)
    self:FirePortal(ptype)
end

function SWEP:PrimaryAttack() self:PerformAttack(self.CanFirePortal1, false, 'blue') end
function SWEP:SecondaryAttack() self:PerformAttack(self.CanFirePortal2, true, 'red') end

function SWEP:CreateShootEffect(ptype)
    if SERVER then
        if self:GetOwner() ~= NULL and self:GetOwner():IsPlayer() then
            local vec = Vector(12, -2, -3)
            vec:Rotate(self:GetOwner():EyeAngles())
            source = self:GetOwner():GetShootPos() + vec
        end
    end
end

function SWEP:CanPlacePortal(ptype)
    local tr = TraceHit(self)
    local ang = tr.HitNormal:Angle()
    local r = ang:Right()
    local f = ang:Forward()
    local u = ang:Up()
    local p = tr.HitPos
    local size = tr.Entity ~= NULL and (tr.Entity:OBBMaxs() - tr.Entity:OBBMins()):Length() or 0
    local portalsize = 134

    if size < portalsize and not tr.Entity:IsWorld() then return false end

    if IsValid(tr.Entity) then
        if tr.Entity:GetNWBool('Portalmod_InvalidSurface') then return false end
            
        if string.sub(tr.Entity:GetClass(), 1, 4) == 'sent' then return false end
        
        if tr.Entity:IsNPC() then return false end
        
        if table.HasValue(self.BadSurfaces, tr.Entity:GetClass()) then return false end
        
        if tr.Entity:GetNWBool('INVALID_SURFACE') then return false end
    end

    if tr.MatType == MAT_GLASS or tr.HitSky then return false end

    for i, v in pairs(ents.FindInBox(p + (r * 33 + u * 76 + f * 5), p - (r * 33 + u * 76))) do
        if v:GetClass() == 'portalgun_portal' and ptype != v:GetNWBool('PORTALTYPE') then
            return false
        end
    end

    return true
end

function SWEP:Think()
    if self:GetOwner() then
        -- SKIN FUNC
        self:SetSkin(self:GetOwner():GetNWInt('PORTALGUNTYPE'))

        -- HOLDING FUNC
        if IsValid(self.HoldenProp) then
            local tr = util.TraceLine({
                start = self:GetOwner():EyePos(),
                endpos = self:GetOwner():EyePos() + self:GetOwner():EyeAngles():Forward() * 70,
                filter = {self:GetOwner(), self.HoldenProp}
            })

            self.HoldenProp:SetPos(tr.HitPos - self.HoldenProp:OBBCenter())
            self.HoldenProp:SetAngles(self:GetOwner():EyeAngles())
        elseif not IsValid(self.HoldenProp) and self.HoldenProp ~= NULL then
            self:DropProp()
        end

        if self:GetOwner():KeyDown(IN_USE) and self.NextAllowedPickup < CurTime() and SERVER then
            local ply = self:GetOwner()
            self.NextAllowedPickup = CurTime() + 0.4

            local tr = util.TraceLine({
                start = ply:EyePos(),
                endpos = ply:EyePos() + ply:EyeAngles():Forward() * 150,
                filter = ply
            })

            -- DROP FUNC
            if IsValid(self.HoldenProp) and self.HoldenProp ~= NULL and self:DropProp() then return end

            -- PORTAL PICKUP FUNC
            for i, v in pairs(ents.FindInSphere(tr.HitPos, 5)) do
                if string.find(v:GetClass(), 'portalgun_portal_') and PortalGunValid(v) then return end
            end

            self:EmitSound('common/wpn_select.wav')
            self:SendWeaponAnim(ACT_VM_DRYFIRE)
        end
    end
end

function SWEP:PortalGunValid(v)
    local distprec = 1 - v:GetPos():Distance(self:GetOwner():EyePos()) / 150 -- get distance
    local portal = v:GetLinkedPortal()
    if not IsValid(portal) then return true end -- no portal - can't pickup

    local tr = util.TraceLine({
        start = portal:GetPos(),
        endpos = portal:GetPos() - portal:GetAngles():Forward() * (150 * distprec) - Vector(0, 0, 35),
        filter = portal
    })

    if IsValid(tr.Entity) and table.HasValue(self.TPEnts, tr.Entity:GetClass()) and not tr.Entity:IsPlayer() then
        local op = portal:GetLinkedPortal()
        if not IsValid(op) then return true end
        op:SetNext(CurTime() + op.NextTeleportCool)
        portal:TeleportEntityToPortal(tr.Entity, op)
        if self:PickupProp(tr.Entity) then return true end
    end
end

function SWEP:FirePortal(ptype)
    local ent
    local owner = (self:GetOwner() ~= NULL) and self:GetOwner() or player.GetAll()[1]

    if SERVER then
        local tr = TraceHit(self)
        local pos = tr.HitPos
        local hitAng = tr.HitNormal:Angle()
        local right = hitAng:Right() * 30
        local up = hitAng:Up() * 50
        local fwd = hitAng:Forward()

        -- Prevent portals from spawning inside each other
        for i, v in pairs(ents.FindInBox(pos + (right + up + hitAng:Forward()), pos - (right + up))) do
            if IsValid(v) and v ~= self and v ~= self.ParentEntity and v:GetClass() == 'portalgun_portal' then
                -- Another portal blocks except when it's being replaced by this new one
                local getsReplaced = v.RealOwner == owner and v:GetNWBool('PORTALTYPE') == ptype

                if not getsReplaced then
                    self:DispatchSparkEffect()
                    return
                end
            end
        end

        local portalpos = pos
        local portalang
        local ownerent = tr.Entity

        if tr.HitNormal == Vector(0, 0, 1) then
            portalang = tr.HitNormal:Angle() + Angle(180, owner:GetAngles().y, 180)
        elseif tr.HitNormal == Vector(0, 0, -1) then
            portalang = tr.HitNormal:Angle() + Angle(180, owner:GetAngles().y, 180)
        else
            portalang = tr.HitNormal:Angle() - Angle(180, 0, 0)
        end

        -- Traces a line from the hit position to a relative offset
        local function TraceRelative(off)
            return util.TraceLine({
                start = pos,
                endpos = pos + off
            })
        end

        local tr_up = TraceRelative(up)
        local tr_down = TraceRelative(-up)
        local tr_left = TraceRelative(right)
        local tr_right = TraceRelative(-right)

        -- Checks if one side of the portal will be off a flat surface
        local function NotFlat(off)
            local delta = pos + off
            return not util.TraceLine({
                start = delta,
                endpos = delta - fwd
            }).Hit
        end

        -- Abort if the portal will not be on a flat surface
        up = hitAng:Up() * 48
        if (tr_up.Hit and tr_down.Hit) or (tr_left.Hit and tr_right.Hit) or NotFlat(-right) or NotFlat(right) or NotFlat(up) or NotFlat(-up) then
            self:DispatchSparkEffect()
            return
        end

        ent = ents.Create('portalgun_portal')
        ent:SetNWBool('PORTALTYPE', ptype)
        local ang = tr.HitNormal:Angle() - Angle(90, 0, 0)
        local coords = Vector(35, 35, 25)
        coords:Rotate(ang)
        up = tr.HitNormal:Angle():Up() * 50
        local lr_fract = Vector(0, 0, 0)
        local ud_fract = Vector(0, 0, 0)

        if tr_left.Hit then
            lr_fract = (right * (1 - tr_left.Fraction))
        elseif tr_right.Hit then
            lr_fract = (-right * (1 - tr_right.Fraction))
        end

        if tr_up.Hit then
            ud_fract = up * (1 - tr_up.Fraction)
        elseif tr_down.Hit then
            ud_fract = -up * (1 - tr_down.Fraction)
        end

        ent:SetPos(portalpos - lr_fract - ud_fract)

        for i, v in pairs(ents.FindInBox(pos + coords, pos - coords)) do
            if table.HasValue(self.BumpProps, v:GetModel()) then
                ent:SetPos(v:GetPos())
                ownerent = v
                portalang = v:GetAngles() - Angle(180, 0, 0)

                if ptype then
                    v:SetSkin(2)
                else
                    v:SetSkin(1)
                end
            end
        end

        ent:SetAngles(portalang)
        ent.RealOwner = owner
        ent.ParentEntity = ownerent
        ent.AllowedEntities = self.TPEnts
        ent:Spawn()

        if tr.HitNormal == Vector(0, 0, 1) then
            ent.PlacedOnGround = true
        elseif tr.HitNormal == Vector(0, 0, -1) then
            ent.PlacedOnCeiling = true
        end

        if not ownerent:IsWorld() then
            ent:SetParent(ownerent)
        end

        ent:SetNWEntity('portalowner', owner)
        --ent:UpdateEntityData()
        self:RemoveSelectedPortal(ptype) -- remove old portal

        if (ptype) then
            owner:SetNWEntity('PORTALGUN_PORTALS_RED', ent)
        else
            owner:SetNWEntity('PORTALGUN_PORTALS_BLUE', ent)
        end

        net.Start('PORTALGUN_SHOOT_PORTAL')
        net.WriteEntity(owner)
        net.WriteEntity(ent)
        net.WriteFloat((ptype == true) and 1 or 0)
        net.Send(player.GetAll())
    end

    if CLIENT then
        if (ptype) then
            local p1 = owner:GetNWEntity('PORTALGUN_PORTALS_RED', ent)

            if IsValid(p1) then
                p1.RealOwner = owner
            end
        else
            local p1 = owner:GetNWEntity('PORTALGUN_PORTALS_BLUE', ent)

            if IsValid(p1) then
                p1.RealOwner = owner
            end
        end
    end
end

function SWEP:RemoveSelectedPortal(ptype)
    local owner = (self:GetOwner() ~= NULL) and self:GetOwner() or player.GetAll()[1]

    for i, v in pairs(ents.GetAll()) do
        if IsValid(v) and ptype == true and owner:GetNWEntity('PORTALGUN_PORTALS_RED') == v then
            SafeRemoveEntity(v)
        elseif IsValid(v) and ptype == false and owner:GetNWEntity('PORTALGUN_PORTALS_BLUE') == v then
            SafeRemoveEntity(v)
        end
    end
end

function SWEP:Reload()
    local owner = (self:GetOwner() ~= NULL) and self:GetOwner() or player.GetAll()[1]

    if SERVER then
        self:RemoveSelectedPortal(true)
        self:RemoveSelectedPortal(false)
    end

    if IsValid(owner) then
        owner:SetNWEntity('PORTALGUN_PORTALS_RED', NULL)
        owner:SetNWEntity('PORTALGUN_PORTALS_BLUE', NULL)
    end
end

function SWEP:OnRemove()
    local owner = (self:GetOwner() ~= NULL) and self:GetOwner() or player.GetAll()[1]

    if SERVER and owner and not owner:Alive() then
        self:RemoveSelectedPortal(true)
        self:RemoveSelectedPortal(false)
    end

    if IsValid(owner) then
        owner:SetNWEntity('PORTALGUN_PORTALS_RED', NULL)
        owner:SetNWEntity('PORTALGUN_PORTALS_BLUE', NULL)
    end
end

function SWEP:AcceptInput(input, activator, called, data)
    if input == 'FirePortal1' then
        self:PrimaryAttack()
    elseif input == 'FirePortal2' then
        self:SecondaryAttack()
    end
end

function SWEP:KeyValue(k, v)
    if k == 'CanFirePortal1' then
        self.CanFirePortal1 = v == '1'
    
    elseif k == 'CanFirePortal2' then
        self.CanFirePortal2 = v == '1'
    end
end

function SWEP:PlayFizzleAnimation()
    self:EmitSound('weapons/portalgun/portal_fizzle_0' .. math.random(1, 2) .. '.wav')
    self:SendWeaponAnim(ACT_VM_DRYFIRE)
end

local crosshair_full = Material('hud/portalgun_crosshair_full.png')
local crosshair_empty = Material('hud/portalgun_crosshair_empty.png')
local crosshair_orange = Material('hud/portalgun_crosshair_right.png')
local crosshair_blue = Material('hud/portalgun_crosshair_left.png')

function SWEP:DrawHUD()
    surface.SetDrawColor(255, 255, 255, 255)
    local current = crosshair_empty

    if self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_RED') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_BLUE') ~= NULL or self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_AT1') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_AT2') ~= NULL or self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_PB1') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_PB2') ~= NULL then
        current = crosshair_full
    elseif self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_BLUE') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_RED') == NULL or self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_AT1') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_AT2') == NULL or self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_PB1') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_PB2') == NULL then
        current = crosshair_blue
    elseif self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_RED') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_BLUE') == NULL or self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_AT1') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_AT2') == NULL or self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_PB1') ~= NULL and self:GetOwner():GetNWEntity('PORTALGUN_PORTALS_PB2') == NULL then
        current = crosshair_orange
    else
        current = crosshair_empty
    end

    surface.SetMaterial(current)
    surface.DrawTexturedRect(ScrW() / 2 - 28, ScrH() / 2 - 37, 53, 72)
end

net.Receive('PORTALGUN_PICKUP_PROP', function()
    local slf = net.ReadEntity()
    local ent = net.ReadEntity()

    if not IsValid(ent) then
        if slf.PickupSound then
            slf.PickupSound:Stop()
            slf.PickupSound = nil
            EmitSound(Sound('player/object_use_stop_01.wav'), slf:GetPos(), 1, CHAN_AUTO, 0.4, 100, 0, 100)
        end
    else
        if not slf.PickupSound and CLIENT then
            slf.PickupSound = CreateSound(slf, 'player/object_use_lp_01.wav')
            slf.PickupSound:Play()
            slf.PickupSound:ChangeVolume(0.5, 0)
        end
    end

    slf.HoldenProp = ent
end)
