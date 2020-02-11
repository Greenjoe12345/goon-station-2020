/obj/critter/gunbot/drone
	name = "Syndicate Drone"
	desc = "An armed and automated Syndicate scout drone."
	icon = 'icons/obj/ship.dmi'
	icon_state = "drone"
	density = 1
	health = 65
	var/maxhealth = 65 // for damage description
	aggressive = 1
	defensive = 1
	wanderer = 1
	opensdoors = 0
	atkcarbon = 1
	atksilicon = 1
	atcritter = 0
	firevuln = 0.5
	brutevuln = 1
	miscvuln = 0
	luminosity = 5
	seekrange = 15
	flying = 1
	var/score = 10
	var/must_drop_loot = 0
	dead_state = "drone-dead"
	var/obj/item/droploot = null
	var/damaged = 0 // 1, 2, 3
	var/dying = 0
	var/beeptext = "beeps"
	var/beepsound = 'sound/machines/twobeep.ogg'
	var/alertsound1 = 'sound/machines/whistlealert.ogg'
	var/alertsound2 = 'sound/machines/whistlebeep.ogg'
	var/projectile_type = /datum/projectile/laser/light
	var/datum/projectile/current_projectile = new/datum/projectile/laser/light // shoot proc cleanup

	var/attack_cooldown = 30

	var/smashes_shit = 0
	var/smashed_recently = 0
	var/smash_cooldown = 200
	var/list/can_smash = list(/obj/window, /obj/grille, /obj/table, /obj/foamedmetal, /obj/rack)
	var/list/do_not_smash = list(/obj/critter, /obj/machinery/vehicle, /obj/machinery/cruiser)

	var/projectile_spread = 0


	proc/select_target(var/atom/newtarget)
		src.target = newtarget
		src.oldtarget_name = newtarget.name
		if (alertsound1 || alertsound2)
			playsound(src.loc, ismob(newtarget) ? alertsound2 : alertsound1, 55, 1)
		src.visible_message("<span style=\"color:red\"><b>[src]</b> starts chasing [src.target]!</span>")
		task = "chasing"

	Bump(atom/movable/AM)
		..()
		if(!smashes_shit) return

		if(isobj(AM))
			for(var/type in do_not_smash)
				if(istype(AM, type)) return
			var/smashed_shit = 1

			if(istype(AM, /obj/window))
				AM:health = 0
				AM:smash()
			else if(istype(AM,/obj/grille))
				AM:damage_blunt(30)
			else if(istype(AM, /obj/table))
				AM.meteorhit()
			else if(istype(AM, /obj/foamedmetal))
				AM.dispose()
			else
				AM.meteorhit()

			if(smashed_shit)
				playsound(src.loc, 'sound/effects/exlow.ogg', 70,1)
				src.visible_message("<span style=\"color:red\"><B>[src]</B> smashes into \the [AM]!</span>")


	seek_target()
		src.anchored = 0

		var/area/AR = get_area(src)
		if (AR == colosseum_controller.colosseum)
			var/list/targets = list()
			for (var/obj/machinery/colosseum_putt/C in colosseum_controller.colosseum)
				if (C.dying) continue
				targets += C
			for (var/mob/living/carbon/human/H in colosseum_controller.colosseum)
				if (isdead(H)) continue
				targets += H
			if (targets.len)
				select_target(pick(targets))
			return

		if(smashes_shit)
			//There be shit near us what can block our way.
			for (var/obj/O in oview(1,src))
				if(O.type in can_smash)
					step_towards(src,O,4) //Thugg lyfe
					break

		for (var/mob/living/C in view(src.seekrange,src))
			if (!src.alive) break
			if (C.health < 0) continue
			if (C.name == src.attacker) src.attack = 1
			if (iscarbon(C) && src.atkcarbon) src.attack = 1
			if (issilicon(C) && src.atksilicon) src.attack = 1

			if (src.attack)
				select_target(C)
				src.attack = 0
				return
			else continue


		for (var/atom in pods_and_cruisers)
			var/atom/A = atom
			if (A && src.z == A.z && get_dist(src,A) <= src.seekrange)
				if (istype(atom, /obj/machinery/vehicle))
					var/obj/machinery/vehicle/C = atom
					if (C.health < 0) continue
					if (!istype(C, /obj/machinery/vehicle/pod_smooth/syndicate)) src.attack = 1
					if (C.name == src.attacker) src.attack = 1
					src.attack = 1

					if (src.attack)
						select_target(C)
						C.threat_alert(src)
						src.attack = 0
						return
					else continue
				else if (istype(atom, /obj/machinery/cruiser))
					var/obj/machinery/cruiser/C = atom
					if (C.health < 0) continue
					if (C.name == src.attacker) src.attack = 1
					src.attack = 1

					if (src.attack)
						select_target(C)
						src.attack = 0
						return
					else continue

		if(src.atcritter)
			for (var/obj/critter/C in view(src.seekrange,src))
				if (!C.alive) break
				if (C.health < 0) continue
				if (C.name == src.attacker) src.attack = 1
				if (!istype(C, /obj/critter/gunbot)) src.attack = 1

				if (src.attack)
					select_target(C)
					src.attack = 0
					return
				else continue

	check_health()
		..()
		if(health == maxhealth) return
		var/percent_damage = src.health/src.maxhealth * 100
		switch(percent_damage)
			if(75 to 100)
				return
			if(50 to 74)
				if(damaged == 1) return
				damaged = 1
				desc = "[src] looks lightly [pick("dented", "burned", "scorched", "scratched")]."
			if(25 to 49)
				if(damaged == 2) return
				damaged = 2
				desc = "[src] looks [pick("quite", "pretty", "rather")] [pick("dented", "busted", "messed up", "burned", "scorched", "haggard")]."
			if(0 to 24)
				if(damaged == 3) return
				damaged = 3
				desc = "[src] looks [pick("really", "totally", "very", "all sorts of", "super")] [pick("mangled", "busted", "messed up", "burned", "broken", "haggard", "smashed up", "trashed")]."
		return

	CritterAttack(atom/M)
		if(target)
			src.attacking = 1
			//playsound(src.loc, "sound/machines/whistlebeep.ogg", 55, 1)
			src.visible_message("<span style=\"color:red\"><b>[src]</b> fires at [M]!</span>")

			var/tturf = get_turf(M)
			Shoot(tturf, src.loc, src)

			if(prob(20)) // break target fixation
				src.target = null
				src.last_found = world.time
				src.frustration = 0
				src.task = "thinking"
				walk_to(src,0)

			SPAWN_DBG(attack_cooldown)
				src.attacking = 0
		return


	ChaseAttack(atom/M)
		if(target)
			src.attacking = 1
			//playsound(src.loc, "sound/machines/whistlebeep.ogg", 55, 1)
			src.visible_message("<span style=\"color:red\"><b>[src]</b> fires at [M]!</span>")

			var/tturf = get_turf(M)
			Shoot(tturf, src.loc, src)

			if(prob(20))
				src.target = null
				src.last_found = world.time
				src.frustration = 0
				src.task = "thinking"
				walk_to(src,0)

			SPAWN_DBG(attack_cooldown)
				src.attacking = 0
		return

	proc/applyDeathState()
		icon_state = dead_state

	CritterDeath()
		if(dying) return
		applyDeathState()
		dying = 1 // this was dying = 0. ha ha.
		SPAWN_DBG(20)
			if (get_area(src) != colosseum_controller.colosseum || must_drop_loot)
				if (prob(25))
					new /obj/item/device/prox_sensor(src.loc)

				if(droploot)
					new droploot(src.loc)
			..()
			return

	Shoot(var/target, var/start, var/user, var/bullet = 0)
		if(target == start)
			return

		SPAWN_DBG(-1)
			if (!current_projectile)
				current_projectile = new projectile_type()
			for (var/i = 0, i < (max(1,current_projectile.shot_number)), i++) //ARRRRGHHH WHY ISNT THIS USING THE NORMAL PROJECTILE SHOT PROCS
				var/obj/projectile/A = unpool(/obj/projectile)
				if(!A)	return
				A.set_loc(src.loc)
				A.proj_data = current_projectile
				A.proj_data.master = A
				A.set_icon()
				A.power = A.proj_data.power
				if(src.current_projectile.shot_sound)
					playsound(src, src.current_projectile.shot_sound, 60)

				if (!istype(target, /turf))
					A.die()
					return
				A.target = target

				if(istype(target, /obj/machinery/cruiser))
					A.yo = (target:y + 2) - start:y
					A.xo = (target:x + 2) - start:x
				else
					A.yo = target:y - start:y
					A.xo = target:x - start:x


				if (projectile_spread)
					if (projectile_spread < 0)
						projectile_spread = -projectile_spread
					var/spread = rand(projectile_spread * 10) / 10
					A.rotateDirection(prob(50) ? spread : -spread)

				A.shooter = src
				src.dir = get_dir(src, target)
				SPAWN_DBG( 0 )
					A.process()

				if (current_projectile.shot_delay)
					sleep(current_projectile.shot_delay)
		return

	process() // override so drones don't just loaf all fuckin day
		if (!src.alive) return 0

		if(sleeping > 0)
			sleeping--
			return 0

		check_health()

		if(prob(7))
			src.visible_message("<b>[src] [beeptext].</b>")
			if (beepsound)
				playsound(src, beepsound, 55, 1)

		if(task == "following path")
			follow_path()
		else if(task == "sleeping")
			var/waking = 0

			for (var/client/C)
				var/mob/M = C.mob
				if (M && src.z == M.z && get_dist(src,M) <= 10)
					if (isliving(M))
						waking = 1
						break

			//for(var/mob/living/M in view(10, src))
			//	if(M.client)
			//		waking = 1
			//		break

			for (var/atom in pods_and_cruisers)
				var/atom/A = atom
				if (A && src.z == A.z && get_dist(src,A) <= 10)
					waking = 1
					break

			//for(var/obj/machinery/M in view(10, src))
			//	if (istype(M,/obj/machinery/vehicle) || istype(M,/obj/machinery/cruiser))
			//		waking = 1
			//		break


			if (!waking)
				if (get_area(src) == colosseum_controller.colosseum)
					waking = 1

			if(waking)
				task = "thinking"
			else
				sleeping = 5
				return 0
		else if(sleep_check <= 0)
			sleep_check = 5

			var/stay_awake = 0

			for (var/client/C)
				var/mob/M = C.mob
				if (M && src.z == M.z && get_dist(src,M) <= 10)
					if (isliving(M))
						stay_awake = 1
						break

			//for(var/mob/living/M in view(10, src))
			//	if(M.client)
			//		stay_awake = 1
			//		break

			for (var/atom in pods_and_cruisers)
				var/atom/A = atom
				if (A && src.z == A.z && get_dist(src,A) <= 10)
					stay_awake = 1
					break

			//for(var/obj/machinery/M in view(10, src))
			//	if (istype(M,/obj/machinery/vehicle) || istype(M,/obj/machinery/cruiser))
			//		stay_awake = 1
			//		break

			if(!stay_awake)
				sleeping = 5
				task = "sleeping"
				return 0

		else
			sleep_check--

		return ai_think()

	ai_think() // more dumb overrides, fuckin lazy critters
		switch(task)
			if("thinking")
				src.attack = 0
				src.target = null

				walk_to(src,0)
				if (src.aggressive) seek_target()
				if (src.wanderer && !src.target) src.task = "wandering"
			if("chasing")
				if (src.frustration >= rand(20,40))
					src.target = null
					src.last_found = world.time
					src.frustration = 0
					src.task = "thinking"
					walk_to(src,0)
				if (target)
					if (get_dist(src, src.target) <= 7)
						var/mob/living/carbon/M = src.target
						if (M)
							if(!src.attacking) ChaseAttack(M)
							src.task = "attacking"
							src.anchored = 1
							src.target_lastloc = M.loc
							if(prob(15)) walk_rand(src,4) // juke around and dodge shots

					else
						var/turf/olddist = get_dist(src, src.target)

						if(smashes_shit) //Break another thing near the drone
							//There be shit near us what can block our way.
							for (var/obj/O in view(1,src))
								if(O.type in can_smash)
									step_towards(src,O,4) //Thugg lyfe
									break

						if(prob(20)) walk_rand(src,4) // juke around and dodge shots
						/*else if(smashes_shit && !smashed_recently && prob(20) && target in ohearers(src,src.seekrange) ) //RAM THE FUCKER! Or not. This sucks. Bad idea.
							smashed_recently = 1
							SPAWN_DBG(smash_cooldown)
								smashed_recently = 0

							walk_towards(src, src.target, 1, 4)*/
						else walk_to(src, src.target,1,4)

						if ((get_dist(src, src.target)) >= (olddist))
							src.frustration++

						else
							src.frustration = 0
				else src.task = "thinking"
			if("attacking")
				if(prob(15)) walk_rand(src,4) // juke around and dodge shots
				// see if he got away
				if ((get_dist(src, src.target) > 1) || ((src.target:loc != src.target_lastloc)))
					src.anchored = 0
					src.task = "chasing"
				else
					if (get_dist(src, src.target) <= 1)
						var/mob/living/carbon/M = src.target
						if (!src.attacking) CritterAttack(src.target)
						if (!src.aggressive)
							src.task = "thinking"
							src.target = null
							src.anchored = 0
							src.last_found = world.time
							src.frustration = 0
							src.attacking = 0
						else
							if(M!=null)
								if (M.health < 0)
									src.task = "thinking"
									src.target = null
									src.anchored = 0
									src.last_found = world.time
									src.frustration = 0
									src.attacking = 0
					else
						src.anchored = 0
						src.attacking = 0
						src.task = "chasing"
			if("wandering")
				patrol_step()
		return 1

	glitchdrone
		name = "Syndic<t@ Ar%#i§lÜrr D²o-|"
		desc = "A highly dÄ:;g$r+us $yn§i#a{e $'+~`?? ???? ? ???? ??"
		icon_state = "glitchdrone"
		health = 8000
		maxhealth = 8000
		score = 9000
		dead_state = "drone5-dead"
		alertsound1 = 'sound/machines/glitch1.ogg'
		alertsound2 = 'sound/machines/glitch2.ogg'
		droploot = /obj/bomberman
		projectile_type = /datum/projectile/bullet/glitch
		current_projectile = new/datum/projectile/bullet/glitch

		New()
			..()
			name = "Dr~n³ *§#-[rand(1,999)]"
			return

	New()
		..()
		name = "Drone SC-[rand(1,999)]"
		return

	heavydrone
		name = "Syndicate Hunter-Killer Drone"
		desc = "A heavily-armed Syndicate hunter-killer drone."
		icon_state = "drone2"
		health = 250
		maxhealth = 250
		score = 50
		dead_state = "drone2-dead"
		droploot = /obj/item/gun/energy/phaser_gun
		projectile_type = /datum/projectile/disruptor/high
		current_projectile = new/datum/projectile/disruptor/high
		attack_cooldown = 40
		New()
			..()
			name = "Drone HK-[rand(1,999)]"
			return

	virtual
		applyDeathState()
			overlays += image('icons/obj/ship.dmi', "dying-overlay")

		laserdrone
			name = "Virtual Laser Drone"
			desc = "An alarmingly well-equipped but relatively fragile virtual drone."
			icon_state = "vrdrone_red"
			health = 100
			maxhealth = 100
			score = 30
			dead_state = "vrdrone_red"
			projectile_type = /datum/projectile/laser
			current_projectile = new/datum/projectile/laser

			New()
				..()
				name = "Drone LZ-[rand(1,999)]"

		cutterdrone
			name = "Virtual Plasma Cutter Drone"
			desc = "A virtual copy of the classic PC series mining drones, now primarily used to cut people in half instead of asteroids."
			icon_state = "vrdrone_orange"
			health = 150
			maxhealth = 150
			score = 40
			dead_state = "vrdrone_orange"
			projectile_type = /datum/projectile/laser/mining
			current_projectile = new/datum/projectile/laser/mining

			New()
				..()
				name = "Drone PC-[rand(1,999)]"

		assdrone // HEH
			name = "Virtual Assault Drone"
			desc = "This is a digital reconstruction of the BR-series breach drones employed by Nanotransen in space extraction and destruction missions."
			icon_state = "vrdrone_blue"
			health = 150
			maxhealth = 150
			score = 60
			dead_state = "vrdrone_blue"
			projectile_type = /datum/projectile/laser/asslaser
			current_projectile = new/datum/projectile/laser/asslaser

			New()
				..()
				name = "Drone BR-[rand(1,999)]"

		aciddrone
			name = "Virtual Acid Drone"
			desc = "This is a digital reconstruction of the CA-series concentrated acid breach drones, the planetary mission counterpart to the robustness of the BR-series assault drones."
			icon_state = "vrdrone_green"
			health = 250
			maxhealth = 250
			score = 80
			dead_state = "vrdrone_green"
			projectile_type = /datum/projectile/special/acid
			current_projectile = new/datum/projectile/special/acid

			New()
				..()
				name = "Drone CA-[rand(1,999)]"

	cannondrone
		name = "Syndicate Artillery Drone"
		desc = "A highly dangerous Syndicate drone equipped with a miniaturized artillery system."
		icon_state = "drone5"
		health = 200
		maxhealth = 200
		score = 120
		dead_state = "drone5-dead"
		alertsound1 = 'sound/machines/engine_alert1.ogg'
		alertsound2 = 'sound/machines/engine_alert1.ogg'
		droploot = /obj/item/shipcomponent/secondary_system/crash
		projectile_type = /datum/projectile/bullet/aex
		current_projectile = new/datum/projectile/bullet/aex
		attack_cooldown = 50
		New()
			..()
			name = "Drone AR-[rand(1,999)]"
			return

	minigundrone
		name = "Syndicate BL Drone"
		desc = "A Syndicate drone equipped with a ballistic weapon."
		icon_state = "droneMG"
		health = 200
		maxhealth = 200
		score = 120
		dead_state = "droneMG-dead"
		alertsound1 = 'sound/machines/engine_alert1.ogg'
		alertsound2 = 'sound/machines/engine_alert1.ogg'
		droploot = /obj/item/bang_gun
		projectile_type = /datum/projectile/bullet/ak47
		current_projectile = new/datum/projectile/bullet/ak47
		attack_cooldown = 20
		New()
			..()
			name = "Drone BML-[rand(1,999)]"
			return

	raildrone // a real jerk
		name = "Syndicate Railgun Drone"
		desc = "An experimental and extremely dangerous Syndicate railgun drone."
		icon_state = "drone3"
		health = 800
		maxhealth = 800
		score = 500
		dead_state = "drone3-dead"
		droploot = /obj/item/spacecash/buttcoin // replace with railgun if that's ever safe enough to hand out? idk
		attack_cooldown = 50
		smashes_shit = 1

		Shoot(var/atom/target, var/start, var/user, var/bullet = 0)
			if(target == start)
				return
			playsound(src, "sound/effects/mag_warp.ogg", 50, 1)
			SPAWN_DBG(rand(1,3)) // so it might miss, sometimes, maybe
				var/obj/target_r

				if(istype(target, /obj/machinery/cruiser))
					target_r = new/obj/railgun_trg_dummy(locate(target.x+2, target.y+2, target.z))
				else
					target_r = new/obj/railgun_trg_dummy(target)

				playsound(src, "sound/weapons/railgun.ogg", 50, 1)
				src.dir = get_dir(src, target)

				var/list/affected = DrawLine(src, target_r, /obj/line_obj/railgun ,'icons/obj/projectiles.dmi',"WholeRailG",1,1,"HalfStartRailG","HalfEndRailG",OBJ_LAYER,1)

				for(var/obj/O in affected)
					O.anchored = 1 //Proc wont spawn the right object type so lets do that here.
					O.name = "Energy"
					var/turf/src_turf = O.loc
					for(var/obj/machinery/vehicle/A in src_turf)
						if(A == O || A == user) continue
						A.meteorhit(O)
					for(var/mob/living/M in src_turf)
						if(M == O || M == user) continue
						M.meteorhit(O)
					for(var/turf/T in src_turf)
						if(T == O) continue
						T.meteorhit(O)
					for(var/obj/machinery/colosseum_putt/A in src_turf)
						if (A == O || A == user) continue
						A.meteorhit(O)
					for (var/obj/machinery/cruiser/C in src_turf)
						if (C == O || C == user) continue
						C.meteorhit(O)

		//			var/turf/T = O.loc
		//			for(var/atom/A in T.contents)
		//				boutput(src, "There is a [A.name] at this location.")
					SPAWN_DBG(3) pool(O)

				if(istype(target_r, /obj/railgun_trg_dummy)) qdel(target_r)
			return

		New()
			..()
			name = "Drone X-[rand(1,999)]"
			return

	buzzdrone
		name = "Syndicate Salvage Drone"
		desc = "A Syndicate scrap cutter drone, designed for automated salvage operations."
		icon_state = "drone4"
		health = 200
		maxhealth = 200
		score = 20
		dead_state = "drone4-dead"
		droploot = /obj/item/circular_saw
		projectile_type = /datum/projectile/laser/drill/cutter
		current_projectile = new/datum/projectile/laser/drill/cutter
		smashes_shit = 1

		ChaseAttack(atom/M)
			if(target && !attacking)
				attacking = 1
				src.visible_message("<span style=\"color:red\"><b>[src]</b> charges at [M]!</span>")
				walk_to(src, src.target,1,4)
				var/tturf = get_turf(M)
				Shoot(tturf, src.loc, src)
				SPAWN_DBG(attack_cooldown)
					attacking = 0
			return

		CritterAttack(atom/M)
			if(target && !attacking)
				attacking = 1
				//playsound(src.loc, "sound/machines/whistlebeep.ogg", 55, 1)
				src.visible_message("<span style=\"color:red\"><b>[src]</b> hits [M]!</span>")

				var/tturf = get_turf(M)
				Shoot(tturf, src.loc, src)
				SPAWN_DBG(attack_cooldown)
					attacking = 0
			return

		New()
			..()
			name = "Drone CR-[rand(1,999)]"
			return

		fish
			name = "Syndicate FishDrone"
			desc = "A Syndicate robo-fish. This appears to be a continuation of the scrap cutter production line made for underwater use."
			icon = 'icons/misc/critter.dmi'
			icon_state = "piranha_robo"
			dead_state = "piranha_robo-dead"
			health = 100
			maxhealth = 100
			score = 10
			droploot = /obj/item/saw
			projectile_type = /datum/projectile/laser/drill/saw_teeth
			current_projectile = new/datum/projectile/laser/drill/saw_teeth
			smashes_shit = 0
			//TODO : TEENSY REDRAW TO ICON TO MAKE IT A LITTLE MORE ROBOTTY

			New()
				..()
				name = "FishDrone CR-[rand(1,999)]b"
				return
				applyDeathState()
				overlays += image('icons/obj/ship.dmi', "dying-overlay")


			CritterDeath() //Yeah thanks for only supporting a single item, loot variable.
				if(dying) return
				new/obj/item/mining_tool(src.loc)
				..()

	gunshark
		name = "Syndicate GunShark"
		desc = "A Syndicate robo-shark. Watch out for that minigun!"
		icon = 'icons/misc/64x32.dmi'
		icon_state = "gunshark"
		health = 220
		maxhealth = 220
		score = 80
		bound_height = 32
		bound_width = 64
		dead_state = "gunshark-dead"
		alertsound1 = 'sound/machines/engine_alert1.ogg'
		alertsound2 = 'sound/machines/engine_alert1.ogg'
		droploot = /obj/item/ammo/bullets/lmg/weak
		projectile_type = /datum/projectile/bullet/lmg/weak
		current_projectile = new/datum/projectile/bullet/lmg/weak
		attack_cooldown = 20
		projectile_spread = 13

		New()
			..()
			name = "SharkDrone BML-[rand(1,999)]b"
			return



	laserdrone
		name = "Laser Drone"
		desc = "A Syndicate drone equipped with a combat laser."
		icon_state = "vrdrone_red"
		health = 100
		maxhealth = 100
		score = 30
		dead_state = "vrdrone_red"
		projectile_type = /datum/projectile/laser
		current_projectile = new/datum/projectile/laser

		New()
			..()
			name = "Drone LZ-[rand(1,999)]"

	cutterdrone
		name = "Plasma Cutter Drone"
		desc = "An industrial mining drone, repurposed by Syndicate engineers for nefarious purposes."
		icon_state = "vrdrone_orange"
		health = 150
		maxhealth = 150
		score = 50
		dead_state = "vrdrone_orange"
		projectile_type = /datum/projectile/laser/mining
		current_projectile = new/datum/projectile/laser/mining

		New()
			..()
			name = "Drone PC-[rand(1,999)]"

	assdrone // HEH
		name = "Breach Drone"
		desc = "A highly dangerous Syndicate drone built for extraction and sabotage operations."
		icon_state = "vrdrone_blue"
		health = 150
		maxhealth = 150
		score = 100
		dead_state = "vrdrone_blue"
		projectile_type = /datum/projectile/laser/asslaser
		current_projectile = new/datum/projectile/laser/asslaser

		New()
			..()
			name = "Drone BR-[rand(1,999)]"

	aciddrone
		name = "Acid Drone"
		desc = "This Syndicate drone is equipped with a corrosive chemical weapon. Rude!"
		icon_state = "vrdrone_green"
		health = 200
		maxhealth = 200
		score = 65
		dead_state = "vrdrone_green"
		projectile_type = /datum/projectile/special/acid
		current_projectile = new/datum/projectile/special/acid

		New()
			..()
			name = "Drone CA-[rand(1,999)]"


	helldrone // the worst jerk
		name = "Syndicate Command Drone"
		desc = "An enormous automated Syndicate battledrone, likely responsible for the loss of several NT facilities in this sector."
		health = 5000
		maxhealth = 5000
		icon = 'icons/effects/96x96.dmi'
		icon_state = "battledrone"
		bound_height = 96
		bound_width = 96
		score = 10000
		dead_state = "battledrone-dead"
		droploot = /obj/item/plutonium_core
		alertsound1 = 'sound/machines/engine_alert2.ogg'
		alertsound2 = 'sound/machines/engine_alert3.ogg'
		projectile_type = /datum/projectile/bullet/autocannon/plasma_orb
		current_projectile = new/datum/projectile/bullet/autocannon/plasma_orb
		attack_cooldown = 70
		smashes_shit = 1

		CritterDeath() //Yeah thanks for only supporting a single item, loot variable.
			if(dying) return
			var/area/A = get_area(src)
			if (A && A.virtual)
				droploot = null
			..()

		process()
			..()
			if(prob(3))
				playsound(src,"sound/machines/signal.ogg", 60, 0)
			return



		Shoot(var/target, var/start, var/user, var/bullet = 0)
			if(target == start)
				return


			src.dir = get_dir(src, target)

			var/obj/projectile/P1 =	new/obj/projectile(src.loc)
			var/obj/projectile/P2 =	new/obj/projectile(src.loc)
			P1.proj_data = new current_projectile.type
			P2.proj_data = new current_projectile.type
			P1.set_icon()
			P2.set_icon()
			P1.shooter = src
			P2.shooter = src
			P1.target = target
			P2.target = target
			if(src.current_projectile.shot_sound)
				playsound(src.loc, src.current_projectile.shot_sound, 60)

			switch(src.dir) // linked fire, directional offsets so they don't hit the ship itself // these need more work still
				if(NORTH)
					P1.yo = 96
					P1.xo = 0
					P2.yo = 96
					P2.xo = 0
					P1.set_loc(locate(src.x, src.y+2, src.z))
					P2.set_loc(locate(src.x+2,src.y+2, src.z))
				if(EAST)
					P1.yo = 0
					P1.xo = 96
					P2.yo = 0
					P2.xo = 96
					P1.set_loc(locate(src.x+2,src.y+2,src.z))
					P2.set_loc(locate(src.x+2,src.y,src.z))
				if(WEST)
					P1.yo = 0
					P1.xo = -96
					P2.yo = 0
					P2.xo = -96
					P1.set_loc(locate(src.x,src.y, src.z))
					P2.set_loc(locate(src.x,src.y+2, src.z))
				else
					P1.yo = -96
					P1.xo = 0
					P2.yo = -96
					P2.xo = 0
					P1.set_loc(locate(src.x+2,src.y, src.z))
					P2.set_loc(locate(src.x, src.y, src.z))

			SPAWN_DBG(0)
				P1.process()
			SPAWN_DBG(0)
				P2.process()

			return

		New()
			..()
			name = "Battledrone Omega-[rand(1,10)]"
			return

