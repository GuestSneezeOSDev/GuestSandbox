--	
--	Prepare for sub-standard commenting,
--	and somewhat confusing variable names,
--	you are in my domain now >:)
--	
--  
--  
--	started July 12, 2020
--	have gone through 1 complete rework since then
-- 	the new files claim they were created October 3, 2021
--	but I think I was reworking it way before then.
--	
--	
--	
-- 	Anyway, what are you doing here?
--	
--	P.S.: There is spaghetti code too.





SWEP.Author = "CodeKraken"
SWEP.Purpose = "Pick up and move multible object at once"
SWEP.Instructions = " Left Click:  fire beams,\n Right Click:  Freeze grabbed objects,\n Reload: Set object distances to be equal,\n Scroll:  Push or pull objects,\n Scroll+Run:  Adjust beam spacing"


SWEP.UseHands = true

SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.Category = "CodeKraken's SWEPS"
SWEP.PrintName = "Multi Physics Gun"

SWEP.ViewModel  = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel  = "models/weapons/w_physics.mdl"
SWEP.ViewModelFOV = 57

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false

SWEP.Slot = 0
SWEP.SlotPos = 4

-- HeldEnts is a table that contains tables that have the info for each held entity
SWEP.HeldEnts = {}

SWEP.can_reload = false
SWEP.can_secondary = false

SWEP.last_reload = 0
SWEP.last_secondary = 0

SWEP.weapon_color = Color(0,0,0,0)

SWEP.client_firing = false
SWEP.client_range = 0

-- list of weapon entities
local multiphysgun_halo_ents = {}

if(SERVER) then
	AddCSLuaFile ("shared.lua")
	
	SWEP.Weight = 5
	SWEP.AutoSwitchTo = false
	SWEP.AutoSwitchFrom = false
end



SWEP._initialized = false
function SWEP:Initialize()
	_initialized = true
	self:SetSkin(1)
	self.use_PhysgunPickup = GetConVar("multi_physics_gun_server_use_PhysgunPickup")
	self.use_MultiPhysgunPickup = GetConVar("multi_physics_gun_server_use_MultiPhysgunPickup")
	self.use_DefaultLimiters = GetConVar("multi_physics_gun_server_use_DefaultLimiters")
end

local function playerCanGrabRagdollBones(ply)

	return (GetConVar("multi_physics_gun_server_allow_grab_ragdoll_bone"):GetBool() and (ply:GetInfoNum("multi_physics_gun_can_grab_ragdoll_bone",0)==1))
end

if(CLIENT || game.SinglePlayer())then 
	
	
	
	
	function SWEP:UpdateConVarData(deployed)
		
		
		
		local range = GetConVar("multi_physics_gun_range"):GetFloat()
		local bc = GetConVar("multi_physics_gun_beam_count"):GetInt()
		local ho = GetConVar("multi_physics_gun_grab_height_offset"):GetFloat()
		
		local r = GetConVar("multi_physics_gun_color_r"):GetInt()
		local g = GetConVar("multi_physics_gun_color_g"):GetInt()
		local b = GetConVar("multi_physics_gun_color_b"):GetInt()
		local wc = Color(r, g, b, 255)
		local ba = GetConVar("multi_physics_gun_beam_arrangement"):GetInt()
		
		
		
		
		local maxBeamCount = GetConVar("multi_physics_gun_server_beam_count")
		bc = math.min(bc,maxBeamCount:GetInt())
		
		
		self.client_range = range
		self:Set_Range(range)
		self:SetBeamNum(bc)
		self:SetHeightOffset(ho)
		
		self:SetWeaponColor(wc:ToVector())
		
		self:SetBeamArrangement(ba)
		
		
		net.Start("multiphysgun_setup")
		net.WriteBool(deployed)
		net.WriteFloat(range)
		net.WriteInt(bc,8)
		net.WriteFloat(ho)
		net.WriteFloat(GetConVar("multi_physics_gun_grab_alpha"):GetFloat())
		
		
		
		
		
		net.WriteColor(wc)
		
		
		
		
		net.SendToServer()
	end
	
	-- scroll code
	hook.Add("CreateMove", "multiphys_gun_move_override", function(cmd)
		-- check if this is the weapon selected
		local ply = LocalPlayer()
		local convar = GetConVar("multi_physics_gun_movement_scroll_disable")
		if(convar:GetBool() == true) then
			if(ply.GetActiveWeapon && ply:GetActiveWeapon():IsValid() && ply:GetActiveWeapon():GetClass() == "multi_physgun") then
				local wep = ply:GetActiveWeapon()
				if(wep.allow_move_scroll != nil && wep.allow_move_scroll:GetBool() && istable(wep.HeldEnts) && (!table.IsEmpty(wep.HeldEnts) || ply:KeyDown(IN_SPEED))) then
					if(ply:KeyDown(IN_USE)) then
						cmd:ClearMovement()
					end
				end
			end
		end
	end)

end




-- start runs when a new owner is selected
function SWEP:Start()
	self.HasStarted = true
	self:SetHasStarted(true)
	if(CLIENT) then
		self.fire_frame_protect = false
		self.allow_move_scroll = GetConVar("multi_physics_gun_allow_use_move_scroll")
		self.allow_shift_scroll  = GetConVar("multi_physics_gun_allow_run_scroll")
	
		multiphysgun_halo_ents[self:EntIndex()] = self
		
		
		
		if(LocalPlayer() == self:GetOwner()) then
			self:UpdateConVarData(true)
		end
	end
end

function SWEP:SetFiringState(state)
	
	if(self:GetFiringState() != state) then
		net.Start("multiphysgun_fire")
		
		net.WriteBool(state)
		net.SendToServer()
		self.client_firing = state
		
		
		--self:SetFiring(state)
	end
end
function SWEP:GetFiringState() 
	if(CLIENT && LocalPlayer() == self:GetOwner()) then
		return self.client_firing
	else
		return self:GetFiring()
	end
end

local function checkPredicted()
	return (IsFirstTimePredicted()||(game.SinglePlayer() || CLIENT))
