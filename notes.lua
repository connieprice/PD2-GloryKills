
--[[
TODO:

- fix 3p unit refusing to be hidden immediately after spawning with player
- eyeAim bone doesn't reflect what's in blender?
- incorrect 3p unit for the chosen player character



forward-design to expect for enemy type specific animations:
- bulldozer
- cloaker



playbonk's anim notes:	
	execution_slap first slap of the cop weapon to the side
	execution_punch punch
	execution_grab grabbing the cop's head
	execution_kill headbutt
	death presumed ragdoll timing so at this trigger i thought itd be ok to turn the cop into a ragdoll
	also the player animation is 46 frames long
	the cop animation is 71

check if custom state syncing will crash unmodded clients

--]]

--managers.player:local_player():movement():current_state()._fwd_ray.unit:set_slot(0)

BeardLib:AddUpdater("asdfljaksdljkf",function(t,dt)
	if alive(GloryKills.unit) then
		local obj = GloryKills.unit:get_object(Idstring("eyeAim"))
		if obj then
			Draw:brush(Color.red:with_alpha(0.5)):sphere(obj:position(),10)
			
			local rot = obj:rotation()
			local fwd = rot:z()
			Draw:brush(Color.blue:with_alpha(0.5)):cylinder(obj:position(),obj:position()+(fwd * 100),3)
		end
	end
end)

local function test()
	local mvec_1 = Vector3()
	local mvec_2 = Vector3()
	local t = Application:time()
	local input = {}
	local self = managers.player:local_player():movement():current_state()
	local col_ray = self._fwd_ray
	local hit_unit = col_ray and col_ray.unit
	if alive(hit_unit) then
		-- account for raycast hitting a shield
		if hit_unit:in_slot(8) then
			local hit_parent = hit_unit:parent()
			if alive(hit_parent) then
				hit_unit = hit_parent
			end
		end
		
		if managers.enemy:is_enemy(hit_unit) and not managers.enemy:is_civilian(hit_unit) then
			
			local hit_base = hit_unit:base()
			
			local dmg_ext = hit_unit:character_damage()
			local my_mov_ext = self._ext_movement
			local my_pos = my_mov_ext:m_pos()
			local my_rot = self._ext_camera:rotation()
			local look_mov = Rotation(GloryKills.unit:movement():m_rot():yaw(),0,0)
			local hit_mov_ext = hit_unit:movement()
			local attack_data = {
				variant = "execution",
				damage = dmg_ext._HEALTH_INIT or 1000000,
				damage_effect = 0,
				attacker_unit = self._unit,
				col_ray = col_ray,
				name_id = melee_entry,
				charge_lerp_value = 0
			}
			
			-- detect hits from behind
			mvector3.set(mvec_1, hit_mov_ext:m_pos()) -- prev pos (before moving the enemy)
			mvector3.subtract(mvec_1, my_pos)
			mvector3.normalize(mvec_1)
			mvector3.set(mvec_2, hit_mov_ext:m_rot():y())

			local from_behind = mvector3.dot(mvec_1, mvec_2) >= 0
			local execution_variant
			-- set animation variant
			if from_behind then
				--log("From behind")
				execution_variant = "var2"
			else
				--log("From front")
				execution_variant = "var1"
			end
			-- i either do a minor sin and set the flag this way (as a member to the movement extension)
			-- or i do an worse sin and overwrite the whole of CopMovement:damage_clbk() just to pass the variant data properly, which i hate
			hit_mov_ext._execution_variant = execution_variant
			-- this does set the flag before we technically know that the execution has succeeded
			-- but as long as that var is recalculated before each attempt it should be fine
			
			-- WOWEE look at the time again! it's time for CODE CRIMES!
			local check_medic_heal = dmg_ext.check_medic_heal
			dmg_ext.check_medic_heal = function(this) return false end -- disable the medic heal by redefining the method solely on this instance
			-- ... it was this, redefine the damage_melee function, or define a whole NEW damage function. cursed any way you cut it
			
			local result = dmg_ext:damage_melee(attack_data)
			
			dmg_ext.check_medic_heal = check_medic_heal -- put that method back where it came from or so help me!
			
			if not result then
				log("Hit ineffective")
				return
			end
			
			if result.type == "death" then
				--GloryKills:Print("Successful proc. Entering execution state")
				if GloryKills.unit then
					GloryKills.unit:set_position(hit_mov_ext:m_pos())
					GloryKills.unit:set_rotation(look_mov)
					
					local redir = GloryKills.unit:movement():play_redirect("execution")
					GloryKills.unit:movement()._machine:set_parameter(redir, execution_variant, 1)
				end
				
				result.variant = "execution"
				--result.execution_variant = variant


				-- rotate cop to face player
				-- set position to cop position
				-- rotate player to face cop
				-- after anim, move player back to orig pos
				hit_mov_ext:set_rotation(look_mov)
				--hit_mov_ext:set_position(mvector3.copy(my_pos))
				self._state_data.execution_unit = hit_unit
				
				my_mov_ext:change_state("execution")
				
				
			-- disable the melee that would otherwise occur on this frame
				self._state_data.melee_attack_wanted = nil
				input.btn_melee_press = nil
				input.btn_melee_release = nil
				--input.btn_meleet_state = nil -- this seems like an edge case i don't need to worry about
				return
			else
				log("GloryKills: uhh... this is embarrassing. the execution failed to kill the enemy.")
			end
		end
	end
end


	
	
	
	