/obj/critter/gunbot/drone/iridium // the worstest jerk, even worse than the previous worst jerk.
	name = "Y-Class Battledrone"
	desc = "One of the prototype battledrones from the Syndicate's PROJECT IRIDIUM, utilizing adapted artifact technologies."
	health = 6000
	maxhealth = 6000
	icon = 'icons/effects/96x96.dmi'
	icon_state = "ydrone"
	bound_height = 96
	bound_width = 96
	score = 10000
	must_drop_loot = 1
	dead_state = "ydrone-dead"
	droploot = /obj/item/device/key/iridium
	alertsound1 = 'sound/machines/engine_alert2.ogg'
	alertsound2 = 'sound/machines/engine_alert3.ogg'
	projectile_type = /datum/projectile/laser/precursor/sphere
	current_projectile = new/datum/projectile/laser/precursor/sphere
	smashes_shit = 1
	attack_cooldown = 70
	process()
		..()
		if(prob(3))
			playsound(src,"sound/machines/signal.ogg", 60, 0)

		return


	Shoot(var/target, var/start, var/user, var/bullet = 0)
		if(target == start)
			return

		if (prob(10))
			elec_zap()

		/*
		var/obj/projectile/A = unpool(/obj/projectile)
		if(!A)	return
		A.set_loc(src.loc)
		A.projectile = new current_projectile.type
		A.projectile.master = A
		A.set_icon()
		if(src.current_projectile.shot_sound)
			playsound(src, src.current_projectile.shot_sound, 60)


		if(!A)	return

		if (!istype(target, /turf))
			A.die()
			return
		A.target = target
		A.yo = target:y - start:y
		A.xo = target:x - start:x
		src.dir = get_dir(src, target)
		SPAWN_DBG( 0 )
			A.process()
		return */

		src.dir = get_dir(src, target)

		var/obj/projectile/P1 = unpool(/obj/projectile/precursor_sphere)
		var/obj/projectile/P2 = unpool(/obj/projectile/precursor_sphere)
		P1.loc = src.loc
		P2.loc = P1.loc
		P1.proj_data = new current_projectile.type
		P2.proj_data = new current_projectile.type
		P1.power = P1.proj_data.power
		P2.power = P2.proj_data.power
		P1.set_icon()
		P2.set_icon()
		P1.shooter = src
		P2.shooter = src
		P1.target = target
		P2.target = target
		if(src.current_projectile.shot_sound)
			playsound(src.loc, src.current_projectile.shot_sound, 60)

		switch(src.dir) // linked fire, directional offsets so they don't hit the ship itself // these need more work still
			if(NORTH)
				P1.yo = 96
				P1.xo = 0
				P2.yo = 96
				P2.xo = 0
				P1.set_loc(locate(src.x, src.y+2, src.z))
				P2.set_loc(locate(src.x+2,src.y+2, src.z))
			if(EAST)
				P1.yo = 0
				P1.xo = 96
				P2.yo = 0
				P2.xo = 96
				P1.set_loc(locate(src.x+2,src.y+2,src.z))
				P2.set_loc(locate(src.x+2,src.y,src.z))
			if(WEST)
				P1.yo = 0
				P1.xo = -96
				P2.yo = 0
				P2.xo = -96
				P1.set_loc(locate(src.x,src.y, src.z))
				P2.set_loc(locate(src.x,src.y+2, src.z))
			else
				P1.yo = -96
				P1.xo = 0
				P2.yo = -96
				P2.xo = 0
				P1.set_loc(locate(src.x+2,src.y, src.z))
				P2.set_loc(locate(src.x, src.y, src.z))

		SPAWN_DBG(0)
			P1.process()
		SPAWN_DBG(0)
			P2.process()


	proc/elec_zap()
		playsound(src, "sound/effects/elec_bigzap.ogg", 40, 1)

		var/list/lineObjs
		for (var/mob/living/poorSoul in range(src, 5))
			lineObjs += DrawLine(src, poorSoul, /obj/line_obj/elec, 'icons/obj/projectiles.dmi',"WholeLghtn",1,1,"HalfStartLghtn","HalfEndLghtn",FLY_LAYER,1,PreloadedIcon='icons/effects/LghtLine.dmi')

			poorSoul << sound('sound/effects/electric_shock.ogg', volume=50)
			random_burn_damage(poorSoul, 45)
			boutput(poorSoul, "<span style=\"color:red\"><B>You feel a powerful shock course through your body!</B></span>")
			poorSoul.unlock_medal("HIGH VOLTAGE", 1)
			poorSoul:Virus_ShockCure(poorSoul, 100)
			poorSoul:shock_cyberheart(100)
			poorSoul:changeStatus("weakened", 4 SECONDS)
			if (isdead(poorSoul) && prob(25))
				poorSoul.gib()

		for (var/obj/machinery/vehicle/poorPod in range(src, 5))
			lineObjs += DrawLine(src, poorPod, /obj/line_obj/elec, 'icons/obj/projectiles.dmi',"WholeLghtn",1,1,"HalfStartLghtn","HalfEndLghtn",FLY_LAYER,1,PreloadedIcon='icons/effects/LghtLine.dmi')

			playsound(poorPod.loc, "sound/effects/elec_bigzap.ogg", 40, 0)
			poorPod.ex_act(3)

		for (var/obj/machinery/colosseum_putt/poorPod in range(src, 5))
			lineObjs += DrawLine(src, poorPod, /obj/line_obj/elec, 'icons/obj/projectiles.dmi',"WholeLghtn",1,1,"HalfStartLghtn","HalfEndLghtn",FLY_LAYER,1,PreloadedIcon='icons/effects/LghtLine.dmi')

			playsound(poorPod.loc, "sound/effects/elec_bigzap.ogg", 40, 0)
			poorPod.ex_act(3)

		for (var/obj/machinery/cruiser/C in range(src, 5))
			lineObjs += DrawLine(src, C, /obj/line_obj/elec, 'icons/obj/projectiles.dmi',"WholeLghtn",1,1,"HalfStartLghtn","HalfEndLghtn",FLY_LAYER,1,PreloadedIcon='icons/effects/LghtLine.dmi')
			playsound(C.loc, "sound/effects/elec_bigzap.ogg", 40, 0)
			C.ex_act(3)

		SPAWN_DBG(6)
			for (var/obj/O in lineObjs)
				pool(O)


	New()
		..()
		name = "Battledrone Y-[rand(1,5)]"
		return

	CritterDeath() //Yeah thanks for only supporting a single item, loot variable.
		if(dying) return
		var/area/A = get_area(src)
		if (A && A.virtual)
			droploot = /obj/item/device/key/virtual
		else
			new/obj/item/material_piece/iridiumalloy(src.loc)
		..()