end


-- Used to check if an entity should be grabbed or not, this runs on both the server and client
function SWEP:entGrabable(ent)
	
	local udl =	self.use_DefaultLimiters:GetBool()
	local up =	self.use_PhysgunPickup:GetBool()
	local ump = self.use_MultiPhysgunPickup:GetBool()
	
	
	if(IsValid(self:GetOwner()) == false) then return false end
	
	
	if(IsValid(ent) == false) 	then 	return false end
	
	
	if(udl) then
		local c = ent:GetClass()
		
		if(c == "player") 		then	return false end
		if(c == "worldspawn") 	then	return false end
		
		if(ent:GetClass() == "class C_BaseEntity") 	then	return false end
		-- This feels like it could end badly, but it works so far
		if(string.Left(c,5) == "func_") 	then	return false end
	end
	
	if(up && hook.Run("PhysgunPickup",self:GetOwner(),ent) == false) then return false end
	
	if(ump && hook.Run("MultiPhysgunPickup",self:GetOwner(),ent) == false) then return false end
	
	return true
end


-- fire
function SWEP:PrimaryAttack()
	if ( game.SinglePlayer() && SERVER) then self:CallOnClient( "PrimaryAttack" ) end
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	if(CLIENT) then
		
		local ply = self:GetOwner()
		if(ply:KeyDown(IN_ATTACK2) == false && self.can_secondary == true) then
			self.fire_frame_protect = true
			self:SetFiringState(true)
			self:SetNextClientThink(CurTime()+0.1)
		end
	end
end

-- freeze
function SWEP:SecondaryAttack()
	
	
	if ( game.SinglePlayer()) then self:CallOnClient( "SecondaryAttack" ) end
	
	if(self.client_firing == true) then
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	end
	if(CLIENT) then
		if(self.can_secondary == true && !table.IsEmpty(self.HeldEnts)) then
			
			if(checkPredicted()) then
				self.HeldEnts = {}
				net.Start("multiphysgun_freeze")
				net.SendToServer()
			end
			self.client_firing = false
			self.last_secondary = CurTime()
			self.can_secondary = false
		end
	end
end

-- reload
function SWEP:Reload()
	
	
	if(checkPredicted()) then
		if ( game.SinglePlayer()) then self:CallOnClient( "Reload" ) end
		if(CLIENT && self.can_reload == true) then
			
			net.Start("multiphysgun_reload")
			net.SendToServer()
			self.can_reload = false
			self.last_reload = CurTime()
			
			-- do the reload on client as well
			local n_dist = 0
			local num = 0
			-- get the average distance
			for i,h_ent in pairs(self.HeldEnts) do
				if(h_ent != nil) then
					n_dist = n_dist + h_ent.dist
					num = num + 1
				end
			end
			n_dist = n_dist/num
			-- set all distances to the average
			for i,h_ent in pairs(self.HeldEnts) do
				if(h_ent != nil) then
					self.HeldEnts[i].dist = n_dist
				end
			end
			
			
		end
	end
end



-- use beam arrangement to position the beams
-- Copy and paste this to the multiphys_gun_beam entity if you are going to do something with beam formations
function RotateBeamDir(angle, num, maxNum, range, beamArrangement, ho)
	local orginAngle = angle
	if(ho == nil) then ho = 0; end
	if(beamArrangement == 0) then
	
		angle:RotateAroundAxis(angle:Right(),ho)
		angle:RotateAroundAxis(angle:Up(),range-(range*2)*((num)/maxNum))
		
	elseif(beamArrangement == 1) then

		angle:RotateAroundAxis(angle:Up(),-ho)
		angle:RotateAroundAxis(angle:Right(),range-(range*2)*((num)/maxNum))
	
	elseif(beamArrangement == 2) then
	
		angle:RotateAroundAxis(angle:Forward(), ((num)/(maxNum+1))*360)
		angle:RotateAroundAxis(angle:Right(), range+ho)
		
	elseif(beamArrangement == 3) then
		local d = ((num)/(maxNum+1))*360
		local r = math.rad(d+90)
		
		angle:RotateAroundAxis(orginAngle:Right(), (range+ho) * math.sin(r)/2)
		angle:RotateAroundAxis(orginAngle:Up(), (range+ho) * math.cos(r))
	elseif(beamArrangement == 4) then
		local de = ((num)/(maxNum+1))*360
		local ra = math.rad(de)
		
		local h = 1
		local v = 1
		
		local newNum = num/(maxNum+1)
		
		if(newNum <= 0.25) then
			h = 1-(newNum*4)*2
			v = 1
		elseif(newNum <= 0.5) then
		
			h = -1
			v = 1-((newNum-0.25)*4)*2
			
		elseif(newNum <= 0.75) then
		
			h = -1+((newNum-0.5)*4)*2
			v = -1
			
		elseif(newNum <= 1) then
		
			h = 1
			v = -1+((newNum-0.75)*4)*2
			
		end
		
		
		
		angle:RotateAroundAxis(orginAngle:Up(), (range+ho)*h)
		angle:RotateAroundAxis(orginAngle:Right(), (range+ho)*v)
		
		
		
		
	end
	
	return angle
end

-- I HATE HOLSTER
function SWEP:Holster( w )
	if(IsValid(self) && (SERVER || self:GetOwner() == LocalPlayer())) then
		if ( game.SinglePlayer() && SERVER) then self:CallOnClient( "Holster" ) return true end
		if(CLIENT) then
			if(checkPredicted()) then
			
				self:SetFiringState(false)
				if(timer.Exists("multiphysgun timer")) then
					timer.Remove("multiphysgun timer")
				end
			end
			self.can_secondary = false
			self.last_secondary = CurTime()
		end
		
		
		
		return true
	end
end

