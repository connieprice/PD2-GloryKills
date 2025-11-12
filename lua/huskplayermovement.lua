
-- these aren't being triggered from the anim, idk why
function HuskPlayerMovement:anim_execution_slap(...)

end
function HuskPlayerMovement:anim_execution_punch(...)

end
function HuskPlayerMovement:anim_execution_grab(...)

end
function HuskPlayerMovement:anim_execution_generic(s)
--	Print("Animation callback:",s)
end

function HuskPlayerMovement:anim_execution_kill(...)
--	local player = managers.player:local_player()
--	local mov_ext = alive(player) and player:movement()
--	local state = mov_ext and mov_ext:current_state()
--	if state then 
----		mov_ext:change_state("standard")
--	end
end

function HuskPlayerMovement:anim_start_execution(...)
--	Print("HuskPlayerMovement:anim_start_execution()")
--	managers.player:local_player():movement():change_state("standard")
end

function HuskPlayerMovement:anim_stop_execution(...)
--	Print("HuskPlayerMovement:anim_stop_execution()")
--	managers.player:local_player():movement():change_state("standard")
	local player = managers.player:local_player()
	local mov_ext = alive(player) and player:movement()
	local state = mov_ext and mov_ext:current_state()
	if state then 
		mov_ext:change_state("standard")
	end
end

--]]