include("shared.lua")


-- Copy and paste this from multiphys gun if you are going to do something with beam formations
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



local beam_mat1 = Material( "sprites/physbeam")
local beam_mat2 = Material( "sprites/physbeama")
local beam_mat3 = Material( "sprites/physgbeamb")
local beam_glow1 = Material( "sprites/physg_glow1")
local beam_glow2 = Material( "sprites/physg_glow2")

-- my draw beam function
local function MyDrawBeam(startPos, endPos, height, textureEnd, color, index, pull_dir, fade_near, length)
	
	
	local ply = LocalPlayer()
	local up = ply:LocalEyeAngles():Up()
	
	render.StartBeam(length+1)
	local i = 0
	
	local upDist = up*height
	
	local t = -RealTime()*2+index*0.5
	
	
	local dl = math.min(length)
	
	
	local spos = startPos
	
	local epos = LerpVector(1/dl,startPos,endPos)
	
	if(fade_near) then
		render.AddBeam(spos, height, (textureEnd*(i/dl)+t) , color_black)
		
	else
		render.AddBeam(spos, height, (textureEnd*(i/dl)+t) , color)
	end
	
	for i=1, length, 1 do
	
		
		if(pull_dir != -1) then
			local d = math.pow( ((i) / (dl)),2)
			epos = LerpVector(d,startPos, startPos+pull_dir)
			spos = LerpVector(d,startPos,endPos)
			epos = LerpVector(i/dl,epos,spos)
		else
			epos = LerpVector(i/dl,startPos,endPos)
		end
		
		
		
		render.AddBeam(epos, height, (textureEnd*(i/dl)+t) , color)
		
	end
	render.EndBeam()
	
	
end





-- draw the beams
function ENT:DrawBeams()
	if(self.should_render_beams:GetBool() == false) then return false end
	
	local DO_GRAB_RAGDOLL_BONE = GetConVar("multi_physics_gun_server_allow_grab_ragdoll_bone"):GetBool();
	local DRAW_OTHER_PLAYER_GUIDE_BEAMS = GetConVar("multi_physics_gun_render_other_guide_beams"):GetBool();
	
	local w = self:GetOwner()
	local ply = w:GetOwner()
	if(w:GetFiringState() == false && ply != LocalPlayer() && !DRAW_OTHER_PLAYER_GUIDE_BEAMS) then return false end
	
	local beamNum = w:GetBeamNum()-1
	
	local spos = nil
	
	if ( !ply:ShouldDrawLocalPlayer() && ply == LocalPlayer()) then
		spos =  ply:GetViewModel():GetAttachment( 1 ).Pos
	else
		spos = w:GetAttachment(1).Pos
	end

	local eang = ply:GetAimVector()
	
	local range = w:Get_Range()
	local grab_alpha = w:GetGrabAlpha()
	
	local colV = w:GetWeaponColor():ToColor()
	
	local colNoFire = Color(colV.r,colV.g,colV.b, 70*colV.a/255)
	local colMiss = Color(colV.r,colV.g,colV.b, 120*colV.a/255)
	local colHit = Color(colV.r,colV.g,colV.b, 200*grab_alpha*colV.a/255)
	local col = Color(colV.r,colV.g,colV.b, 20*colV.a/255)
	
	
	local is_firing = w:GetFiringState()
	if(ply == LocalPlayer()) then
		range = w.client_range
	end
	
	local beamArrangement = w:GetBeamArrangement()
	
	
	local wiggle = self.should_beams_wiggle:GetBool()
	local fade_near = self.should_fade_near:GetBool()
	local beam_length = self.beam_length:GetInt()
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
		
		
		
		
		local h_ent = w.HeldEnts[i]
		local max_size = 2
		local pull_dir = -1
		if(h_ent != nil) then
			if(IsValid(h_ent.Entity))then
				local ent = h_ent.Entity
				if(DO_GRAB_RAGDOLL_BONE) then
					epos = ent:GetBonePosition(ent:TranslatePhysBoneToBone(h_ent.bone))
				else
					epos = ent:GetPos()
				end
				if(epos == nil) then epos = ent:GetPos() end
				
				col = colHit
				max_size = 1
				render.SetMaterial(beam_mat2)
				if(wiggle == true) then
					pull_dir = (r):Forward()*h_ent.dist
				end
				
				MyDrawBeam(spos ,epos,math.random(3,5),1, col, i, pull_dir, fade_near, beam_length)
				
			end
		end
		
		
		render.SetMaterial(beam_mat1)
		MyDrawBeam(spos ,epos,math.random(1,max_size),1, col, i, pull_dir, fade_near, beam_length)
		render.SetMaterial(beam_mat2)
		MyDrawBeam(spos ,epos,math.random(1,max_size),1, col, i, pull_dir, fade_near, beam_length)
		
		--render.DrawWireframeSphere(epos,3,5,5)
		
		
		
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
	