function SWEP:Deploy()
	if(checkPredicted() && IsValid(self) && SERVER) then
		self:CallOnClient( "ClientDeploy" )
		
		if(self.HasStarted != true) then
			if(!timer.Exists("multiphysgun timer")) then
				timer.Create("multiphysgun timer",0.25,1,function() 
					local filter = RecipientFilter()
					filter:AddAllPlayers()
					filter:RemovePlayer(self:GetOwner())
					net.Start("multiphysgun_client_start")
					net.WriteEntity(self:GetOwner())
					net.Send(filter)
					timer.Remove("multiphysgun timer")
				end)
				timer.Start("multiphysgun timer")
			end
		end
	end
	
	return true
end

if(CLIENT) then
	function SWEP:ClientDeploy()
		self.can_secondary = false
		self.last_secondary = CurTime()
		self.client_firing = false
		if(self:GetFiring()) then
			print("B")
			print(self:GetOwner())
			self:SetFiringState(false)
		end
		self.HeldEnts = {}
	end

end




local last_curtime = 0


local bool_to_int = {[true] = 1, [false] = 0}

-- Moving and picking up entities / releasing and reactivating firing,  only runs for server / client who holds the weapon
function SWEP:Think()
	
	local ply = self:GetOwner()
	
	
	
	local DO_GRAB_RAGDOLL_BONE = playerCanGrabRagdollBones(ply);
	local DO_GRAB_SAME_RAGDOLL = GetConVar("multi_physics_gun_allow_grab_same_ragdoll"):GetBool() && DO_GRAB_RAGDOLL_BONE;
	
	if(!self._initialized) then
		self:Initialize()
	end
	
	if(!checkPredicted() || self.Start == nil) then return end
	--if ( game.SinglePlayer() && SERVER) then self:CallOnClient( "Think" ) end
	
	local use_time = (CurTime()-last_curtime)* 200
	last_curtime = CurTime()
	
	
	local firing = self:GetFiringState()
	
	
	
	if(self.HasStarted != true) then self:Start() end
	
	
	if((SERVER) && !IsValid(self:GetBeamObject()) && IsValid(self:GetOwner())) then
		local ent = ents.Create("multi_physgun_beam")
		self:SetBeamObject(ent)
		ent:SetOwner(self)
		ent:Spawn()
	end
	
	
	if((CLIENT)&&(LocalPlayer() != self:GetOwner()) && LocalPlayer():GetActiveWeapon() == self)then return false end
	
	
	
	
	
	
	
	
	
	
	
	local beamNum = self:GetBeamNum()-1
	local range = self:Get_Range()
	local beamArrangement = self:GetBeamArrangement()
	
	
	
	
	
	if(CLIENT) then
		
		local raw_raw_scroll = input.GetAnalogValue(ANALOG_MOUSE_WHEEL)
		local raw_scroll = raw_raw_scroll
		
		
		if(ply:KeyDown(IN_USE) && self.allow_move_scroll:GetBool()) then 
			raw_scroll = raw_scroll + (((bool_to_int[ply:KeyDown(IN_FORWARD)]-bool_to_int[ply:KeyDown(IN_BACK)])/10) - (input.GetAnalogValue(ANALOG_JOY_Y) / 300000))*use_time
		end
		
		
		if(self.last_scroll == nil) then self.last_scroll = raw_raw_scroll end
		-- scrolling
		local scroll = (raw_scroll-self.last_scroll)
		self.last_scroll = raw_raw_scroll
		if(scroll != 0 && isnumber(scroll)) then
			-- if the player is running
			if(ply:KeyDown(IN_SPEED) && self.allow_shift_scroll:GetBool()) then
				local convar = GetConVar("multi_physics_gun_range")
				
				local scroll_speed = GetConVar("multi_physics_gun_range_scroll_speed"):GetFloat()
				
				
				
				convar:SetFloat(convar:GetFloat()+(scroll*scroll_speed))
				
				self:UpdateConVarData(false)
			else
				local s = ply:GetActiveWeapon()
				local scroll_speed = GetConVar("multi_physics_gun_scroll_speed"):GetFloat()
				local dist_add = scroll*15*scroll_speed
				
				
				net.Start("multiphysgun_scroll")
				net.WriteFloat(dist_add)
				net.SendToServer()
				
				
				
				for b in pairs(s.HeldEnts) do
					h_ent = s.HeldEnts[b]
					if(h_ent != nil && table.IsEmpty(h_ent) == false) then h_ent.dist = math.max( h_ent.dist+dist_add,30) end
				end
				
			end
		end
		
		
		range = self.client_range
		firing = self.client_firing
		-- removes held ents if client_firing is false
		if(firing == false) then
			self.HeldEnts = {}
		end
		
		-- disables firing if the player stops firing
		if((!ply:KeyDown(IN_ATTACK)) && firing == true && self.fire_frame_protect != true) then
			self:SetFiringState(false)
		end
		if(self.fire_frame_protect == true) then self.fire_frame_protect = false end
		
		if(CurTime() > self.last_reload+0.5 && self.can_reload == false) then
			self.can_reload = true
		end
		if(CurTime() > self.last_secondary+0.5 && self.can_secondary == false) then
			self.can_secondary = true
			
			if(ply:KeyDown(IN_ATTACK) && firing == false) then
				self:SetFiringState(true)
			end
			
		end
		
		-- double check client_firing because these things might change it ^
		firing = self.client_firing
		
		-- handles object detection
		if(firing == true && self.can_secondary == true) then
			-- check for grabbed ents
			local did_a_thing = false
			local i = 0
			local j = 0
			-- Set old_HeldEnts to self.HeldEnts
			local old_HeldEnts = {}
			table.CopyFromTo(self.HeldEnts, old_HeldEnts)
			for i = 0, beamNum do
				
				local r = Angle(ply:GetAimVector():Angle())
				
				RotateBeamDir(r, i, beamNum, range, beamArrangement)
				--r:RotateAroundAxis(r:Up(),range-(range*2)*((i)/beamNum))
				
				
				-- tracer for the current beam
				local tr = util.TraceLine( {
				start = ply:EyePos(),
				endpos = ply:EyePos() + r:Forward() * 10000,filter = ply})
				
				
				
				if(self.HeldEnts[i] != nil && !IsValid(self.HeldEnts[i].Entity)) then
					self.HeldEnts[i] = nil
				end
				
				
				if( self:entGrabable(tr.Entity)  and  self.HeldEnts[i] == nil && tr.Entity:GetPhysicsObject() != nil) then
					if(tr.Entity:IsRagdoll() == false) then tr.PhysicsBone = 0 end
					self.HeldEnts[i] = {
						Entity = tr.Entity,  
						dist = ply:EyePos():Distance( tr.Entity:GetPos() ),
						bone = tr.PhysicsBone, 
						color = self:GetWeaponColor():ToColor()
					}
					-- Set the bone to 0 if the player doesn't want to pick up bones / picking up bones is not allowed
					if(!DO_GRAB_RAGDOLL_BONE) then
						self.HeldEnts[i].bone = 0;
					end
					-- Check for multible of the same object being grabbed
					if(!DO_GRAB_SAME_RAGDOLL) then
						for j = 0, beamNum do
							if(self.HeldEnts[j] != nil) then
								if (self.HeldEnts[i].Entity  == self.HeldEnts[j].Entity  and  i != j ) then
									self.HeldEnts[i] = nil
									break
								end
							end
						end
						if(self.HeldEnts[i] != nil   &&  (
						(old_HeldEnts[i] == nil)  ||  
						(self.HeldEnts[i].Entity != old_HeldEnts[i].Entity))) then did_a_thing = true end
						
					else
						for j = 0, beamNum do
							if(self.HeldEnts[j] != nil) then
								if ((self.HeldEnts[i].Entity  == self.HeldEnts[j].Entity and self.HeldEnts[i].bone == self.HeldEnts[j].bone)  and  i != j ) then
									self.HeldEnts[i] = nil
									break
								end
							end
						end
						if(self.HeldEnts[i] != nil   &&  (
						(old_HeldEnts[i] == nil)  ||  
						(self.HeldEnts[i].Entity != old_HeldEnts[i].Entity))) then did_a_thing = true end
					end
					
					
				end
				
			end
			
			-- send info to server
			if(did_a_thing) then
				net.Start("multiphysgun_grabbed_ents")
				
				local i = 0
				for i = 0, beamNum do
					local l = self.HeldEnts[i]
					net.WriteBool(l != nil)
					if(l != nil) then
					
						net.WriteEntity(l.Entity)
						net.WriteFloat(l.dist)
						net.WriteInt(l.bone, 16)
						
					end
				end
				
				net.SendToServer()
			end
			
		end
	end
	
	
	if(SERVER) then
	
	
		-- removes held ents if GetFiring is false
		if(firing == false) then
			self.HeldEnts = {}
		end
		
		-- this does the moving of objects
		if(firing == true && self:GetOwner():KeyDown(IN_ATTACK2) == false)then
			
			local ho = self:GetHeightOffset()
			local max_speed = GetConVar("multi_physics_gun_server_max_speed"):GetInt()
			beamNum = math.min( GetConVar("multi_physics_gun_server_beam_count"):GetInt(), beamNum)
			
			for i = 0, beamNum do
			
				local h_ent = self.HeldEnts[i]
				
				if(h_ent != nil) then
					
					
					if(IsValid(self.HeldEnts[i].Entity)) then
						
						local r = Angle(ply:GetAimVector():Angle())
						
						
						
						r = RotateBeamDir(r, i, beamNum, range, beamArrangement, ho)
						
						
						
						local ent = h_ent.Entity
						local p =  ent:GetPhysicsObjectNum(h_ent.bone)
						
						local target_pos = (ply:EyePos() + (r):Forward() * h_ent.dist)
						
						if(IsValid(p)) then
							local dist = (target_pos - p:GetPos())
							local mt = ent:GetMoveType()
							if(mt != MOVETYPE_STEP && mt != MOVETYPE_PUSH && ent:GetClass() != "prop_effect") then
								
								local dir = dist:GetNormalized()
								local speed = math.min(max_speed/2, dist:Dot(dir) *5)*dir  +  p:GetVelocity()*0.5
								speed = math.max(math.min(max_speed,speed:Dot(dir)),-max_speed)
								
								p:SetVelocity((speed)*dir)
							else
								
								
								local traceData = {
									start = ent:GetPos(),
									endpos = target_pos,
									filter = ent,
									mask = MASK_NPCSOLID_BRUSHONLY
								}
								local traceResult = util.TraceEntity(traceData,ent)
								local p = LerpVector( 0.5, ent:GetPos(), traceResult.HitPos)
								ent:SetPos(p)
								
								
							end
						else
							
							local traceData = {
								start = ent:GetPos(),
								endpos = target_pos,
								filter = ent,
								mask = MASK_NPCSOLID_BRUSHONLY
							}
							local traceResult = util.TraceEntity(traceData,ent)
							ent:SetPos(traceResult.HitPos )
						end
					else
						self.HeldEnts[i] = nil
					end
				end
			end
		end
		
	end
	
	return true
