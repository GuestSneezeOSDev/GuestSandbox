
print("multiphysgun client lua started!")

-- multi physics gun
CreateConVar("multi_physics_gun_range","5", FCVAR_ARCHIVE + FCVAR_UNLOGGED,"The beam distance",0,40)
CreateConVar("multi_physics_gun_range_scroll_speed","1", FCVAR_ARCHIVE ,"The horizontal range modifier scroll speed ('run'+'scroll')")
CreateConVar("multi_physics_gun_scroll_speed","1", FCVAR_ARCHIVE ,"The scroll speed when use 'scroll'",0,30)
CreateConVar("multi_physics_gun_beam_count","2", FCVAR_ARCHIVE + FCVAR_UNLOGGED,"Number of beam the come from the multi physgun",2,15)
CreateConVar("multi_physics_gun_grab_height_offset","0", FCVAR_ARCHIVE + FCVAR_UNLOGGED,"Height offset from the aim area for holding",-30,30)
CreateConVar("multi_physics_gun_grab_alpha","1", FCVAR_ARCHIVE + FCVAR_UNLOGGED,"Alpha multiplier for when an object is grabbed",0,1)
CreateConVar("multi_physics_gun_beam_arrangement","0", FCVAR_ARCHIVE + FCVAR_USERINFO + FCVAR_UNLOGGED,"What way the beams are aranged")
CreateConVar("multi_physics_gun_color_r","255", FCVAR_ARCHIVE+FCVAR_UNLOGGED)
CreateConVar("multi_physics_gun_color_g","51", FCVAR_ARCHIVE+FCVAR_UNLOGGED)
CreateConVar("multi_physics_gun_color_b","0", FCVAR_ARCHIVE+FCVAR_UNLOGGED)
CreateConVar("multi_physics_gun_render_beams","1", FCVAR_ARCHIVE,"Should the beams be rendered")
CreateConVar("multi_physics_gun_render_other_guide_beams","1", FCVAR_ARCHIVE,"Should the guide beams for other players render for you")

CreateConVar("multi_physics_gun_wiggly_beams","0", FCVAR_ARCHIVE,"If on:  Makes the beams wiggly like the normal physgun.")
CreateConVar("multi_physics_gun_draw_halo","1", FCVAR_ARCHIVE,"Should the halos be rendered")
CreateConVar("multi_physics_gun_fade_near","0", FCVAR_ARCHIVE,"Should the beams fade near the gun like the normal physgun.")
CreateConVar("multi_physics_gun_beam_segments","10", FCVAR_ARCHIVE,"How many segments the beams are made of, a lower number might help with performance",1,100)
CreateConVar("multi_physics_gun_movement_scroll_disable","1", FCVAR_ARCHIVE,"If on: Disables movement if you are holding use and, 1) running, or 2) holding any amount of objects")
CreateConVar("multi_physics_gun_allow_use_move_scroll","1", FCVAR_ARCHIVE ,"Allow you to hold use while holding an object to scroll")
CreateConVar("multi_physics_gun_allow_run_scroll","1", FCVAR_ARCHIVE ,"Allows you to adjust the spacing of the beams by shift scrolling")