/obj/critter/gunbot/drone/iridium/whydrone
	name = "Battledronì4?½&?aÄ	ÏbçÇ~¥D??õ®×³?£"
	desc = "Run."
	health = 5000
	maxhealth = 5000 // per stage
	var/stage = 0
	icon = 'icons/effects/96x96.dmi'
	icon_state = "ydrone"
	bound_height = 96
	bound_width = 96
	attack_range = 7
	score = 1500
	dead_state = "ydrone-dead"
	droploot = /obj/item/device/key/iridium
	alertsound1 = 'sound/machines/glitch3.ogg'
	alertsound2 = 'sound/machines/glitch3.ogg'
	projectile_type = /datum/projectile/bullet/autocannon/huge
	current_projectile = new/datum/projectile/bullet/autocannon/huge
	var/datum/projectile/sphere_projectile = new/datum/projectile/laser/precursor/sphere
	generic = 0
	smashes_shit = 1

	New()
		..()
		name = "Battledronì4?½&?aÄ	ÏbçÇ~¥D??õ®×³?£-[rand(1,5)]"

	// copied and modified to fuck from the Y-drone, murder me
	Shoot(var/target, var/start, var/user, var/bullet = 0)
		if(target == start)
			return

		if (prob(50))
			elec_zap()

		src.dir = get_dir(src, target)

		var/obj/projectile/sphere = unpool(/obj/projectile/precursor_sphere)
		sphere.loc = src.loc
		sphere.proj_data = new sphere_projectile.type
		sphere.set_icon()
		sphere.shooter = src
		sphere.target = target
		if(src.current_projectile.shot_sound)
			playsound(src.loc, src.current_projectile.shot_sound, 60)

		switch(src.dir)
			if(NORTH)
				sphere.yo = 96
				sphere.xo = 0
				sphere.set_loc(locate(src.x, src.y+2, src.z))
			if(EAST)
				sphere.yo = 0
				sphere.xo = 96
				sphere.set_loc(locate(src.x+2,src.y+2,src.z))
			if(WEST)
				sphere.yo = 0
				sphere.xo = -96
				sphere.set_loc(locate(src.x,src.y, src.z))
			else
				sphere.yo = -96
				sphere.xo = 0
				sphere.set_loc(locate(src.x+2,src.y, src.z))

		SPAWN_DBG(0)
			sphere.process()

		if (bounds_dist(src, target) >= 2*32) // dont murder ourself with explosives
			var/obj/projectile/P1 = unpool(/obj/projectile)
			var/obj/projectile/P2 = unpool(/obj/projectile)
			P1.loc = sphere.loc
			P2.loc = sphere.loc
			P1.proj_data = new current_projectile.type
			P2.proj_data = new current_projectile.type
			P1.set_icon()
			P2.set_icon()
			P1.shooter = src
			P2.shooter = src
			P1.target = target
			P2.target = target

			P1.yo = sphere.yo
			P1.xo = sphere.xo
			P1.set_loc(sphere.loc)
			P2.yo = sphere.yo
			P2.xo = sphere.xo
			P2.set_loc(sphere.loc)

			SPAWN_DBG(0)
				P1.process()
			SPAWN_DBG(0)
				P2.process()


	/*proc/elec_zap()
		playsound(src, "sound/effects/elec_bigzap.ogg", 40, 1)

		var/list/lineObjs
		for (var/mob/living/poorSoul in range(src, 5))
			lineObjs += DrawLine(src, poorSoul, /obj/line_obj/elec, 'icons/obj/projectiles.dmi',"WholeLghtn",1,1,"HalfStartLghtn","HalfEndLghtn",FLY_LAYER,1,PreloadedIcon='icons/effects/LghtLine.dmi')

			poorSoul << sound('sound/effects/electric_shock.ogg', volume=50)
			random_burn_damage(poorSoul, 45)
			boutput(poorSoul, "<span style=\"color:red\"><B>You feel a powerful shock course through your body!</B></span>")
			poorSoul.unlock_medal("HIGH VOLTAGE", 1)
			poorSoul:Virus_ShockCure(poorSoul, 100)
			poorSoul:shock_cyberheart(100)
			poorSoul:weakened += rand(3,5)
			if (isdead(poorSoul) && prob(25))
				poorSoul.gib()

		for (var/obj/machinery/vehicle/poorPod in range(src, 5))
			lineObjs += DrawLine(src, poorPod, /obj/line_obj/elec, 'icons/obj/projectiles.dmi',"WholeLghtn",1,1,"HalfStartLghtn","HalfEndLghtn",FLY_LAYER,1,PreloadedIcon='icons/effects/LghtLine.dmi')

			playsound(poorPod.loc, "sound/effects/elec_bigzap.ogg", 40, 0)
			poorPod.ex_act(3)

		SPAWN_DBG(6)
			for (var/obj/O in lineObjs)
				pool(O)*/

