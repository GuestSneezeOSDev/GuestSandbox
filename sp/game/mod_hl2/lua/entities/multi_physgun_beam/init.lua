AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetRenderMode(RENDERMODE_GLOW)
	self:DrawShadow(false)
end


function ENT:Think()
	local w = self:GetOwner()
	
	
	if(!IsValid(w) || !IsValid(w:GetOwner())) then
		self:Remove()
		return false
	end
	
	if(w:GetOwner():GetActiveWeapon():GetClass() != "multi_physgun") then
		self:Remove()
		return false
	end
	self:SetPos(w:GetPos())
end