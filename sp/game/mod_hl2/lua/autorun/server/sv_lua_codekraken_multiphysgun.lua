CreateConVar("multi_physics_gun_server_beam_count","15",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Max number of beams for the multi physgun",2,15)
CreateConVar("multi_physics_gun_server_max_speed","3000",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Max speed for entities being moved by the multi physgun, I recommend keeping this at the default, the higher the value the higher the chance of things clipping through walls")

CreateConVar("multi_physics_gun_server_use_PhysgunPickup","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Enables if the PhysgunPickup hook should be used for grab detection",0,1)
CreateConVar("multi_physics_gun_server_use_MultiPhysgunPickup","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Enables if the MultiPhysgunPickup hook should be used for grab detection",0,1)
CreateConVar("multi_physics_gun_server_use_DefaultLimiters","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"Enables if the default limiters put in place should be used for grab detection",0,1)


CreateConVar("multi_physics_gun_server_allow_grab_ragdoll_bone","1",FCVAR_REPLICATED+FCVAR_ARCHIVE,"If ragdoll bone should be picked up instead of their centers",0,1)