/obj/critter/gunbot/drone/iridium/whydrone/horse
	name = "Horseman"
	desc = "What the hell is this thing!? Oh God, is that a MOUTH?"
	health = 8000 //glitch drone tough
	maxhealth = 8000 // you aren't killing the apocalypse easily
	icon = 'icons/effects/96x96.dmi'
	icon_state = "horsedrone"
	bound_height = 96
	bound_width = 96
	attack_range = 14
	score = 45000
	dead_state = "horsedrone-dead"
	droploot = /obj/item/clothing/mask/horse_mask/cursed
	beeptext = "neighs"
	beepsound = 'sound/vox/na.ogg' //how is nay or neigh not a thing in vox?
	alertsound1 = 'sound/effects/mag_pandroar.ogg'
	alertsound2 = 'sound/voice/animal/wendigo_roar.ogg'
	projectile_type = /datum/projectile/bullet/autocannon/huge
	current_projectile = new/datum/projectile/bullet/autocannon/huge
	sphere_projectile = new/datum/projectile/laser/precursor/sphere
	generic = 0
	smashes_shit = 1

	process()
		..()
		if(prob(3))
			playsound(src,"sound/effects/heartbeat.ogg", 60, 0) //for the spooky effect
		return

	New()
		..()
		name = "[pick("War", "Death", "Pestilence", "Famine")]"

	ex_act(severity)
		return //immune to our own explosions

	check_health()
		..()
		if(health == maxhealth) return
		var/percent_damage = src.health/src.maxhealth * 100
		switch(percent_damage)
			if(75 to 100)
				return
			if(50 to 74)
				if(damaged == 1) return
				damaged = 1
				desc = "[src] looks lightly [pick("injured", "hurt", "bruised", "cut")]."
			if(25 to 49)
				if(damaged == 2) return
				damaged = 2
				desc = "[src] looks [pick("quite", "pretty", "rather")] [pick("injured", "wounded", "messed up", "beaten up", "hurt", "haggard")]."
			if(0 to 24)
				if(damaged == 3) return
				damaged = 3
				desc = "[src] looks [pick("really", "totally", "very", "all sorts of", "super", "grievously")] [pick("mangled", "wounded", "messed up", "injured", "hurt", "haggard", "beaten down", "bloodied")]."
		return

	CritterDeath() //Yeah thanks for only supporting a single item, loot variable.
		if(dying) return
		var/area/A = get_area(src)
		if (A && A.virtual)
			droploot = /obj/item/device/key/virtual //we don't want this loot in vr do we???
		else
			new/obj/item/instrument/fiddle(src.loc)
			new/obj/item/instrument/trumpet/dootdoot(src.loc)
			new/obj/item/rubber_hammer(src.loc)
			new/obj/item/instrument/bagpipe(src.loc)
			new/obj/item/storage/belt/macho_belt(src.loc)
			new/obj/item/stimpack/large_dose(src.loc)
			new/obj/item/stimpack/large_dose(src.loc)
			new/obj/item/stimpack/large_dose(src.loc)
			new/obj/item/stimpack/large_dose(src.loc)
			new/obj/item/stimpack/large_dose(src.loc)
		..()