end






function SWEP:OnRemove()
	if(CLIENT) then
		table.remove(multiphysgun_halo_ents,self:EntIndex())
		if(LocalPlayer() == self:GetOwner()) then
			if(self:GetFiring() == true) then
				print("C")
				print(self:GetOwner())
				self:SetFiringState(false)
			end
		end
	end
end

function SWEP:SetupDataTables()
	-- thought SetRange and GetRange were causing issues, it wasn't. But I'm not changing it back now!
	self:NetworkVar( "Float", 0, "_Range" )
	self:NetworkVar( "Float", 1, "HeightOffset" )
	self:NetworkVar( "Float", 2, "GrabAlpha" )
	
	self:NetworkVar( "Int", 0, "BeamNum" )
	self:NetworkVar( "Int", 1, "BeamArrangement" )
	
	self:NetworkVar( "Bool", 0, "Firing" )
	self:NetworkVar( "Bool", 1, "HasStarted" )
	
	self:NetworkVar( "Vector", 0, "WeaponColor" )
	
	self:NetworkVar( "Entity", 0, "BeamObject" )
	
	
	if(CLIENT && LocalPlayer() == self:GetOwner()) then
	
		local r = GetConVar("multi_physics_gun_color_r")
		local g = GetConVar("multi_physics_gun_color_g")
		local b = GetConVar("multi_physics_gun_color_b")
		
		if(r:GetInt() == nil) then
			r:SetInt(255)
		end
		if(g:GetInt() == nil) then
			g:SetInt(255)
		end
		if(b:GetInt() == nil) then
			b:SetInt(255)
		end
		
		self.weapon_color = Color(r:GetInt(), g:GetInt(), b:GetInt(), 255)
	end
	
	if(SERVER) then
		
		
		local range = GetConVar("multi_physics_gun_range")
		local bc = GetConVar("multi_physics_gun_beam_count")
		local gho = GetConVar("multi_physics_gun_grab_height_offset")
		local ga = GetConVar("multi_physics_gun_grab_alpha")
		local ba = GetConVar("multi_physics_gun_beam_arrangement")
		
		if(range != nil) then range = range:GetFloat() else range = 5 end
		if(bc != nil) then bc = bc:GetInt() else bc = 2 end
		if(gho != nil) then gho = gho:GetFloat() else gho = 0 end
		if(ga != nil) then ga = ga:GetFloat() else ga = 1 end
		if(ba != nil) then ba = ba:GetInt() else ba = 1 end
		
		
		
		self:SetFiring(false)
		self:Set_Range(range)
		self:SetBeamNum(bc)
		self:SetHeightOffset(gho)
		self:SetGrabAlpha(ga)
		self:SetWeaponColor(self.weapon_color:ToVector())
		self:SetBeamArrangement(ba)
		self:SetHasStarted(false)
		self:SetBeamObject(nil)
	end
	
	
	
