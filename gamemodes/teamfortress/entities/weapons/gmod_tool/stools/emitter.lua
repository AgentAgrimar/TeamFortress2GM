
TOOL.Category		= "Construction"
TOOL.Name			= "#tool.emitter.name"

TOOL.ClientConVar[ "key" ] 			= "51"
TOOL.ClientConVar[ "delay" ] 		= "1"
TOOL.ClientConVar[ "toggle" ] 		= "1"
TOOL.ClientConVar[ "starton" ] 		= "0"
TOOL.ClientConVar[ "effect" ] 		= "sparks"
TOOL.ClientConVar[ "scale" ] 		= "1"

cleanup.Register( "emitters" )

function TOOL:LeftClick( trace, worldweld )

	worldweld = worldweld or false

	if ( trace.Entity && trace.Entity:IsPlayer() ) then return false end
	
	-- If there's no physics object then we can't constraint it!
	if ( SERVER && !util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) ) then return false end
	
	if ( CLIENT ) then return true end
	
	local ply = self:GetOwner()
	
	local key	 		= self:GetClientNumber( "key" )
	local delay 		= self:GetClientNumber( "delay" )
	local toggle 		= self:GetClientNumber( "toggle" ) == 1
	local starton 		= self:GetClientNumber( "starton" ) == 1
	local effect	 	= self:GetClientInfo( "effect" )
	local scale	 		= math.Clamp( self:GetClientNumber( "scale" ), 0.1, 6 )

	-- Safe(ish) limits
	delay = math.Clamp( delay, 0.05, 20 )
	
	-- We shot an existing emitter - just change its values
	if ( trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_emitter" && trace.Entity.pl == ply ) then

		trace.Entity:SetEffect( effect )
		trace.Entity:SetDelay( delay )
		trace.Entity:SetToggle( toggle )
		trace.Entity:SetScale( scale )
		
		numpad.Remove( trace.Entity.NumDown )
		numpad.Remove( trace.Entity.NumUp )
		
		trace.Entity.NumDown = numpad.OnDown( ply, key, "Emitter_On", trace.Entity )
		trace.Entity.NumUp = numpad.OnUp( ply, key, "Emitter_Off", trace.Entity )

		trace.Entity.key = key
	
		return true
		
	end
	
	if ( !self:GetSWEP():CheckLimit( "emitters" ) ) then return false end
	
	local Pos = trace.HitPos
	if ( trace.Entity != NULL && ( !trace.Entity:IsWorld() || worldweld ) ) then else

		Pos = Pos + trace.HitNormal
	
	end
	
	local Ang = trace.HitNormal:Angle()
	Ang:RotateAroundAxis( trace.HitNormal, 0 )

	local emitter = MakeEmitter( ply, key, delay, toggle, effect, starton, nil, nil, nil, nil, { Pos = Pos, Angle = Ang }, scale )
		
	local weld
	
	-- Don't weld to world
	if ( trace.Entity != NULL && ( !trace.Entity:IsWorld() || worldweld ) ) then
	
		weld = constraint.Weld( emitter, trace.Entity, 0, trace.PhysicsBone, 0, true, true )
		
		-- >:(
		emitter:GetPhysicsObject():EnableCollisions( false )
		emitter.nocollide = true
		
	end
	
	undo.Create( "Emitter" )
		undo.AddEntity( emitter )
		undo.AddEntity( weld )
		undo.SetPlayer( ply )
	undo.Finish()
	
	return true

end

function TOOL:RightClick( trace )
	return self:LeftClick( trace, true )
end

if ( SERVER ) then

	function MakeEmitter( ply, key, delay, toggle, effect, starton, Vel, aVel, frozen, nocollide, Data, scale )
	
		if ( IsValid( ply ) && !ply:CheckLimit( "emitters" ) ) then return nil end
	
		local emitter = ents.Create( "gmod_emitter" )
		if ( !emitter:IsValid() ) then return false end

		duplicator.DoGeneric( emitter, Data )
		emitter:SetEffect( effect )
		emitter:SetPlayer( ply )
		emitter:SetDelay( delay )
		emitter:SetToggle( toggle )
		emitter:SetOn( starton )
		emitter:SetScale( scale or 1 )

		emitter:Spawn()
		
		DoPropSpawnedEffect( emitter )

		emitter.NumDown = numpad.OnDown( ply, key, "Emitter_On", emitter )
		emitter.NumUp = numpad.OnUp( ply, key, "Emitter_Off", emitter )

		if ( nocollide == true ) then emitter:GetPhysicsObject():EnableCollisions( false ) end

		local ttable = 
		{
			key			= key,
			delay 		= delay,
			toggle 		= toggle,
			effect 		= effect,
			pl			= ply,
			nocollide 	= nocollide,
			starton		= starton,
			scale		= scale
		}

		table.Merge( emitter:GetTable(), ttable )
		
		if ( IsValid( ply ) ) then
			ply:AddCount( "emitters", emitter )
			ply:AddCleanup( "emitters", emitter )
		end

		return emitter
		
	end
	
	duplicator.RegisterEntityClass( "gmod_emitter", MakeEmitter, "key", "delay", "toggle", "effect", "starton", "Vel", "aVel", "frozen", "nocollide", "Data", "scale" )

end

function TOOL:UpdateGhostEmitter( ent, player )

	if ( !IsValid( ent ) ) then return end
	
	local tr	= util.GetPlayerTrace( player )
	local trace	= util.TraceLine( tr )
	if ( !trace.Hit ) then return end
	
	if ( trace.Entity:IsPlayer() || trace.Entity:GetClass() == "gmod_emitter" ) then
	
		ent:SetNoDraw( true )
		return
		
	end
	
	ent:SetPos( trace.HitPos )
	ent:SetAngles( trace.HitNormal:Angle() )
	
	ent:SetNoDraw( false )
	
end

function TOOL:Think()

	if ( !IsValid( self.GhostEntity ) || self.GhostEntity:GetModel() != /*self:GetClientInfo( "model" )*/ "models/props_lab/tpplug.mdl" ) then
		self:MakeGhostEntity( "models/props_lab/tpplug.mdl", Vector( 0, 0, 0 ), Angle( 0, 0, 0 ) )
	end
	
	self:UpdateGhostEmitter( self.GhostEntity, self:GetOwner() )
	
end

-- NOTE!! The . instead of : here - there is no 'self' argument!!
-- This is just a function on the table - not a member function!

function TOOL.BuildCPanel( CPanel )

	-- HEADER
	CPanel:AddControl( "Header", { Description	= "#tool.emitter.desc" } )
	
	-- PRESETS
	local params = { Label = "#tool.presets", MenuButton = 1, Folder = "emitter", Options = {}, CVars = {} }
			
		params.Options.default = {
			emitter_key			= 		3,
			emitter_delay		=		0.1,
			emitter_toggle		=		1,
			emitter_starton		=		1,
			emitter_scale		=		1,
			emitter_effect		=		"sparks" }
			
		table.insert( params.CVars, "emitter_key" )
		table.insert( params.CVars, "emitter_delay" )
		table.insert( params.CVars, "emitter_toggle" )
		table.insert( params.CVars, "emitter_starton" )
		table.insert( params.CVars, "emitter_effect" )
		table.insert( params.CVars, "emitter_scale" )
		
	CPanel:AddControl( "ComboBox", params )
	
	
	-- KEY
	CPanel:AddControl( "Numpad", { Label = "#tool.emitter.key", Command = "emitter_key", ButtonSize = 22 } )
	
	-- DELAY
	CPanel:AddControl( "Slider",  { Label	= "#tool.emitter.delay",
									Type	= "Float",
									Min		= 0.01,
									Max		= 0.5,
									Command = "emitter_delay" }	 )
	
	CPanel:AddControl( "Slider",  { Label	= "#tool.emitter.scale",
									Type	= "Float",
									Min		= 0.1,
									Max		= 6,
									Command = "emitter_scale",
									Help 	= true } )
	
	-- TOGGLE
	CPanel:AddControl( "Checkbox", { Label = "#tool.emitter.toggle", Command = "emitter_toggle" } )
	
	-- START ON
	CPanel:AddControl( "Checkbox", { Label = "#tool.emitter.starton", Command = "emitter_starton" } )

	-- SELECT
	local matselect = vgui.Create( "MatSelect", CPanel )
	matselect:SetItemWidth( 64 )
	matselect:SetItemHeight( 64 )
	matselect:SetAutoHeight( true )
	matselect:SetConVar( "emitter_effect" )
		
	Derma_Hook( matselect.List, "Paint", "Paint", "Panel" )
	
	local list = list.Get( "EffectType" )		
	for k, v in pairs( list ) do
		matselect:AddMaterialEx( v.print, v.material, k, { emitter_effect = k } )
	end	

	CPanel:AddItem( matselect )	

end