/obj/critter/gunbot/drone/miniature_syndie
	name = "miniature Syndicate Operative"
	desc = "They look determined."
	icon = 'icons/misc/critter.dmi'
	icon_state = "minisyndie"
	density = 1
	health = 5
	maxhealth = 5 // for damage description
	aggressive = 1
	defensive = 1
	wanderer = 1
	opensdoors = 1
	atkcarbon = 1
	atksilicon = 1
	atcritter = 0
	firevuln = 0.5
	brutevuln = 1
	miscvuln = 0
	luminosity = 0
	seekrange = 15
	flying = 1
	dead_state = "minisyndie-dead"
	beeptext = "prepares to finish the fight!"
	beepsound = 0
	alertsound1 = 0

	alertsound2 = 0
	projectile_type = /datum/projectile/bullet/revolver_357
	current_projectile = new/datum/projectile/bullet/revolver_357
	attack_cooldown = 20

	var/voice_gender = "male"

	New()
		..()
		voice_gender = pick("male","female")
		name = "miniature Syndicate Operative"

	select_target(var/atom/newtarget)
		..()
		playsound(get_turf(src), (voice_gender == "male" ? "sound/voice/screams/male_scream.ogg" : "sound/voice/screams/female_scream.ogg"), 40, 1, 0.1, 3)

	ex_act(severity)
		return

	CritterDeath()
		if(dying) return
		playsound(get_turf(src), 'sound/voice/farts/poo2.ogg', 40, 1, 0.1, 3)
		src.visible_message("[src] emits a very small clicking noise.")
		icon_state = dead_state
		SPAWN_DBG(5)
			explosion(src, get_turf(src), -1, -1, 2, 3)
		..()

	Shoot(var/target, var/start, var/user, var/bullet = 0)
		..()
		SPAWN_DBG(5)
			task = "sleeping"
			src.health = 0
			src.CritterDeath()