end



function SWEP:OwnerChanged()
	if(IsValid(self:GetOwner())) then
		self.oldOwner = self:GetOwner()
		if(CLIENT) then self:Start() end
		
	elseif(CLIENT) then
		self:ClientOnDrop()
	end
end

if(SERVER) then
	function SWEP:OnDrop() 
		if(self.SetFiring == nil) then return end
		
		local s = self
		s:SetFiring(false)
		
		s.HeldEnts = {}
		
		local filter = RecipientFilter()
		
		filter:AddAllPlayers()
		filter:RemovePlayer(s.oldOwner)
		
		net.Start("multiphysgun_client_grab")
		net.WriteEntity(s.oldOwner)
		
		net.WriteBool(false)
		
		net.Send(filter)
	end
end

function SWEP:ClientOnDrop()
	self.HeldEnts = {}
	self.client_firing = false
end
if(SERVER)  then
	

	-- net receivers
	
	
	
	util.AddNetworkString( "multiphysgun_setup" ) 
	
	util.AddNetworkString( "multiphysgun_scroll" ) 
	util.AddNetworkString( "multiphysgun_freeze" ) 
	util.AddNetworkString( "multiphysgun_fire" ) 
	util.AddNetworkString( "multiphysgun_grabbed_ents" ) 
	util.AddNetworkString( "multiphysgun_reload" ) 
	
	util.AddNetworkString( "multiphysgun_client_grab" ) 
	util.AddNetworkString( "multiphysgun_client_start" )
	util.AddNetworkString( "multiphysgun_client_reject" ) 
	
	
	
	-- convar setup / update
	net.Receive( "multiphysgun_setup", function(_len, ply)
		if ( IsValid( ply ) and ply:IsPlayer() ) then
			local s = ply:GetActiveWeapon()
			if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
			local deployed = net.ReadBool()
			if(deployed) then
				s:SetFiring(false)
				s:SetHasStarted(true)
				s.HeldEnts = {}
				
			end
			s:Set_Range(net.ReadFloat())
			
			local bn = net.ReadInt(8)
			local maxBeamCount = GetConVar("multi_physics_gun_server_beam_count")
			s:SetBeamNum(math.min(bn,maxBeamCount:GetInt()))
			
			s:SetHeightOffset(net.ReadFloat())
			s:SetGrabAlpha(net.ReadFloat())
			
			local col = net.ReadColor()
			s:SetWeaponColor(col:ToVector())
			s:SetBeamArrangement(ply:GetInfo( "multi_physics_gun_beam_arrangement" ) )
			
			
		end
	end)
	
	
	--  grabbed ents
	net.Receive( "multiphysgun_grabbed_ents", function(_len, ply)
		
		if !( IsValid( ply ) and ply:IsPlayer() ) then return end
		
		local DO_UNFREEZE_RAGDOLL = GetConVar("multi_physics_gun_unfreeze_entire_ragdoll"):GetBool();
		local DO_GRAB_RAGDOLL_BONE = playerCanGrabRagdollBones(ply);
		local DO_GRAB_SAME_RAGDOLL = GetConVar("multi_physics_gun_allow_grab_same_ragdoll"):GetBool() && DO_GRAB_RAGDOLL_BONE;
		local s = ply:GetActiveWeapon()
		if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
		
		
		s.HeldEnts = {}
		if(s:GetFiring() == true) then
			local beamNum = s:GetBeamNum()-1
			local i = 0
			for i = 0, beamNum do
				local b = net.ReadBool()
				if(b) then
					
					local h_ent = net.ReadEntity()
					local _dist = net.ReadFloat()
					local _boneId = net.ReadInt(16)
					if(DO_GRAB_RAGDOLL_BONE == false) then _boneId = 0 end
					if(IsValid(h_ent) && s:entGrabable(h_ent)) then 
						s.HeldEnts[i] = {Entity=h_ent, dist = _dist, bone = _boneId }
						
						
						
						-- Check for multible of the same object being grabbed
						if(!DO_GRAB_SAME_RAGDOLL) then
							for j = 0, beamNum do
								if(s.HeldEnts[j] != nil) then
									if (s.HeldEnts[i].Entity  == s.HeldEnts[j].Entity  and  i != j ) then
										s.HeldEnts[i] = nil
										break
									end
								end
							end
						else
							for j = 0, beamNum do
								if(s.HeldEnts[j] != nil) then
									if ((s.HeldEnts[i].Entity  == s.HeldEnts[j].Entity and s.HeldEnts[i].bone == s.HeldEnts[j].bone) and  i != j) then
										s.HeldEnts[i] = nil
										break
									end
								end
							end
						end
						
						-- unfreeze grabbed object
						if(DO_UNFREEZE_RAGDOLL && s.HeldEnts[i] != nil && IsValid(h_ent:GetPhysicsObject())) then
							local p = h_ent:GetPhysicsObject()
							local bone_num = h_ent:GetBoneCount()
							for n = 0, bone_num do
								local phys_bone = h_ent:GetPhysicsObjectNum(h_ent:TranslateBoneToPhysBone(n))
								if(phys_bone != nil) then
									phys_bone:EnableMotion(true)
									phys_bone:Wake()
								end
							end
							p:EnableMotion(true)
						elseif(IsValid(h_ent:GetPhysicsObjectNum(_boneId))) then
							h_ent:GetPhysicsObjectNum(_boneId):EnableMotion(true)
						end
						
						
						
						
					else
						net.Start("multiphysgun_client_reject")
						net.WriteUInt(i,8)
						net.Send(ply)
					end
				end
				
			end
		end
		
		local filter = RecipientFilter()
		filter:AddAllPlayers()
		filter:RemovePlayer(ply)
		net.Start("multiphysgun_client_grab")
		net.WriteEntity(ply)
		
		net.WriteBool(s:GetFiring())
		local beamNum = s:GetBeamNum()-1
		local i = 0
		for i = 0, beamNum do
			local ent = s.HeldEnts[i]
			
			net.WriteBool(ent != nil)
			if(ent != nil) then
				
				net.WriteEntity(ent.Entity)
				net.WriteInt(ent.bone, 10)
				
			end
		end
		
		net.Send(filter)
		
		
	end )
	
	-- scrolled
	net.Receive( "multiphysgun_scroll", function(_len, ply)
		if !( IsValid( ply ) and ply:IsPlayer() ) then return end
		local s = ply:GetActiveWeapon()
		if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
		
		local scroll = net.ReadFloat()
		for b in pairs(s.HeldEnts) do
			h_ent = s.HeldEnts[b]
			if(h_ent != nil) then h_ent.dist = math.max( h_ent.dist+scroll,30) end
		end
		
	end )
	
	-- freezed
	net.Receive( "multiphysgun_freeze", function(_len, ply)
		local DO_GRAB_RAGDOLL_BONE = playerCanGrabRagdollBones(ply);
		if !( IsValid( ply ) and ply:IsPlayer() ) then return end
		local s = ply:GetActiveWeapon()
		if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
		if(!DO_GRAB_RAGDOLL_BONE) then
			for b in pairs(s.HeldEnts) do
				h_ent = s.HeldEnts[b]
				if(h_ent != nil && IsValid(h_ent.Entity) && IsValid(h_ent.Entity:GetPhysicsObject())) then 
					h_ent.Entity:GetPhysicsObject():EnableMotion(false)
				end
			end
		else
			for b in pairs(s.HeldEnts) do
				h_ent = s.HeldEnts[b]
				if(h_ent != nil && IsValid(h_ent.Entity) && IsValid(h_ent.Entity:GetPhysicsObjectNum(h_ent.bone))) then 
					h_ent.Entity:GetPhysicsObjectNum(h_ent.bone):EnableMotion(false)
				end
			end
		end
		s.HeldEnts = {}
		s:SetFiring(false)
		
		local filter = RecipientFilter()
		filter:AddAllPlayers()
		filter:RemovePlayer(ply)
		
		net.Start("multiphysgun_client_grab")
		net.WriteEntity(ply)
		
		net.WriteBool(false)
		
		net.Send(filter)
		
		
	end )
	
	
	-- fire toggle
	net.Receive( "multiphysgun_fire", function(_len, ply)
		if !( IsValid( ply ) and ply:IsPlayer() ) then return end
		local s = ply:GetActiveWeapon()
		if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
		local firing = net.ReadBool()
		if(s:GetFiring() != firing) then
			s:SetFiring(firing)
			
			if(firing == false) then
				s.HeldEnts = {}
				
				local filter = RecipientFilter()
				filter:AddAllPlayers()
				filter:RemovePlayer(ply)
				net.Start("multiphysgun_client_grab")
				net.WriteEntity(ply)
				net.WriteBool(false)
				
				net.Send(filter)
			end
			
		end
		if(firing == true) then
			s:SetAnimation(PLAYER_ATTACK1)
		end
		
		
	end )
	
	
	
	
	
	-- reload normalizes all the distances
	net.Receive( "multiphysgun_reload", function(_len, ply)
		-- get self
		
		if !( IsValid( ply ) and ply:IsPlayer() ) then return end
		local s = ply:GetActiveWeapon()
		if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
		
		local n_dist = 0
		local num = 0
		-- get the average distance
		for i,h_ent in pairs(s.HeldEnts) do
			if(h_ent != nil) then
				n_dist = n_dist + h_ent.dist
				num = num + 1
			end
		end
		n_dist = n_dist/num
		-- set all distances to the average
		for i,h_ent in pairs(s.HeldEnts) do
			if(h_ent != nil) then
				s.HeldEnts[i].dist = n_dist
			end
		end
		
		
		
	end	)
