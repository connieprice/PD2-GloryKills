
--[[


todo:

- raycast checks (like bipods) to ensure unobstructed view to enemy
	- 3x rays- head, body, legs

figure out the "proper" way to trigger death logic AND death animations
- death logic shouldn't do anything to the unit that would cause a crash with other players
	- freeze the unit, preventing it from taking action
		- this entails disabling the brain ai and unregistering it with the groupai state/manager
	- kill the unit, counting as a kill
		- needs to call on-kill listeners like in playermanager






	
execution_slap first slap of the cop weapon to the side
execution_punch punch
execution_grab grabbing the cop's head
execution_kill headbutt
death presumed ragdoll timing so at this trigger i thought itd be ok to turn the cop into a ragdoll
also the player animation is 46 frames long
the cop animation is 71

test triggering death anim from calling listeners

check if custom state syncing will crash unmodded clients
	
	
	
	
	
	
	
	--]]




--local mov = managers.player:local_player():movement():current_state()._fwd_ray.unit:movement()
--managers.player:local_player():movement():current_state()._fwd_ray.unit:chk_freeze_anims()
--mov:play_redirect("execution")
--mov:on_anim_freeze(true)

function CopActionHurt:init(action_desc, common_data) end




managers.player:local_player():movement():current_state()._fwd_ray.unit:movement():play_redirect("death_exit")
managers.player:local_player():movement():current_state()._fwd_ray.unit:movement():play_redirect("up_idle")
managers.player:local_player():movement():current_state()._fwd_ray.unit:movement():anim_clbk_force_ragdoll()
managers.player:local_player():movement():current_state()._fwd_ray.unit:anim_data().ragdoll = true
managers.player:local_player():movement():current_state()._fwd_ray.unit:set_slot(0)


execute_unit(managers.player:local_player():movement():current_state()._fwd_ray.unit)

local player = managers.player:local_player()
local fwd_ray = player:movement():current_state()._fwd_ray
			local attack_data = {
				variant = "execution",
				damage = 1000000,
				damage_effect = 0,
				attacker_unit = player,
				col_ray = fwd_ray,
				name_id = managers.blackmarket:equipped_melee_weapon(),
				charge_lerp_value = 0
			}
--fwd_ray.unit:character_damage():die(attack_data)
fwd_ray.unit:character_damage():damage_melee(attack_data)
			
local player = managers.player:local_player()
local fwd_ray = player:movement():current_state()._fwd_ray
local damage_info = {
	variant = "execution",
	damage = 1000000,
	damage_effect = 0,
	attacker_unit = player,
	col_ray = fwd_ray,
	name_id = managers.blackmarket:equipped_melee_weapon(),
	charge_lerp_value = 0
}			
local a = fwd_ray.unit; a:brain():clbk_death(a,damage_info)


--			managers.player:local_player():movement():current_state()._fwd_ray.unit:movement():play_redirect("death_execution")
--			GloryKills.unit:movement():play_redirect("death_execution")
			
			managers.player:local_player():movement():current_state()._fwd_ray.unit:movement():action_request({
				type = "death",
				hurt_type = "death",
				variant = "bullet",
				direction_vec = Vector3(),
				hit_pos = Vector3(),
				body_part = 1,
				instant = true,
				client_interrupt = true,
				weapon_unit = managers.player:local_player():inventory():equipped_unit(),
				attacker_unit = managers.player:local_player(),
				death_type = "normal",
				blocks = {
					walk = 1,
					crouch = 1,
					act = 1,
					action = 1,
					aim = 1,
					action = 1,
					tase = 1,
					bleedout = 1,
					hurt = 1,
					heavy_hurt = 1,
					hurt_sick = 1,
					concussion = 1,
				}
			})
				
				
				--fwd_ray.unit:character_damage():damage_melee(attack_data)
				
				--local result = _G.copdamage_execute_melee(dmg_ext,attack_data)
				--redirect
				--dmg_ext:_on_damage_received(attack_data)
				
				--self:_prepare_ragdoll()
				--self:force_ragdoll()

				local damage_info = { -- for triggering the anim
					damage = 0,
					variant = "melee",
					pos = Vector3(),
					attack_dir = Vector3(),
					result = {
						variant = "melee",
						type = "execution"
					}
				}
				managers.player:local_player():movement():current_state()._fwd_ray.unit:character_damage():_call_listeners(damage_info)
					
	
	
	
	
	
	
	
	
	
	
	
	
