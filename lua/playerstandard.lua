local DEBUG_DRAW_ENABLED = true
-- visualize raycast line-of-sight checks

PlayerStandard.ANIM_STATES.standard.execution = Idstring("execution")

--memory optimization; temp vector allocations to be used for various calculations
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


--local barfool,barfoo2

--local mvec_1 = Vector3()
--local mvec_2 = Vector3()
_G.testhook = function(self, t, input,...)

	local action_wanted = input.btn_melee_press or input.btn_melee_release
	--Print("press",input.btn_melee_press,"release",input.btn_melee_release)
	if not action_wanted then
		return
	end
	
	local action_forbidden = not self:_melee_repeat_allowed() or self._use_item_expire_t or self:_changing_weapon() or self:_interacting() or self:_is_throwing_projectile() or self:_is_using_bipod() or self:is_shooting_count()
	-- extra conditions specific to the execution
	or self:in_air() or self:ducking() or self:on_ladder() or self:_on_zipline()
	
	if action_forbidden then
		return
	end
	
	--local melee_entry = managers.blackmarket:equipped_melee_weapon()
	
	local col_ray = self:_calc_melee_hit_ray(t, 20)
	local hit_unit = col_ray and col_ray.unit
	if hit_unit then
		if managers.enemy:is_enemy(hit_unit) and not managers.enemy:is_civilian(hit_unit) then
		
			if hit_unit:in_slot(25,26) then -- sentry guns not allowed >:(
				return
			end
			
			if hit_unit:in_slot(2,3,16,25) then -- no jokers either
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
				mvector3.set(mvec1,my_mov_ext:m_head_pos())
				mvector3.set(mvec2,hit_mov_ext:m_head_pos())
				ray = World:raycast("ray", mvec1, mvec2, "slot_mask", slotmask)
				if ray then 
					-- hit obstacle
					has_los = false
					
				end
				
				if DEBUG_DRAW_ENABLED then
					if ray then
						Draw:brush(Color.red,5):line(mvec1,mvec2,5)
					else
						Draw:brush(Color.green,5):line(mvec1,mvec2,5)
					end
				end
				
			end
			
			ray = nil
			do -- check body position
--				mvector3.set(mvec1,my_mov_ext:m_head_pos()) -- should still be player head pos
				mvector3.set(mvec2,hit_unit:oobb():center())
				ray = World:raycast("ray", mvec1, mvec2, "slot_mask", slotmask)
				if ray then 
					has_los = false
				end
				
				if DEBUG_DRAW_ENABLED then
					if ray then
						Draw:brush(Color.red,5):line(mvec1,mvec2,5)
					else
						Draw:brush(Color.green,5):line(mvec1,mvec2,5)
					end
				end
				
			end
			
			ray = nil
			do -- check leg/feet position
				mvector3.set(mvec1,my_pos)
				mvector3.set(mvec2,hit_mov_ext:m_pos())
				ray = World:raycast("ray", mvec1, mvec2, "slot_mask", slotmask)
				if ray then 
					has_los = false
				end
				
				if DEBUG_DRAW_ENABLED then
					if ray then
						Draw:brush(Color.red,5):line(mvec1,mvec2,5)
					else
						Draw:brush(Color.green,5):line(mvec1,mvec2,5)
					end
				end
			end
			
			
			if has_los then
				local dmg_ext = hit_unit:character_damage()
				if dmg_ext and dmg_ext.damage_melee and not (dmg_ext:dead() or dmg_ext._immortal) then
					
					-- do health check; only attempt proc if melee is estimated to be fatal blow
					local melee_td = tweak_data.blackmarket.melee_weapons[melee_entry]
					local damage,dmg_multiplier = 0,0
					
					if not managers.groupai:state():is_enemy_special(hit_unit) then
						dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "non_special_melee_multiplier", 1)
					else
						dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_damage_multiplier", 1)
					end
					
					dmg_multiplier = dmg_multiplier * managers.player:upgrade_value("player", "melee_" .. tostring(melee_td.stats.weapon_type) .. "_damage_multiplier", 1)

					if character_unit:base() and character_unit:base().char_tweak and character_unit:base():char_tweak().priority_shout then
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
						else
							stack[2] = 0
						end
					end

					
					
					
					local attack_data = {
						variant = "execution",
						damage = dmg_ext._HEALTH_INIT or 10000000,
						damage_effect = 0,
						attacker_unit = self._unit,
						col_ray = col_ray,
						name_id = managers.blackmarket:equipped_melee_weapon(),
						charge_lerp_value = 0
					}
					local result = dmg_ext:damage_melee(attack_data)
					if result and result.type == "death" then
						--Print("Successful proc. Entering execution state")
						-- detect back hits
						mvector3.set(mvec_1, hit_mov_ext:m_pos()) -- prev pos (before moving the enemy)
						mvector3.subtract(mvec_1, my_pos)
						mvector3.normalize(mvec_1)
						mvector3.set(mvec_2, hit_mov_ext:m_rot():y())

						local from_behind = mvector3.dot(mvec_1, mvec_2) >= 0
						local variant
						if from_behind then
							-- set variant
							variant = "var2"
						else
							variant = "var1"
						end
						if GloryKills.unit then
							GloryKills.unit:set_position(my_pos)
							GloryKills.unit:set_rotation(look_mov)
							
							local redir = GloryKills.unit:movement():play_redirect("execution")
							GloryKills._unit:movement()._machine:set_parameter(redir, variant, 1)
						end
						result.variant = "execution"
						result.execution_variant = variant


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
						return
					end
				end
			end
		end
	end
end

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

Hooks:PreHook(PlayerStandard,"_check_action_melee","glorykills_playerstandard_checkmelee",function(...)
	_G.testhook(...)
end)

do return end

Hooks:OverrideFunction(PlayerStandard,"_check_action_melee",
	function(...)
		_G.testhook(...)
	end
)