CreateConVar("multi_physics_gun_server_beam_count","15",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Max number of beams for the multi physgun",2,15)
CreateConVar("multi_physics_gun_server_max_speed","3000",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Max speed for entities being moved by the multi physgun, I recommend keeping this at the default, the higher the value the higher the chance of things clipping through walls")
CreateConVar("multi_physics_gun_server_use_PhysgunPickup","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Enables if the PhysgunPickup hook should be used for grab detection",0,1)
CreateConVar("multi_physics_gun_server_use_MultiPhysgunPickup","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Enables if the MultiPhysgunPickup hook should be used for grab detection",0,1)
CreateConVar("multi_physics_gun_server_use_DefaultLimiters","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Enables if the default limiters put in place should be used for grab detection",0,1)
CreateConVar("multi_physics_gun_server_allow_grab_ragdoll_bone","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"If ragdoll bone should be picked up instead of their centers",0,1)

CreateConVar("multi_physics_gun_can_grab_ragdoll_bone", "1", FCVAR_USERINFO+FCVAR_ARCHIVE,"If ragdoll bone should be picked up instead of their centers",0,1)
CreateConVar("multi_physics_gun_allow_grab_same_ragdoll", "0", FCVAR_USERINFO+FCVAR_ARCHIVE,"If ragdolls can be picked up by 2 or more beams from one person",0,1)
CreateConVar("multi_physics_gun_unfreeze_entire_ragdoll"," 1", FCVAR_USERINFO+FCVAR_ARCHIVE,"If the multi physgun should unfreeze the entire ragdoll when 1 beam hits it",0,1)



-- 28 convars
-- 22 client convars
-- 6 server convar


-- multi phys gun options
hook.Add("PopulateToolMenu","Multi_physgun_options", function()
	spawnmenu.AddToolMenuOption( "Options", "Multi Physgun", "codekraken_multi_physgun_options","Client Settings","","",function(panel)
		panel:ClearControls()
		
		panel:ControlHelp("Client Settings")
		--panel:Help("Some of these settings require requiping the weapon to work");
		panel:NumSlider( "Beam Spacing", "multi_physics_gun_range" ,0,30,1)
		panel:NumSlider( "Beam Count", "multi_physics_gun_beam_count" ,2,15,0)
		
		panel:NumSlider( "Spacing Scroll Speed","multi_physics_gun_range_scroll_speed" ,0,40,1)
		panel:NumSlider( "Scroll Speed","multi_physics_gun_scroll_speed" ,0,10,1)
		
		
		-- local BeamCount = vgui.Create( "DNumSlider", panel)
		-- BeamCount:SetMinMax(2,15)
		-- BeamCount:SetConVar("multi_physics_gun_beam_count")
		-- BeamCount:SetDecimals(0)
		-- BeamCount:SetText( "Beam Count" )
		-- BeamCount:DockMargin(8,8,8,8)
		-- BeamCount:Dock( LEFT )
		-- local BeamCountWang = vgui.Create( "DNumberWang", panel)
		-- BeamCountWang:SetMinMax(2,15)
		-- BeamCountWang:SetConVar("multi_physics_gun_beam_count")
		-- BeamCountWang:SetDecimals(0)
		
		
		--panel:AddItem(BeamCount, BeamCountWang)
		
		
		panel:NumSlider( "Pickup Offset", "multi_physics_gun_grab_height_offset" ,-30,30,1)
		panel:NumSlider( "Grab Alpha Multiplier", "multi_physics_gun_grab_alpha" ,0,1,1)
		
		panel:NumSlider( "Beam Arrangement", "multi_physics_gun_beam_arrangement", 0, 4, false)
		
		
		
		
		panel:CheckBox("Can Grab Ragdoll Bones", "multi_physics_gun_can_grab_ragdoll_bone")
		panel:CheckBox("Grab Mutlible Bones On A Single Ragdoll", "multi_physics_gun_allow_grab_same_ragdoll")
		panel:CheckBox("Grabbing Unfreezes Entire Ragdoll", "multi_physics_gun_unfreeze_entire_ragdoll")
		
		-- Color select
		panel:Help("Weapon Color")
		
		local colorSelect = vgui.Create( "DColorMixer", panel)
		
		panel:AddItem(colorSelect)
		
		colorSelect:SetAlphaBar(false)
		colorSelect:SetPalette(true) 
		colorSelect:SetWangs(true) 
		
		
		
		
		local r = GetConVar("multi_physics_gun_color_r")
		local g = GetConVar("multi_physics_gun_color_g")
		local b = GetConVar("multi_physics_gun_color_b")
		colorSelect:SetColor( Color( r:GetInt(), g:GetInt(), b:GetInt() ) )
		
		colorSelect:SetConVarR("multi_physics_gun_color_r")
		colorSelect:SetConVarG("multi_physics_gun_color_g")
		colorSelect:SetConVarB("multi_physics_gun_color_b")
		
		
		local submitButton = vgui.Create( "DButton", panel )
		--submitButton:SetPos( 20, 600 )
		
		panel:AddItem(submitButton)
		submitButton:SetText( "Submit Changes" )	
		submitButton:SetSize( 250, 50 )
		
		submitButton.DoClick = function()
			if(IsValid(LocalPlayer())) then
					
					local w = LocalPlayer():GetActiveWeapon()
					
					if(IsValid(w) && w:GetClass() == "multi_physgun") then
						w:UpdateConVarData(true)
					end
					
			end
		end
		
		
		
		---------------- RENDER SETTING ------------------------
		panel:ControlHelp("\nRendering Settings")
		
		
		panel:CheckBox("Draw Beams", "multi_physics_gun_render_beams")
		panel:CheckBox("Draw Other Player's Guide Beams", "multi_physics_gun_render_other_guide_beams")
		
		panel:CheckBox("Draw Halos", "multi_physics_gun_draw_halo")
		panel:CheckBox("Bendy Beams", "multi_physics_gun_wiggly_beams")
		panel:CheckBox("Fade Near", "multi_physics_gun_fade_near")
		panel:NumSlider("Beam Segments", "multi_physics_gun_beam_segments", 1, 20, false)
	end)
	
	spawnmenu.AddToolMenuOption( "Options", "Multi Physgun", "codekraken_multi_physgun_options_server","Server Settings","","",function(panel)
		panel:ClearControls()
		panel:ControlHelp("Server Settings")
		
		panel:NumSlider( "Max Beam Count", "multi_physics_gun_server_beam_count" ,2,15,0)
		panel:NumSlider( "Max Pull Speed", "multi_physics_gun_server_max_speed" ,100,10000,0)
		
		panel:CheckBox("Allow Grabbing Bones", "multi_physics_gun_server_allow_grab_ragdoll_bone")
		
		
	end)

end)