end





-- net receivers for client
net.Receive( "multiphysgun_client_start", function(_len, ply)
	if ( IsValid( ply ) and ply:IsPlayer() ) then
		print( "This shouldn't print, check 'multiphysgun_client_start' net.Receive" )
	elseif(CLIENT) then
	
		local _player = net.ReadEntity()
		if !( IsValid( _player ) and _player:IsPlayer() ) then return end
		local w = _player:GetActiveWeapon()
		if(!IsValid(w) || w:GetClass() != "multi_physgun") then return end
		
		if(w.Start == nil) then return end
		
		if(w.HasStarted != true) then
			w:Start()
		end
	end
end)


net.Receive( "multiphysgun_client_grab", function(_len, ply)
	if ( IsValid( ply ) and ply:IsPlayer() ) then
		print( "This shouldn't print, check 'multiphysgun_client_grab' net.Receive" )
	elseif(CLIENT) then
		
		local _player = net.ReadEntity()
		if !( IsValid( _player ) and _player:IsPlayer() ) then return end
		local s = _player:GetActiveWeapon()
		if(!IsValid(s) || s:GetClass() != "multi_physgun") then return end
		
		
		local firing = net.ReadBool()
		if(s.GetFiring == nil) then return end
		s.HeldEnts = {}
		if(firing == true) then
		
			local beamNum = s:GetBeamNum()-1
			local i = 0
			for i = 0, beamNum do
				
				local b = net.ReadBool()
				if(b == true) then
					
					local h_ent = net.ReadEntity()
					local boneId = net.ReadInt(10)
					if(IsValid(h_ent)) then 
						
						s.HeldEnts[i] = {
							Entity = h_ent, 
							dist = 0 ,
							bone = boneId,
							color = s:GetOwner():GetWeaponColor():ToColor()
						}
						
						
						
						-- check for multible of the same object being grabbed
						/*for j = 0, beamNum do
							if(s.HeldEnts[j] != nil) then
								
								if (s.HeldEnts[i].Entity  == s.HeldEnts[j].Entity  and  i != j ) then
									s.HeldEnts[i] = nil
									break
								end
							end
						end*/
					end
				end
			end
		end
	end
end)


