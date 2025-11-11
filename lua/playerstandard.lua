local DEBUG_DRAW_ENABLED = false
-- visualize raycast line-of-sight checks

PlayerStandard.ANIM_STATES.standard.execution = Idstring("execution")
--memory optimization; temp vector allocations to be used for various calculations
local mvec_1 = Vector3()
local mvec_2 = Vector3()

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
					
					my_mov_ext:change_state("execution")
					
					
				-- disable the melee that would otherwise occur on this frame
--						self._state_data.melee_attack_allowed_t = 0
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

do return end


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
