--[[
execution_slap first slap of the cop weapon to the side
execution_punchthroat punch
execution_grab grabbing the cop's head
execution_kill headbutt
death presumed ragdoll timing so at this trigger i thought itd be ok to turn the cop into a ragdoll
also the player animation is 46 frames long
the cop animation is 71

test triggering death anim from calling listeners

force stand before entering melee
check zipline/other invalid actions

check if custom state syncing will crash unmodded clients
--]]

PlayerStandard.ANIM_STATES.standard.execution = Idstring("execution")

local mvec_1 = Vector3()
local mvec_2 = Vector3()
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

--[[

	playerstate._ext_camera:play_redirect(Idstring("execution"))


_G.copdamage_execute_die = function(self,attack_data)
	if self._immortal then
		debug_pause("Immortal character died!")
	end

	managers.modifiers:run_func("OnEnemyDied", self._unit, attack_data)
	self:_check_friend_4(attack_data)
	self:_check_ranc_9(attack_data)
	CopDamage.MAD_3_ACHIEVEMENT(attack_data)
	self:_remove_debug_gui()
	self._unit:base():set_slot(self._unit, 17)
	self:drop_pickup()
	self._unit:inventory():drop_shield()
	self:_chk_unique_death_requirements(attack_data, true)

	if self._unit:unit_data().mission_element then
		self._unit:unit_data().mission_element:event("death", self._unit)

		if not self._unit:unit_data().alerted_event_called then
			self._unit:unit_data().alerted_event_called = true

			self._unit:unit_data().mission_element:event("alerted", self._unit)
		end
	end

	if self._unit:movement() then
		self._unit:movement():remove_giveaway()
	end

	self._health = 0
	self._health_ratio = 0
	self._dead = true

	self:set_mover_collision_state(false)

	if self._death_sequence then
		if self._unit:damage() and self._unit:damage():has_sequence(self._death_sequence) then
			self._unit:damage():run_sequence_simple(self._death_sequence)
		else
			debug_pause_unit(self._unit, "[CopDamage:die] does not have death sequence", self._death_sequence, self._unit)
		end
	end

--	if self._unit:base():char_tweak().die_sound_event then
--		self._unit:sound():play(self._unit:base():char_tweak().die_sound_event, nil, nil)
--	end

	self:_on_death()
	managers.mutators:notify(Message.OnCopDamageDeath, self._unit, attack_data)

	if self._tmp_invulnerable_clbk_key then
		managers.enemy:remove_delayed_clbk(self._tmp_invulnerable_clbk_key)

		self._tmp_invulnerable_clbk_key = nil
	end
end

_G.copdamage_delayed_death_fx = function(self)
	if self._unit:base():char_tweak().die_sound_event then
		self._unit:sound():play(self._unit:base():char_tweak().die_sound_event, nil, nil)
	end
end
--]]






_G.testhook = function(self, t, input)

	local action_wanted = input.btn_melee_press or input.btn_melee_release
	if not action_wanted then
		return
	end
	
	local action_forbidden = not self:_melee_repeat_allowed() or self._use_item_expire_t or self:_changing_weapon() or self:_interacting() or self:_is_throwing_projectile() or self:_is_using_bipod() or self:is_shooting_count()
	
	if action_forbidden then
		return
	end
	
	--local melee_entry = managers.blackmarket:equipped_melee_weapon()
	
	local col_ray = self:_calc_melee_hit_ray(t, 20)
	local hit_unit = col_ray and col_ray.unit
	if hit_unit then
		if managers.enemy:is_enemy(hit_unit) then
			local dmg_ext = hit_unit:character_damage()
			if dmg_ext and dmg_ext.damage_melee and not (dmg_ext:dead() or dmg_ext._immortal) then
			-- kill the enemy here;
			-- perform identical damage calculation,
			-- but without the vfx/sfx,
			-- only the network
				
				local attack_data = {
					variant = "melee",
					damage = dmg_ext._HEALTH_INIT or 10000000,
					damage_effect = 0,
					attacker_unit = self._unit,
					col_ray = col_ray,
					name_id = managers.blackmarket:equipped_melee_weapon(),
					charge_lerp_value = 0
				}
				
				--local result = _G.copdamage_execute_melee(dmg_ext,attack_data)
				--redirect
				--dmg_ext:_on_damage_received(attack_data)
				
				dmg_ext:die(attack_data)
				
				foo3 = col_ray
			
				local damage_info = { -- for triggering the anim
					damage = attack_data.damage,
					variant = "melee",
					pos = Vector3(),
					attack_dir = Vector3(),
					result = {
						variant = "melee",
						type = "execution"
					}
				}
				dmg_ext:_call_listeners(damage_info)
					
				
				--if result and result.type == "death" then
				if dmg_ext:dead() then
					Print("Successful proc. Entering execution state")
					
					local my_mov_ext = self._ext_movement
					local my_pos = my_mov_ext:m_pos()
					local my_rot = self._ext_camera:rotation() --my_mov_ext:m_rot()
--					self._state_data.execution_start_position = mvector3.copy(my_pos)
					-- rotate cop to face player
					-- set position to cop position
					-- rotate player to face cop
					-- after anim, move player back to orig pos
					hit_unit:movement():set_rotation(Rotation(my_rot:yaw(),0,0))
					hit_unit:movement():set_m_pos(my_pos)
					hit_unit:movement():play_redirect("death_execution")
					
					
					
					my_mov_ext:change_state("execution")
					
					-- disable the melee that would otherwise occur on this frame
					self._state_data.melee_attack_wanted = 0
					self._state_data.melee_attack_allowed_t = 0
				end
				
			end
		end
	end
end

Hooks:PreHook(PlayerStandard,"_check_action_melee","glorykills_playerstandard_checkmelee",function(...)
	_G.testhook(...)
end)


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