end



function ENT:Think()
	if(self.should_render_beams:GetBool() == false) then return false end
	local w = self:GetOwner()
	if(!IsValid(w)) then  return false  end
	local ply = w:GetOwner()
	
	
	local DRAW_OTHER_PLAYER_GUIDE_BEAMS = GetConVar("multi_physics_gun_render_other_guide_beams"):GetBool();
	if(w:GetFiringState() == false && ply != LocalPlayer() && !DRAW_OTHER_PLAYER_GUIDE_BEAMS) then return false end
	
	
	if(!IsValid(self:GetOwner())) then
		return false
	end
	
	
	local i = 0
	local beamNum = w:GetBeamNum()-1
	local range = w:Get_Range()
	local beamArrangement = w:GetBeamArrangement()
	if(IsValid(ply)) then
		local mins = Vector(math.huge,math.huge,math.huge)
		local maxs = Vector(-math.huge,-math.huge,-math.huge)
		
		for i = 0, beamNum do
			
			local r = Angle(ply:GetAimVector():Angle())
			
			RotateBeamDir(r, i, beamNum, range, beamArrangement)
			
			local tr = util.TraceLine( {
				start = ply:EyePos(),
				endpos = ply:EyePos() + r:Forward() * 10000,filter = ply})
			
			mins = Vector(math.min(tr.HitPos.x, mins.x),math.min(tr.HitPos.y, mins.y),math.min(tr.HitPos.z, mins.z))
			maxs = Vector(math.max(tr.HitPos.x, maxs.x),math.max(tr.HitPos.y, maxs.y),math.max(tr.HitPos.z, maxs.z))
		end
		local wPos = w:GetOwner():EyePos()
		mins = Vector(math.min(wPos.x, mins.x),math.min(wPos.y, mins.y),math.min(wPos.z, mins.z))
		maxs = Vector(math.max(wPos.x, maxs.x),math.max(wPos.y, maxs.y),math.max(wPos.z, maxs.z))
		--print(maxs-mins)
		self:SetRenderBoundsWS(mins,maxs,Vector(32,32,32))
	end
	
end

function ENT:Initialize()
	self:SetRenderMode(RENDERMODE_GLOW)
	self:DrawShadow(false)
	self.should_render_beams = GetConVar("multi_physics_gun_render_beams")
	self.should_beams_wiggle = GetConVar("multi_physics_gun_wiggly_beams")
	self.should_fade_near = GetConVar("multi_physics_gun_fade_near")
	self.beam_length = GetConVar("multi_physics_gun_beam_segments")
	
end



function ENT:Draw(flags)
	local w = self:GetOwner()
	
	
	if((IsValid(w) && IsValid(w:GetOwner()) && w:GetClass() == "multi_physgun")) then
		local ply = w:GetOwner()
		if !( !ply:ShouldDrawLocalPlayer() && ply == LocalPlayer()) then
			self:DrawBeams()
		end
	end
	
end