net.Receive( "multiphysgun_client_reject", function(_len, ply)
	if ( IsValid( ply ) and ply:IsPlayer() ) then
		print( "This shouldn't print, check 'multiphysgun_client_reject' net.Receive" )
	elseif(CLIENT) then
		
		local int = net.ReadUInt(8)
		if(IsValid(LocalPlayer())) then
		
			local w = LocalPlayer():GetWeapon("multi_physgun")
			if(IsValid(w)) then
				w.HeldEnts[int] = {}
			end
		end
		
	end
end)



if(CLIENT) then
	
	
	
	-- draw the halos
	hook.Add( "PreDrawHalos", "multiphysgun_halo", function()
		if(GetConVar("multi_physics_gun_draw_halo"):GetBool()) then
			local list = {}
			if(multiphysgun_halo_ents != nil) then
				for entIndex, ent in pairs(multiphysgun_halo_ents) do
					if(IsValid(ent) && ent.HeldEnts != nil) then
						local list = {}
						for i,t in pairs(ent.HeldEnts) do
							list[#list+1] = t.Entity
						end
						local r = math.random(0,1)
						halo.Add(list, ent:GetWeaponColor():ToColor(),1+r,1+r,2)
					end
				end
			end
		end
	end)
	-- block weapon swap while using weapon
	hook.Add("HUDShouldDraw","multiphysgun_scrolling_hud", function(name)
		
		
		if(LocalPlayer().GetActiveWeapon == nil) then return true end
		if(name == "CHudWeaponSelection") then
			
			
			local w = LocalPlayer():GetActiveWeapon()
			if((IsValid(w) && w:GetClass() == "multi_physgun") &&
			((w.HasStarted == true && w:GetFiring() == true && !table.IsEmpty(w.HeldEnts)) || LocalPlayer():KeyDown(IN_SPEED))  ) then
				return false 
			end
			
		end
		
	end)
	
	SWEP.defaultFOV = SWEP.ViewModelFOV
	
	/*
	-- my draw beam function
	local function MyDrawBeam(startPos, endPos, height, textureEnd, color, index)
		
		
		local ply = LocalPlayer();
		
		local DO_GRAB_RAGDOLL_BONE = playerCanGrabRagdollBones(ply);
		
		local up = ply:LocalEyeAngles():Up()
		--local up = RenderCamData.angles:Up()
		
		render.StartBeam(8)
		local i = 0
		
		local upDist = up*height
		
		local t = -RealTime()*2+index*0.5
		for i=0, 9, 1 do
			
			--local pos1 = LerpVector(i/7,startPos,endPos)
			--local pos2 = LerpVector((i+1)/7,startPos,endPos)
			
			--render.DrawQuad(pos1+upDist, pos1-upDist, pos2+upDist, pos2-upDist,color)
			render.AddBeam(LerpVector(i/7,startPos,endPos), height, textureEnd*(i/7)+t, color)
			
		end
		render.EndBeam()
		
		--render.DrawBeam(startPos,endPos,width,height,textureEnd,color)
		
	end
	
	
	-- draw the beams
	function SWEP:DrawBeams()
		local ply = self:GetOwner()
		local beamNum = self:GetBeamNum()-1
		local w = self
		
		local spos = nil
		if ( !ply:ShouldDrawLocalPlayer() && ply == LocalPlayer()) then
			spos =  ply:GetViewModel():GetAttachment( 1 ).Pos
			
		else
			spos = w:GetAttachment(1).Pos
			
		end
		local eang = ply:GetAimVector()
		
		local range = self:Get_Range()
		local grab_alpha = self:GetGrabAlpha()
		
		local colV = w:GetWeaponColor():ToColor()
		
		local colNoFire = Color(colV.r,colV.g,colV.b, 70*colV.a/255)
		local colMiss = Color(colV.r,colV.g,colV.b, 120*colV.a/255)
		local colHit = Color(colV.r,colV.g,colV.b, 200*grab_alpha*colV.a/255)
		local col = Color(colV.r,colV.g,colV.b, 20*colV.a/255)
		local is_firing = w:GetFiring()
		
		
		local beamArrangement = w:GetBeamArrangement();
		
		
		
		
		-- draw the beams
		for i = 0, beamNum do
			col = colNoFire
			if(is_firing) then
				col = colMiss
			end
			local r = eang:Angle()
			
			r = RotateBeamDir(r, i, beamNum, range, beamArrangement)
			
			local tr = util.TraceLine( {
			start = ply:EyePos(),
			endpos = ply:EyePos() + (r):Forward() * 10000,filter = ply})
			
			
			local epos = tr.HitPos
			
			
			
			--if(entGrabable(tr.Entity)) then epos = tr.Entity:GetPos() end
			
			local h_ent = self.HeldEnts[i]
			local max_size = 2
			if(h_ent != nil) then
				if(IsValid(h_ent.Entity))then
					if(DO_GRAB_RAGDOLL_BONE) then
						epos = h_ent.Entity:GetBonePosition(h_ent.bone)
					else
						epos = h_ent.Entity:GetPos()
					end
					col = colHit
					max_size = 1
					render.SetMaterial(beam_mat2)
					MyDrawBeam(spos ,epos,math.random(3,5),1, col, i)
				end
			end
			
			
			render.SetMaterial(beam_mat1)
			MyDrawBeam(spos ,epos,math.random(1,max_size),1, col, i)
			render.SetMaterial(beam_mat2)
			MyDrawBeam(spos ,epos,math.random(1,max_size),1, col, i)
			
			
			
			
			
			local col2 = table.Copy( col )
			-- draw pointers
			
			
			col2.a = math.min(col2.a+120,255)
			size = math.random(3,10)
			render.SetMaterial(beam_glow1)
			render.DrawSprite(epos,size,size,col2)
			size = math.random(1,6)
			render.DrawSprite(epos,size,size,col2)
			
			
			
		end
		
		
		-- draw gun glow
		local size = math.random(20,30)
		local col = Color(colV.r,colV.g,colV.b, 200)
		if(is_firing) then
			col = Color(colV.r,colV.g,colV.b, 255)
		end
		render.SetMaterial(beam_glow1)
		render.DrawSprite(spos,size,size,col)
		size = math.random(20,30)
		render.DrawSprite(spos,size,size,col)
		
	end*/

	
	
	
	function SWEP:GetViewModelPosition(ep,ea)
		--self.ViewModelFOV = LocalPlayer():GetFOV()
		local mul = (self.ViewModelFOV/75) * (self.ViewModelFOV/75)
		local mul2 = (self.ViewModelFOV/75) * (self.ViewModelFOV/75)
		local num = -10
		
		local range = math.max(self:Get_Range()-10,0)/2
		
		
		mul = (self.ViewModelFOV/75)-1
		-- don't touch this, its magic
		ea:RotateAroundAxis(ea:Up(), 0*mul)
		ea:RotateAroundAxis(ea:Forward(), -12*mul)
		ea:RotateAroundAxis(ea:Right(), 0*mul)
		ep = ep + ((-10) * ea:Forward())*mul2
		
		/*
		ep = ep + (0 * ea:Right())*mul2
		ep = ep + (-0 * ea:Up())*mul2
		
		ep = ep + (0 * ea:Right())*mul
		ep = ep + (0 * ea:Up())*mul
		ep = ep - (-0 * ea:Forward())*mul*/
		
		
		return ep,ea
	end
	
	
	function SWEP:ShouldDrawViewModel()
		self.ViewModelFOV = 57
		return true
	end
	
	
	local White = Color(255,255,255,255)
	local player_weapon_color = nil
	function SWEP:PreDrawViewModel(  vm,  w,  ply )
		if(w:GetClass() == "multi_physgun") then
			self.ViewModelFOV = LocalPlayer():GetFOV()
			local spos = w:GetAttachment(1).Pos
			if ( !ply:ShouldDrawLocalPlayer() ) then
				spos = ply:GetViewModel():GetAttachment( 1 ).Pos
			end
			local beam = self:GetBeamObject()
			if(IsValid(beam)) then
				beam:DrawBeams()
			end
		end
		
		vm:SetSkin(1)
		player_weapon_color = self:GetOwner():GetWeaponColor()
		self:GetOwner():SetWeaponColor(self:GetWeaponColor())
		
	end
	-- this seems like its going to end badly, oh well
	function SWEP:PostDrawViewModel(  vm,  w,  ply )
		self:GetOwner():SetWeaponColor(player_weapon_color)
	end
	
	
	
	function SWEP:DrawWorldModel(flags)
		local doColor = (self:GetHasStarted() && IsValid(self:GetOwner()))
		
		if(doColor) then
			player_weapon_color = self:GetOwner():GetWeaponColor()
			self:GetOwner():SetWeaponColor(self:GetWeaponColor())
		end
		
		self:DrawModel(flags)
		
		if(doColor) then
			self:GetOwner():SetWeaponColor(player_weapon_color)
		end
	end
	
	
	
end












-- player init spawn
if(CLIENT) then
	hook.Add( "InitPostEntity", "multiphysgun_get_ready_for_info_hook", function()
		net.Start( "multiphysgun_mod_ready_for_info" )
		net.SendToServer()
	end )
end

if(SERVER) then
	util.AddNetworkString("multiphysgun_mod_ready_for_info")
	
	net.Receive("multiphysgun_mod_ready_for_info", function(_len,ply)
	local _list = ents.FindByClass("multi_physgun")
		
		for i,w in pairs(_list) do
		
			if(IsValid(w) && IsValid(w:GetOwner())) then
				
				-- send start info
				net.Start("multiphysgun_client_start")
				net.WriteEntity(w:GetOwner())
				net.Send(ply)
				
				
				-- send grabbed objects
				net.Start("multiphysgun_client_grab")
				net.WriteEntity(w:GetOwner())
				net.WriteBool(w:GetFiringState())
				if (w:GetFiringState()) then 
					local beamNum = w:GetBeamNum()-1
					local i = 0
					for i = 0, beamNum do
						local ent = w.HeldEnts[i]
						
						net.WriteBool(istable(ent))
						if(istable(ent)) then
							
							net.WriteEntity(ent.Entity)
							net.WriteInt(ent.bone, 10)
							
						end
					end
				end
				net.Send(ply)
				
			end
		end
	end)
	
end






