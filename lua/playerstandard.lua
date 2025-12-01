if _G.IS_VR then
	return
end

local DEBUG_DRAW_ENABLED = false
-- visualize raycast line-of-sight checks

PlayerStandard.ANIM_STATES.standard.execution = Idstring("execution")
--memory optimization; temp vector allocations to be used for various calculations
local mvec_1 = Vector3()
local mvec_2 = Vector3()

local melee_vars = {
	"player_melee",
	"player_melee_var2"
}




Hooks:OverrideFunction(PlayerStandard,"_do_melee_damage",function(self, t, bayonet_melee, melee_hit_ray, melee_entry, hand_id)
	melee_entry = melee_entry or managers.blackmarket:equipped_melee_weapon()
	local instant_hit = tweak_data.blackmarket.melee_weapons[melee_entry].instant
	local melee_damage_delay = tweak_data.blackmarket.melee_weapons[melee_entry].melee_damage_delay or 0
	local charge_lerp_value = instant_hit and 0 or self:_get_melee_charge_lerp_value(t, melee_damage_delay)

	self._ext_camera:play_shaker(melee_vars[math.random(#melee_vars)], math.max(0.3, charge_lerp_value))

	local sphere_cast_radius = 20
	local col_ray = nil

	if melee_hit_ray then
		col_ray = melee_hit_ray ~= true and melee_hit_ray or nil
	else
		col_ray = self:_calc_melee_hit_ray(t, sphere_cast_radius)
	end
	
	if col_ray and alive(col_ray.unit) then
		local damage, damage_effect = managers.blackmarket:equipped_melee_weapon_damage_info(charge_lerp_value)		
		local damage_effect_mul = math.max(managers.player:upgrade_value("player", "melee_knockdown_mul", 1), managers.player:upgrade_value(self._equipped_unit:base():weapon_tweak_data().categories and self._equipped_unit:base():weapon_tweak_data().categories[1], "melee_knockdown_mul", 1))
		damage = damage * managers.player:get_melee_dmg_multiplier()
		damage_effect = damage_effect * damage_effect_mul
		col_ray.sphere_cast_radius = sphere_cast_radius
		local hit_unit = col_ray.unit

		if hit_unit:character_damage() then
			if bayonet_melee then
				self._unit:sound():play("fairbairn_hit_body", nil, false)
			else
				local hit_sfx = "hit_body"

				if hit_unit:character_damage() and hit_unit:character_damage().melee_hit_sfx then
					hit_sfx = hit_unit:character_damage():melee_hit_sfx()
				end

				self:_play_melee_sound(melee_entry, hit_sfx, self._melee_attack_var)
			end

			if not hit_unit:character_damage()._no_blood then
				managers.game_play_central:play_impact_flesh({
					col_ray = col_ray
				})
				managers.game_play_central:play_impact_sound_and_effects({
					no_decal = true,
					no_sound = true,
					col_ray = col_ray
				})
			end

			self._camera_unit:base():play_anim_melee_item("hit_body")
		else
			if self._on_melee_restart_drill and hit_unit:base() and (hit_unit:base().is_drill or hit_unit:base().is_saw) then
				hit_unit:base():on_melee_hit(managers.network:session():local_peer():id())
			end

			if bayonet_melee then
				self._unit:sound():play("knife_hit_gen", nil, false)
			else
				self:_play_melee_sound(melee_entry, "hit_gen", self._melee_attack_var)
			end

			self._camera_unit:base():play_anim_melee_item("hit_gen")
			managers.game_play_central:play_impact_sound_and_effects({
				no_decal = true,
				no_sound = true,
				col_ray = col_ray,
				effect = Idstring("effects/payday2/particles/impacts/fallback_impact_pd2")
			})
		end

		local custom_data = nil

		if _G.IS_VR and hand_id then
			custom_data = {
				engine = hand_id == 1 and "right" or "left"
			}
		end

		managers.rumble:play("melee_hit", nil, nil, custom_data)
		managers.game_play_central:physics_push(col_ray)

		local character_unit, shield_knock = nil
		local can_shield_knock = managers.player:has_category_upgrade("player", "shield_knock")

		if can_shield_knock and hit_unit:in_slot(8) and alive(hit_unit:parent()) and not hit_unit:parent():character_damage():is_immune_to_shield_knockback() then
			shield_knock = true
			character_unit = hit_unit:parent()
		end

		character_unit = character_unit or hit_unit
		
		--vvvvvvvvvvvvvvvvvvvvvvv
		local char_base = character_unit:base()
		-- note: minor unmarked changes to optimize extension calls like character_unit:base() elsewhere in the otherwise-vanilla code
		--^^^^^^^^^^^^^^^^^^^^^^^
		
		if character_unit:character_damage() and character_unit:character_damage().damage_melee then
			local dmg_multiplier = 1

			if not managers.enemy:is_civilian(character_unit) and not managers.groupai:state():is_enemy_special(character_unit) then
				dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "non_special_melee_multiplier", 1)
			else
				dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_damage_multiplier", 1)
			end

			dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_" .. tostring(tweak_data.blackmarket.melee_weapons[melee_entry].stats.weapon_type) .. "_damage_multiplier", 1)

			if char_base and char_base.char_tweak and char_base:char_tweak().priority_shout then
				dmg_multiplier = dmg_multiplier * (tweak_data.blackmarket.melee_weapons[melee_entry].stats.special_damage_multiplier or 1)
			end

			if managers.player:has_category_upgrade("melee", "stacking_hit_damage_multiplier") then
				self._state_data.stacking_dmg_mul = self._state_data.stacking_dmg_mul or {}
				self._state_data.stacking_dmg_mul.melee = self._state_data.stacking_dmg_mul.melee or {
					nil,
					0
				}
				local stack = self._state_data.stacking_dmg_mul.melee

				if stack[1] and t < stack[1] then
					dmg_multiplier = dmg_multiplier * (1 + managers.player:upgrade_value("melee", "stacking_hit_damage_multiplier", 0) * stack[2])
				else
					stack[2] = 0
				end
			end

			local health_ratio = self._ext_damage:health_ratio()
			local damage_health_ratio = managers.player:get_damage_health_ratio(health_ratio, "melee")

			if damage_health_ratio > 0 then
				dmg_multiplier = dmg_multiplier * (1 + self._damage_health_ratio_mul_melee * damage_health_ratio)
			end

			dmg_multiplier = dmg_multiplier * managers.player:temporary_upgrade_value("temporary", "berserker_damage_multiplier", 1)
			local target_dead = character_unit:character_damage().dead and not character_unit:character_damage():dead()
			local target_hostile = managers.enemy:is_enemy(character_unit) and not tweak_data.character[char_base._tweak_table].is_escort and character_unit:brain():is_hostile()
			local life_leach_available = managers.player:has_category_upgrade("temporary", "melee_life_leech") and not managers.player:has_activate_temporary_upgrade("temporary", "melee_life_leech")

			if target_dead and target_hostile and life_leach_available then
				managers.player:activate_temporary_upgrade("temporary", "melee_life_leech")
				self._unit:character_damage():restore_health(managers.player:temporary_upgrade_value("temporary", "melee_life_leech", 1))
			end
			
--vvvvvvvvvvvvvvvvvvvvvvvvvvvvv
			local dmg_ext = character_unit:character_damage()
			local my_mov_ext = self._ext_movement
			local my_pos = my_mov_ext:m_pos()
			local my_rot = self._ext_camera:rotation()
			local look_mov = Rotation(my_rot:yaw(),0,0)
			local mov_ext = character_unit:movement()
			
			local execution_variant
			local is_execution = not (self:in_air() or self:ducking() or self:on_ladder() or self:_on_zipline())
			is_execution = is_execution and managers.enemy:is_enemy(character_unit) and not managers.enemy:is_civilian(character_unit)
			
			if is_execution and character_unit:in_slot(25,26) then -- sentry guns not allowed >:(
				--log("Sentry guns cannot be executed")
				is_execution = false
			end
			
			if is_execution and character_unit:in_slot(2,3,16,25) then -- no jokers either
				--log("Jokers not allowed")
				is_execution = false
			end
			
			if is_execution and char_base and char_base.has_tag then
				if char_base:has_tag("shield") or char_base:has_tag("phalanx_vip") or char_base:has_tag("phalanx_minion") then
					-- exclude shields, winters, and phalanx shields
					is_execution = false
				end
				
				-- special variations (for later)
--				if char_base:has_tag("tank") then
--				end
--				if char_base:has_tag("spooc") then
--				end
			end
			
			local anim_data = character_unit:anim_data()
			if is_execution and (anim_data.hurt or anim_data.hurt_exit) then
				-- can't override hurt anims so don't trigger the execution
				is_execution = false
			end
			
			-- filter out invalid states (driving, bipod, etc)
			-- not that you can melee in those.
			-- but since PlayerStandard is the parent state used as a template for a lot of state classes,
			-- it's prudent to filter them manually
			if is_execution and not GloryKills.ALLOWED_PLAYER_STATES[my_mov_ext:current_state_name() or ""] then
				is_execution = false
			end
			
			-- if a second hit would be lethal, give the damage as a bonus
			-- to trigger a kill with the execution;
			-- this is a workaround for the fact that i don't know an easy way to interrupt the current action/animation with the execution anim
			if is_execution then 
				local damage2,_ = managers.blackmarket:equipped_melee_weapon_damage_info(0)
				damage2 = damage2 * dmg_multiplier
				if dmg_ext.health and (dmg_ext:health() <= damage + damage2) then
					--todo: account for capt winters damage reduction?
					--or just apply max damage? -- damage = dmg_ext._HEALTH_INIT
					damage = damage + damage2
				else
					is_execution = false
				end
			end
			
			if is_execution then
				
				-- detect hits from behind
				mvector3.set(mvec_1, mov_ext:m_pos()) -- prev pos (before moving the enemy)
				mvector3.subtract(mvec_1, my_pos)
				mvector3.normalize(mvec_1)
				mvector3.set(mvec_2, mov_ext:m_rot():y())

				local from_behind = mvector3.dot(mvec_1, mvec_2) >= 0
				-- set animation variant
				
				execution_variant = GloryKills:get_execution_variant({
					variant = GloryKills:get_execution_type_by_melee(melee_entry),
					from_behind = from_behind
				})
			end
			mov_ext._execution_variant = execution_variant
--			Print("execution_variant",execution_variant)
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
			local action_data = {
				variant = "melee",
				is_execution = execution_variant and is_execution
--				,execution_variant = execution_variant
			}

			if _G.IS_VR and melee_entry == "weapon" and not bayonet_melee then
				dmg_multiplier = 0.1
			end

			action_data.damage = shield_knock and 0 or damage * dmg_multiplier
			action_data.damage_effect = damage_effect
			action_data.attacker_unit = self._unit
			action_data.col_ray = col_ray

			if shield_knock then
				action_data.shield_knock = can_shield_knock
			end

			action_data.name_id = melee_entry
			action_data.charge_lerp_value = charge_lerp_value

			if managers.player:has_category_upgrade("melee", "stacking_hit_damage_multiplier") then
				self._state_data.stacking_dmg_mul = self._state_data.stacking_dmg_mul or {}
				self._state_data.stacking_dmg_mul.melee = self._state_data.stacking_dmg_mul.melee or {
					nil,
					0
				}
				local stack = self._state_data.stacking_dmg_mul.melee

				if dmg_ext.dead and not dmg_ext:dead() then
					stack[1] = t + managers.player:upgrade_value("melee", "stacking_hit_expire_t", 1)
					stack[2] = math.min(stack[2] + 1, tweak_data.upgrades.max_melee_weapon_dmg_mul_stacks or 5)
				else
					stack[1] = nil
					stack[2] = 0
				end
			end

			
			
			local defense_data = character_unit:character_damage():damage_melee(action_data)

			self:_check_melee_special_damage(col_ray, character_unit, defense_data, melee_entry)
			self:_perform_sync_melee_damage(hit_unit, col_ray, action_data.damage)
			
			
--vvvvvvvvvvvvvvvvvvvvvvvvvvvvv
			if is_execution and defense_data and defense_data.type == "death" then
				if GloryKills.unit then
					GloryKills.unit:set_position(my_pos)
					GloryKills.unit:set_rotation(look_mov)
					
					local redir = GloryKills.unit:movement():play_redirect("execution")
					GloryKills.unit:movement()._machine:set_parameter(redir, execution_variant, 1)
				end
				
				mov_ext:set_rotation(look_mov)
				mov_ext:set_position(mvector3.copy(my_pos))
				self._state_data.execution_unit = character_unit
				self._state_data.execution_prev_state = my_mov_ext:current_state_name() or "standard"
				GloryKills.set_viewmodel_visible(self,false)
				my_mov_ext:change_state("execution")
			end
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
			
			return defense_data
		else
			self:_perform_sync_melee_damage(hit_unit, col_ray, damage)
		end
	end

	if managers.player:has_category_upgrade("melee", "stacking_hit_damage_multiplier") then
		self._state_data.stacking_dmg_mul = self._state_data.stacking_dmg_mul or {}
		self._state_data.stacking_dmg_mul.melee = self._state_data.stacking_dmg_mul.melee or {
			nil,
			0
		}
		local stack = self._state_data.stacking_dmg_mul.melee
		stack[1] = nil
		stack[2] = 0
	end

	return col_ray
end)






do return end
-- old version that activates instantly on button press
_G.testhook = function(self, t, input,...)

	local action_wanted = input.btn_melee_press or input.btn_melee_release
	--GloryKills:Print("press",input.btn_melee_press,"release",input.btn_melee_release)
	if not action_wanted then
		return
	end
	
	local action_forbidden = not self:_melee_repeat_allowed() or self._use_item_expire_t or self:_changing_weapon() or self:_interacting() or self:_is_throwing_projectile() or self:_is_using_bipod() or self:is_shooting_count()
	-- extra conditions specific to the execution
	or self:in_air() or self:ducking() or self:on_ladder() or self:_on_zipline()
	
	if action_forbidden then
		return
	end
	
	local col_ray = self:_calc_melee_hit_ray(t, 20)
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
			if not hit_base then 
				return
			end
			
			if hit_base.has_tag then
				if hit_base:has_tag("shield") or hit_base:has_tag("phalanx_vip") or hit_base:has_tag("phalanx_minion") then
					-- exclude shields, winters, and phalanx shields
					return 
				end
				
				-- special variations (for later)
--				if hit_base:has_tag("tank") then
--				end
--				if hit_base:has_tag("spooc") then
--				end
			end
			
			if hit_unit:in_slot(25,26) then -- sentry guns not allowed >:(
				--log("Sentry guns cannot be executed")
				return
			end
			
			if hit_unit:in_slot(2,3,16,25) then -- no jokers either
				--log("Jokers not allowed")
				return
			end
			
			
			local my_mov_ext = self._ext_movement
			local my_pos = my_mov_ext:m_pos()
			local my_rot = self._ext_camera:rotation()
			local look_mov = Rotation(my_rot:yaw(),0,0)
			local hit_mov_ext = hit_unit:movement()
			
			
			-- perform line-of-sight checks
			local slotmask = managers.slot:get_mask("world_geometry")
			local has_los = true
			local ray
			do -- check head position
				mvector3.set(mvec_1,my_mov_ext:m_head_pos())
				mvector3.set(mvec_2,hit_mov_ext:m_head_pos())
				ray = World:raycast("ray", mvec_1, mvec_2, "slot_mask", slotmask)
				if ray then 
					-- hit obstacle
					has_los = false
					
				end
				
				if DEBUG_DRAW_ENABLED then
					if ray then
						Draw:brush(Color.red,5):line(mvec_1,mvec_2,5)
					else
						Draw:brush(Color.green,5):line(mvec_1,mvec_2,5)
					end
				end
				
			end
			
			ray = nil
			do -- check body position
--				mvector3.set(mvec_1,my_mov_ext:m_head_pos()) -- should still be player head pos
				mvector3.set(mvec_2,hit_unit:oobb():center())
				ray = World:raycast("ray", mvec_1, mvec_2, "slot_mask", slotmask)
				if ray then 
					has_los = false
				end
				
				if DEBUG_DRAW_ENABLED then
					if ray then
						Draw:brush(Color.red,5):line(mvec_1,mvec_2,5)
					else
						Draw:brush(Color.green,5):line(mvec_1,mvec_2,5)
					end
				end
				
			end
			
			--[[
			ray = nil
			do -- check leg/feet position
				mvector3.set(mvec_1,my_pos)
				mvector3.add(mvec_1,Vector3(0,0,50))
				mvector3.set(mvec_2,hit_mov_ext:m_pos())
				mvector3.add(mvec_2,Vector3(0,0,50))
				ray = World:raycast("ray", mvec_1, mvec_2, "slot_mask", slotmask)
				if ray then 
					has_los = false
				end
				
				if DEBUG_DRAW_ENABLED then
					if ray then
						Draw:brush(Color.red,5):line(mvec_1,mvec_2,5)
					else
						Draw:brush(Color.green,5):line(mvec_1,mvec_2,5)
					end
				end
			end
			--]]
			
			if not has_los then
				--log("Insufficient line of sight to execution target")
				return
			end
			
		
			local dmg_ext = hit_unit:character_damage()
			if dmg_ext and dmg_ext.damage_melee and dmg_ext.health and not (dmg_ext:dead() or dmg_ext._immortal or dmg_ext._invulnerable) then
				
				-- do health check; only attempt proc if melee is estimated to be fatal blow
				local melee_entry = managers.blackmarket:equipped_melee_weapon()
				local melee_td = tweak_data.blackmarket.melee_weapons[melee_entry]
				
				if hit_mov_ext:cool() then
					-- assume it will be an instant kill anyway
				else
					local damage,_ = managers.blackmarket:equipped_melee_weapon_damage_info(1)
					damage = damage * managers.player:get_melee_dmg_multiplier()
		
					local dmg_multiplier = 1
					
					if not managers.groupai:state():is_enemy_special(hit_unit) then
						dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "non_special_melee_multiplier", 1)
					else
						dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_damage_multiplier", 1)
					end
					
					dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_" .. tostring(melee_td.stats.weapon_type) .. "_damage_multiplier", 1)

					if hit_base.char_tweak and hit_base:char_tweak().priority_shout then
						dmg_multiplier = dmg_multiplier * (melee_td.stats.special_damage_multiplier or 1)
					end

					if managers.player:has_category_upgrade("melee", "stacking_hit_damage_multiplier") then
						self._state_data.stacking_dmg_mul = self._state_data.stacking_dmg_mul or {}
						self._state_data.stacking_dmg_mul.melee = self._state_data.stacking_dmg_mul.melee or {
							nil,
							0
						}
						local stack = self._state_data.stacking_dmg_mul.melee

						if stack[1] and t < stack[1] then
							dmg_multiplier = dmg_multiplier * (1 + managers.player:upgrade_value("melee", "stacking_hit_damage_multiplier", 0) * stack[2])
						end
					end
					
					local damage_health_ratio = managers.player:get_damage_health_ratio(self._ext_damage:health_ratio(), "melee")

					if damage_health_ratio > 0 then
						dmg_multiplier = dmg_multiplier * (1 + self._damage_health_ratio_mul_melee * damage_health_ratio)
					end

					dmg_multiplier = dmg_multiplier * managers.player:temporary_upgrade_value("temporary", "berserker_damage_multiplier", 1)
					
					damage = damage * dmg_multiplier
					
					-- final health check
					if damage < dmg_ext:health() then
						--log("Not projected fatal blow:",damage,dmg_ext:health())
						return
					end
				end
				
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
					--log("Hit ineffective")
					return
				end
				
				-- reset bloodthirst stacks
				if managers.player:has_category_upgrade("melee", "stacking_hit_damage_multiplier") then
					self._state_data.stacking_dmg_mul = self._state_data.stacking_dmg_mul or {}
					self._state_data.stacking_dmg_mul.melee = self._state_data.stacking_dmg_mul.melee or {
						nil,
						0
					}
					local stack = self._state_data.stacking_dmg_mul.melee

					if dmg_ext.dead and not dmg_ext:dead() then
						stack[1] = t + managers.player:upgrade_value("melee", "stacking_hit_expire_t", 1)
						stack[2] = math.min(stack[2] + 1, tweak_data.upgrades.max_melee_weapon_dmg_mul_stacks or 5)
					else
						stack[1] = nil
						stack[2] = 0
					end
				end
				
				if result.type == "death" then
					--GloryKills:Print("Successful proc. Entering execution state")
					if GloryKills.unit then
						GloryKills.unit:set_position(my_pos)
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
					hit_mov_ext:set_position(mvector3.copy(my_pos))
					self._state_data.execution_unit = hit_unit
					self._state_data.execution_prev_state = my_mov_ext:current_state_name() or "standard"
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
end
Hooks:PreHook(PlayerStandard,"_check_action_melee","glorykills_playerstandard_checkmelee",function(...)
	_G.testhook(...)
end)





--[[
BeardLib:AddUpdater("asdfljaksdljkf",function(t,dt)
	if alive(barfoo1) then
		Draw:brush(Color.red:with_alpha(0.5)):sphere(barfoo1:position(),10)
	end
	if alive(barfoo2) then
		Draw:brush(Color.blue:with_alpha(0.5)):sphere(barfoo2:position(),10)
	end
end)
--]]

-- i included these for safety (from PlayerStandard) but they aren't used by any of the functions this mod hooks
local impact_bones_tmp = {
	"Hips",
	"Spine",
	"Spine1",
	"Spine2",
	"Neck",
	"Head",
	"LeftShoulder",
	"LeftArm",
	"LeftForeArm",
	"RightShoulder",
	"RightArm",
	"RightForeArm",
	"LeftUpLeg",
	"LeftLeg",
	"LeftFoot",
	"RightUpLeg",
	"RightLeg",
	"RightFoot",
	"c_sphere_head"
}
local impact_body_distance_tmp = {
	Head = 15,
	Spine1 = 25,
	RightShoulder = 20,
	LeftFoot = 5,
	Spine2 = 20,
	RightLeg = 10,
	c_sphere_head = 15,
	LeftShoulder = 20,
	LeftUpLeg = 15,
	RightFoot = 5,
	LeftArm = 8,
	Spine = 15,
	Neck = 7,
	RightUpLeg = 15,
	RightArm = 8,
	LeftLeg = 10,
	LeftForeArm = 6,
	RightForeArm = 6,
	Hips = 15
}



Hooks:OverrideFunction(PlayerStandard,"_check_action_melee",
	function(...)
		_G.testhook(...)
	end
)



--[[
local orig = Hooks:GetFunction(PlayerStandard,"_do_action_melee")
Hooks:OverrideFunction(PlayerStandard,"_do_action_melee",function(self,t,input,skip_damage)
	
	
	
	return orig(self,t,input,skip_damage)

end)
--]]


--Hooks:PostHook(PlayerStandard,"_do_action_melee","glorykills_onmeleeattack",function(self, t, input, skip_damage)
--	local unit = self:_calc_melee_hit_ray(t,100)
-- if valid hit unit is low health, enter execution state
--end)

--[[
Hooks:PostHook(PlayerStandard,"_do_melee_damage","glorykills_onmeleedamage",function(self, t, bayonet_melee, melee_hit_ray, melee_entry, hand_id)
	local defense_data = Hooks:GetReturn()
	if defense_data and defense_data.result.type == "death" then
	
	end
	
end)
--]]

do return end

-- this is no longer necessary
_G.execute_unit = function(unit,col_ray)
	col_ray = col_ray or {
		normal = Vector3(),
		position = Vector3(),
		ray = Vector3(),
		hit_position = Vector3(),
		distance = 1000,
		unit = unit
	}	
	
	local hit_mov_ext = unit:movement()
	local player = managers.player:local_player()
	local my_mov_ext = player:movement()
	local state = my_mov_ext:current_state()
	local my_pos = hit_mov_ext:m_pos()
	--my_mov_ext:m_pos()
	local my_rot = state._ext_camera:rotation() --my_mov_ext:m_rot()
	local look_mov = Rotation(my_rot:yaw(),0,0)
	
	local attack_data = {
		variant = "melee",
		damage = unit:character_damage()._HEALTH_INIT or 10000000,
		damage_effect = 0,
		attacker_unit = player,
		col_ray = col_ray,
		name_id = managers.blackmarket:equipped_melee_weapon(),
		charge_lerp_value = 0
	}
				
	
	if GloryKills.unit then
		GloryKills.unit:set_position(my_pos)
		GloryKills.unit:set_rotation(look_mov)
		GloryKills.unit:movement():play_redirect("execution")
	end
	
	unit:brain():clbk_death(unit,damage_info) -- disable attention and pesky auto-idle anim
	
	hit_mov_ext:set_rotation(look_mov)
	hit_mov_ext:set_m_pos(my_pos)
	hit_mov_ext:play_redirect("death_execution")
end



_G.copdamage_execute_melee = function(self,attack_data)
	if self._dead or self._invulnerable then
		return
	end

	if PlayerDamage.is_friendly_fire(self, attack_data.attacker_unit) then
		return "friendly_fire"
	end

	if self:chk_immune_to_attacker(attack_data.attacker_unit) then
		return
	end

	local result = nil
	local is_civlian = CopDamage.is_civilian(self._unit:base()._tweak_table)
	local is_gangster = CopDamage.is_gangster(self._unit:base()._tweak_table)
	local is_cop = not is_civlian and not is_gangster
	local head = self._head_body_name and attack_data.col_ray.body and attack_data.col_ray.body:name() == self._ids_head_body_name
	local damage = attack_data.damage

	if attack_data.attacker_unit and attack_data.attacker_unit == managers.player:player_unit() then
		local critical_hit, crit_damage = self:roll_critical_hit(attack_data, damage)

		if critical_hit then
			managers.hud:on_crit_confirmed()

			damage = crit_damage
			attack_data.critical_hit = true
		else
			managers.hud:on_hit_confirmed()
		end

		if tweak_data.achievement.cavity.melee_type == attack_data.name_id and not CopDamage.is_civilian(self._unit:base()._tweak_table) then
			managers.achievment:award(tweak_data.achievement.cavity.award)
		end
	end

	damage = damage * (self._marked_dmg_mul or 1)

	if self._unit:movement():cool() then
		damage = self._HEALTH_INIT
	end

	local damage_effect = attack_data.damage_effect
	local damage_effect_percent = 1
	damage = self:_apply_damage_reduction(damage)
	damage = math.clamp(damage, self._HEALTH_INIT_PRECENT, self._HEALTH_INIT)
	local damage_percent = math.ceil(damage / self._HEALTH_INIT_PRECENT)
	damage = damage_percent * self._HEALTH_INIT_PRECENT
	damage, damage_percent = self:_apply_min_health_limit(damage, damage_percent)

	if self._immortal then
		damage = math.min(damage, self._health - 1)
	end

	if self._health <= damage then
		if self:check_medic_heal() then
			result = {
				type = "healed",
				variant = attack_data.variant
			}
		else
			damage_effect_percent = 1
			attack_data.damage = self._health
			result = {
				type = "death",
				variant = attack_data.variant
			}

			self:die(attack_data)
			self:chk_killshot(attack_data.attacker_unit, "melee", false, attack_data.name_id)
		end
	else
		attack_data.damage = damage
		damage_effect = math.clamp(damage_effect, self._HEALTH_INIT_PRECENT, self._HEALTH_INIT)
		damage_effect_percent = math.ceil(damage_effect / self._HEALTH_INIT_PRECENT)
		damage_effect_percent = math.clamp(damage_effect_percent, 1, self._HEALTH_GRANULARITY)
		local result_type = attack_data.shield_knock and self._char_tweak.damage.shield_knocked and "shield_knock" or attack_data.variant == "counter_tased" and "counter_tased" or attack_data.variant == "taser_tased" and "taser_tased" or attack_data.variant == "counter_spooc" and "expl_hurt" or self:get_damage_type(damage_effect_percent, "melee") or "fire_hurt"
		result = {
			type = result_type,
			variant = attack_data.variant
		}

		self:_apply_damage_to_health(damage)
	end

	attack_data.result = result
	attack_data.pos = attack_data.col_ray.position
	local dismember_victim = false
	local snatch_pager = false

	if result.type == "death" then
--		if self:_dismember_condition(attack_data) then
--			self:_dismember_body_part(attack_data)
--
--			dismember_victim = true
--		end

		local data = {
			name = self._unit:base()._tweak_table,
			stats_name = self._unit:base()._stats_name,
			head_shot = head,
			weapon_unit = attack_data.weapon_unit,
			name_id = attack_data.name_id,
			variant = attack_data.variant
		}

		managers.statistics:killed_by_anyone(data)

		if attack_data.attacker_unit == managers.player:player_unit() then
			self:_comment_death(attack_data.attacker_unit, self._unit)
			self:_show_death_hint(self._unit:base()._tweak_table)
			managers.statistics:killed(data)

			if not is_civlian and managers.groupai:state():whisper_mode() and managers.blackmarket:equipped_mask().mask_id == tweak_data.achievement.cant_hear_you_scream.mask then
				managers.achievment:award_progress(tweak_data.achievement.cant_hear_you_scream.stat)
			end

			mvector3.set(mvec_1, self._unit:position())
			mvector3.subtract(mvec_1, attack_data.attacker_unit:position())
			mvector3.normalize(mvec_1)
			mvector3.set(mvec_2, self._unit:rotation():y())

			local from_behind = mvector3.dot(mvec_1, mvec_2) >= 0

			if is_cop and Global.game_settings.level_id == "nightclub" and attack_data.name_id and attack_data.name_id == "fists" then
				managers.achievment:award_progress(tweak_data.achievement.final_rule.stat)
			end

			if is_civlian then
				managers.money:civilian_killed()
			elseif math.rand(1) < managers.player:upgrade_value("player", "melee_kill_snatch_pager_chance", 0) then
				snatch_pager = true
				self._unit:unit_data().has_alarm_pager = false
			end
		end
	end

	self:_check_melee_achievements(attack_data)

	local hit_offset_height = math.clamp(attack_data.col_ray.position.z - self._unit:movement():m_pos().z, 0, 300)
	local variant = nil

	if result.type == "shield_knock" then
		variant = 1
	elseif result.type == "counter_tased" then
		variant = 2
	elseif result.type == "expl_hurt" then
		variant = 4
	elseif snatch_pager then
		variant = 3
	elseif result.type == "taser_tased" then
		variant = 5
	elseif dismember_victim then
		variant = 6
	elseif result.type == "healed" then
		variant = 7
	else
		variant = 0
	end

	local body_index = self._unit:get_body_index(attack_data.col_ray.body:name())

	self:_send_melee_attack_result(attack_data, damage_percent, damage_effect_percent, hit_offset_height, variant, body_index)
	--self:_on_damage_received(attack_data)

	result.attack_data = attack_data

	return result
end
