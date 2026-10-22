extends Node

const GAME := preload("res://games/Patintero/Scenes/main.tscn")
const GUARD := preload("res://games/Patintero/Scripts/platform.gd")
const PLAYER := preload("res://games/Patintero/Scenes/player.tscn")
const UPPER_GUARDS := ["Platform", "Platform4", "Platform7", "Platform6"]
const LOWER_GUARDS := ["Platform2", "Platform5", "Platform8", "Platform3"]
const RUNNER_YS := [119.0, 257.0, 387.0, 527.0]
const LANE_XS := [264.0, 530.0, 803.0, 972.0]
const STEP := 1.0 / 60.0

class TestRunner extends CharacterBody2D:
	var hits := 0

	func _ready() -> void:
		add_to_group(&"patintero_players")

	func _get_hit() -> void:
		hits += 1

var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_profiles_and_detection()
	await get_tree().physics_frame
	await _test_patrol_variation()
	await _test_committed_blocks()
	await _test_openings_and_tags()
	await _test_dash_recharge()
	await _test_player_impact_feedback()
	await _test_timed_dashes()
	var trials := [
		{"delay": 0.0, "seed": 104729},
		{"delay": 0.65, "seed": 130363},
		{"delay": 1.3, "seed": 155921},
	]
	var total_tags := 0
	var tagged_runners := 0
	for trial in trials:
		var result := await _measure_held_crossing(trial.delay, trial.seed)
		total_tags += result.tags
		tagged_runners += result.tagged_runners
	_check(total_tags >= 60 and tagged_runners >= 9, "Hard guards apply sustained pressure to untimed approaches across randomized courts")
	var mashed_tagged_runners := 0
	var mashed_clean_finishes := 0
	for trial in trials:
		var result := await _measure_held_crossing(trial.delay, trial.seed, true)
		mashed_tagged_runners += result.tagged_runners
		mashed_clean_finishes += result.clean_finishes
	_check(mashed_tagged_runners >= 9 and mashed_clean_finishes <= 2, "Repeated double-tapping gets intercepted across randomized full-court runs")
	print("PATINTERO GUARDS: %d failure(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_profiles_and_detection() -> void:
	var court := GAME.instantiate() as Node2D
	court.position = Vector2(140.0, 75.0)
	court.scale = Vector2(1.2, 0.9)
	add_child(court)
	_seed_court(court, 541)
	var runner := TestRunner.new()
	court.add_child(runner)
	for child in court.get_children():
		child.set_physics_process(false)
		if child is CharacterBody2D:
			child.position.x = -2000.0
	var profiles_increase := true
	var tracking_correct := true
	for names in [UPPER_GUARDS, LOWER_GUARDS]:
		var previous: Node2D
		for lane in 4:
			var guard: Node2D = court.get_node(names[lane])
			profiles_increase = profiles_increase and guard.lane_difficulty == lane + 1
			if previous != null:
				profiles_increase = profiles_increase and guard._patrol_speed >= previous._patrol_speed * 1.19
				profiles_increase = profiles_increase and guard._intercept_speed >= previous._intercept_speed * 1.12
				profiles_increase = profiles_increase and guard._reaction_time < previous._reaction_time
				profiles_increase = profiles_increase and guard._recovery_time < previous._recovery_time
			previous = guard
			for runner_y in RUNNER_YS:
				if runner_y < guard.top_y or runner_y > guard.bottom_y:
					continue
				runner.position = Vector2(guard.position.x - 80.0, runner_y)
				runner.velocity = Vector2(200.0, 0.0)
				tracking_correct = tracking_correct and guard._find_nearby_player() == runner
				guard._physics_process(STEP)
				tracking_correct = tracking_correct and is_equal_approx(guard._target_y, runner_y)
				guard._set_state(GUARD.State.PATROL)
				runner.velocity = Vector2.ZERO
				tracking_correct = tracking_correct and guard._find_nearby_player() == runner
				runner.position.x = guard.position.x - guard._pressure_distance - 20.0
				tracking_correct = tracking_correct and guard._find_nearby_player() == null
				runner.position.x = guard.position.x - 80.0
				runner.velocity.x = -100.0
				tracking_correct = tracking_correct and guard._find_nearby_player() == null
				runner.velocity.x = 200.0
				runner.position.x = guard.position.x + 20.0
				tracking_correct = tracking_correct and guard._find_nearby_player() == null
				runner.position.x = guard.position.x - 1000.0
				tracking_correct = tracking_correct and guard._find_nearby_player() == null
	_check(profiles_increase, "Each successive guard lane has a noticeable speed increase and quicker reactions")
	_check(tracking_correct, "All runner tracks draw pressure when approaching or waiting nearby, with no pursuit behind the line")
	var guard: Node2D = court.get_node(UPPER_GUARDS[3])
	runner.position = Vector2(guard.position.x - 90.0, guard.position.y)
	runner.velocity.x = 200.0
	var dashing_runner := TestRunner.new()
	dashing_runner.position = Vector2(guard.position.x - 140.0, guard.bottom_y - 20.0)
	dashing_runner.velocity.x = 650.0
	court.add_child(dashing_runner)
	_check(guard._find_nearby_player() == dashing_runner, "Guards prioritize an imminent dash over a slower, physically closer runner")
	court.queue_free()


func _test_patrol_variation() -> void:
	var template := GAME.instantiate()
	var fixtures: Array[Dictionary] = []
	for lane in 4:
		var world := Node2D.new()
		world.position = Vector2(lane * 1600.0, 0.0)
		add_child(world)
		var guards: Array[Node2D] = []
		for sample in 3:
			var guard := template.get_node(UPPER_GUARDS[lane]).duplicate() as Node2D
			guard.position = Vector2(400.0 + sample * 400.0, (guard.top_y + guard.bottom_y) * 0.5)
			guard.start_dir = 1
			world.add_child(guard)
			_seed_guard(guard, 7919 + lane * 101 + (1009 if sample == 2 else 0))
			guards.append(guard)
		fixtures.append({
			"world": world, "guards": guards, "twins_match": true,
			"largest_difference": 0.0, "previous_dir": guards[2].dir,
			"feints": 0, "hesitates": false,
		})
	template.free()
	for _frame in 600:
		await get_tree().physics_frame
		for fixture in fixtures:
			var first: Node2D = fixture.guards[0]
			var twin: Node2D = fixture.guards[1]
			var other: Node2D = fixture.guards[2]
			fixture.twins_match = fixture.twins_match and is_equal_approx(first.position.y, twin.position.y)
			fixture.largest_difference = maxf(fixture.largest_difference, absf(first.position.y - other.position.y))
			var mid_lane: bool = other.position.y > other.top_y + 30.0 and other.position.y < other.bottom_y - 30.0
			if mid_lane and other.dir != fixture.previous_dir:
				fixture.feints += 1
			fixture.hesitates = fixture.hesitates or (mid_lane and other._turn_timer > 0.0)
			fixture.previous_dir = other.dir
	var seeds_work := true
	var paths_vary := true
	var feints := 0
	var hesitates := false
	for fixture in fixtures:
		seeds_work = seeds_work and fixture.twins_match
		paths_vary = paths_vary and fixture.largest_difference > 25.0
		feints += fixture.feints
		hesitates = hesitates or fixture.hesitates
		fixture.world.queue_free()
	_check(seeds_work, "Seeded guard behavior replays consistently for balance checks")
	_check(paths_vary, "Every difficulty produces different patrol paths with different random seeds")
	_check(feints > 0 and hesitates, "Guards can hesitate and reverse mid-patrol, rather than always sweeping end to end")
	await get_tree().physics_frame
	await get_tree().physics_frame


func _test_committed_blocks() -> void:
	var template := GAME.instantiate()
	var fixtures: Array[Dictionary] = []
	for lane in 4:
		var world := Node2D.new()
		world.position = Vector2(lane * 1600.0, 0.0)
		add_child(world)
		var guard := template.get_node(UPPER_GUARDS[lane]).duplicate() as Node2D
		guard.position = Vector2(400.0, 119.0)
		world.add_child(guard)
		_seed_guard(guard, 8191 + lane * 101)
		var runner := TestRunner.new()
		runner.position = Vector2(310.0, 119.0)
		runner.velocity.x = 200.0
		world.add_child(runner)
		fixtures.append({
			"world": world, "guard": guard, "warning_for": 0.0,
			"first_warning": -1.0, "blocking_for": 0.0, "longest_block": 0.0,
			"intercept_for": 0.0, "longest_intercept": 0.0,
			"lane": lane, "previous_state": GUARD.State.PATROL, "windups": 0,
			"forced_follow_up": false, "first_recovery_windups": 0, "first_recovery_at": -1.0,
		})
	template.free()
	for frame in 180:
		await get_tree().physics_frame
		for fixture in fixtures:
			var guard: Node2D = fixture.guard
			if guard._state == GUARD.State.WINDUP and fixture.previous_state != GUARD.State.WINDUP:
				fixture.windups += 1
				if fixture.lane >= 2 and not fixture.forced_follow_up:
					guard._follow_ups_left = 1
					fixture.forced_follow_up = true
			if guard._state == GUARD.State.RECOVER and fixture.first_recovery_at < 0.0:
				fixture.first_recovery_windups = fixture.windups
				fixture.first_recovery_at = frame * STEP
			fixture.previous_state = guard._state
			if guard._state == GUARD.State.WINDUP:
				fixture.warning_for += STEP
			elif fixture.warning_for > 0.0 and fixture.first_warning < 0.0:
				fixture.first_warning = fixture.warning_for
			if guard._state == GUARD.State.INTERCEPT:
				fixture.intercept_for += STEP
				fixture.longest_intercept = maxf(fixture.longest_intercept, fixture.intercept_for)
				if absf(guard.position.y - 119.0) < 2.0:
					fixture.blocking_for += STEP
					fixture.longest_block = maxf(fixture.longest_block, fixture.blocking_for)
				else:
					fixture.blocking_for = 0.0
			else:
				fixture.intercept_for = 0.0
				fixture.blocking_for = 0.0
	var holds_crossing := true
	var warns_first := true
	var ends_intercept := true
	var follow_ups_bounded := true
	for fixture in fixtures:
		holds_crossing = holds_crossing and fixture.longest_block >= 0.25
		warns_first = warns_first and fixture.first_warning >= 0.14 - STEP
		ends_intercept = ends_intercept and fixture.longest_intercept > 0.0 and fixture.longest_intercept <= 1.2
		var expected_windups := 2 if fixture.lane >= 2 else 1
		follow_ups_bounded = follow_ups_bounded and fixture.first_recovery_windups == expected_windups
		follow_ups_bounded = follow_ups_bounded and fixture.first_recovery_at >= 0.0 and fixture.first_recovery_at <= 2.8
		fixture.world.queue_free()
	_check(holds_crossing, "Guards hold a contested crossing briefly instead of immediately abandoning it")
	_check(warns_first, "Even the fastest guard gives a visible warning before intercepting")
	_check(ends_intercept, "Committed blocks still end promptly and lead into recovery")
	_check(follow_ups_bounded, "Later guards can make one warned follow-up, then must create a recovery opening")
	await get_tree().physics_frame
	await get_tree().physics_frame


func _test_openings_and_tags() -> void:
	var template := GAME.instantiate()
	var fixtures: Array[Dictionary] = []
	for lane in 4:
		for track in 4:
			var world := Node2D.new()
			world.position = Vector2(lane * 1600.0, track * 1000.0)
			add_child(world)
			var names := UPPER_GUARDS if track < 2 else LOWER_GUARDS
			var guard := template.get_node(names[lane]).duplicate() as Node2D
			guard.position.x = 400.0
			world.add_child(guard)
			_seed_guard(guard, 4103 + lane * 101 + track * 1009)
			var runner := TestRunner.new()
			runner.position = Vector2(310.0, RUNNER_YS[track])
			runner.velocity.x = 200.0
			world.add_child(runner)
			fixtures.append({
				"world": world, "guard": guard, "runner": runner,
				"clear_for": 0.0, "longest_opening": 0.0,
				"in_bounds": true, "states": {},
			})
	template.free()
	# A continuously approaching target must still get usable openings, not a permanent lock-on.
	for _frame in 480:
		await get_tree().physics_frame
		for fixture in fixtures:
			var guard: Node2D = fixture.guard
			fixture.in_bounds = fixture.in_bounds and guard.position.y >= guard.top_y and guard.position.y <= guard.bottom_y
			fixture.states[guard._state] = true
			# Includes the full player area, guard hitbox, and a little margin.
			if absf(guard.position.y - fixture.runner.position.y) > 76.0:
				fixture.clear_for += STEP
				fixture.longest_opening = maxf(fixture.longest_opening, fixture.clear_for)
			else:
				fixture.clear_for = 0.0
	var openings_ok := true
	var bounds_ok := true
	var states_ok := true
	for fixture in fixtures:
		openings_ok = openings_ok and fixture.longest_opening >= 0.45
		bounds_ok = bounds_ok and fixture.in_bounds
		for state in [GUARD.State.WINDUP, GUARD.State.INTERCEPT, GUARD.State.RECOVER]:
			states_ok = states_ok and fixture.states.has(state)
	_check(openings_ok, "Every lane and runner track gets a usable dash window of at least 0.45 seconds under pressure")
	_check(bounds_ok, "All guards stay on their own court segment throughout the movement cycle")
	_check(states_ok, "All guard profiles warn, intercept, and recover instead of chasing indefinitely")

	var guard: Node2D = fixtures[0].guard
	var first_runner: TestRunner = fixtures[0].runner
	var body_area := Area2D.new()
	first_runner.add_child(body_area)
	var second_runner := TestRunner.new()
	second_runner.position = Vector2(-500.0, 119.0)
	fixtures[0].world.add_child(second_runner)
	guard._on_touched(first_runner)
	guard._on_touched(body_area)
	guard._on_touched(second_runner)
	_check(first_runner.hits == 1 and second_runner.hits == 1, "Duplicate overlaps count once and each runner has an independent tag cooldown")
	await get_tree().create_timer(guard.hit_cooldown + 0.1).timeout
	guard._on_touched(first_runner)
	_check(first_runner.hits == 2, "Tag cooldown expires normally")
	for fixture in fixtures:
		fixture.world.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _test_dash_recharge() -> void:
	var action := "PatinteroDashRechargeCheck"
	InputMap.add_action(action)
	var world := Node2D.new()
	world.position = Vector2(0.0, 6000.0)
	add_child(world)
	var runner := PLAYER.instantiate() as CharacterBody2D
	world.add_child(runner)
	runner._action = action
	var last_boost := 0.0
	var activations: Array[float] = []
	var active_for := 0.0
	var longest_burst := 0.0
	var peak_speed := 0.0
	for frame in 180:
		if frame % 4 < 2:
			Input.action_press(action)
		else:
			Input.action_release(action)
		await get_tree().physics_frame
		var boost: float = runner._boost_timer
		if boost > last_boost + 0.001:
			activations.append(frame * STEP)
		if boost > 0.0:
			active_for += STEP
			longest_burst = maxf(longest_burst, active_for)
		else:
			active_for = 0.0
		peak_speed = maxf(peak_speed, runner.velocity.x)
		last_boost = boost
	var recharges := activations.size() >= 2
	for index in range(1, activations.size()):
		recharges = recharges and activations[index] - activations[index - 1] >= runner.dash_cooldown - STEP
	_check(recharges, "Repeated taps cannot reactivate a dash until its recharge finishes")
	_check(longest_burst <= runner.boost_duration + STEP * 2.0, "Button mashing cannot refresh a dash into one continuous boost")
	_check(peak_speed <= runner.boost_speed + 0.01, "Repeated dashes stay within the controlled burst-speed limit")
	runner.set_physics_process(false)
	Input.action_release(action)
	InputMap.erase_action(action)
	world.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _test_player_impact_feedback() -> void:
	var court := GAME.instantiate() as Node2D
	add_child(court)
	await court.round_started
	await get_tree().physics_frame
	var runner := court.get_node("Player") as CharacterBody2D
	var camera := court.get_node("ImpactCamera") as Camera2D
	var start_x := runner.position.x
	runner._get_hit()
	var one_second_stun: bool = is_equal_approx(runner.get("stun_duration"), 1.0) and is_equal_approx(runner.get("_stun_timer"), 1.0)
	var camera_responds: bool = float(camera.get("_zoom_bump")) > 0.0 and float(camera.get("_shake_strength")) > 0.0
	await get_tree().physics_frame
	var knockback_speed := float(runner.get("knockback_speed"))
	var knockback_eases: bool = runner.velocity.x < 0.0 and runner.velocity.x > -knockback_speed and runner.position.x < start_x
	_check(one_second_stun, "A tag stuns the runner for exactly one second")
	_check(knockback_eases, "Knockback carries the runner back while smoothly easing off")
	_check(camera_responds, "A tag briefly zooms and shakes the shared court camera")
	court.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _test_timed_dashes() -> void:
	var template := GAME.instantiate()
	var fixtures: Array[Dictionary] = []
	for lane in 4:
		for track in 4:
			var world := Node2D.new()
			world.position = Vector2(lane * 1600.0, track * 1000.0)
			add_child(world)
			var names := UPPER_GUARDS if track < 2 else LOWER_GUARDS
			var guard := template.get_node(names[lane]).duplicate() as Node2D
			guard.position.x = 400.0
			world.add_child(guard)
			_seed_guard(guard, 4019 + lane * 101 + track * 1009)
			var action := "PatinteroDashCheck_%d_%d" % [lane, track]
			InputMap.add_action(action)
			var runner := PLAYER.instantiate() as CharacterBody2D
			runner.player_id = track + 1
			runner.position = Vector2(310.0, RUNNER_YS[track])
			world.add_child(runner)
			runner._action = action
			fixtures.append({
				"world": world, "guard": guard, "runner": runner, "action": action,
				"phase": "wait", "previous_y": guard.position.y,
				"boosted": false, "hit": false, "passed": false,
			})
	template.free()
	# Read the blue recovery cue at a 0.1-second cadence and dash as the guard
	# moves out of the path, before it plants to defend again.
	for frame in 900:
		var all_done := true
		for fixture in fixtures:
			if fixture.phase == "done":
				continue
			all_done = false
			var guard: Node2D = fixture.guard
			var runner: CharacterBody2D = fixture.runner
			var guard_step: float = guard.position.y - fixture.previous_y
			fixture.previous_y = guard.position.y
			fixture.boosted = fixture.boosted or runner._boost_timer > 0.0
			if runner._stun_timer > 0.0 or runner.position.x > guard.position.x + 52.0:
				fixture.hit = runner._stun_timer > 0.0
				fixture.passed = not fixture.hit
				fixture.phase = "done"
				Input.action_release(fixture.action)
				runner.set_physics_process(false)
				continue
			match fixture.phase:
				"wait":
					if frame % 6 == 0:
						var separation := guard.position.y - runner.position.y
						var moving_away := separation * guard_step > 0.0
						if guard._state == GUARD.State.RECOVER and absf(separation) >= 76.0 and absf(separation) <= 112.0 and moving_away:
							Input.action_press(fixture.action)
							fixture.phase = "tap"
				"tap":
					Input.action_release(fixture.action)
					fixture.phase = "release"
				"release":
					Input.action_press(fixture.action)
					fixture.phase = "run"
		if all_done:
			break
		await get_tree().physics_frame
	var passed := 0
	var boosted := 0
	var tagged := 0
	for fixture in fixtures:
		passed += 1 if fixture.passed else 0
		boosted += 1 if fixture.boosted else 0
		tagged += 1 if fixture.hit else 0
		if not fixture.passed:
			print("Timed dash did not clear ", fixture.action, ": phase=", fixture.phase, ", hit=", fixture.hit)
		fixture.runner.set_physics_process(false)
		Input.action_release(fixture.action)
		InputMap.erase_action(fixture.action)
		fixture.world.queue_free()
	_check(passed == 16, "A timed dash can clear every guard lane on all four player tracks")
	_check(boosted == 16, "Timed passing checks activate the real double-tap boost")
	_check(tagged == 0, "Carefully timed passes remain clean even with the harder guard settings")
	await get_tree().physics_frame
	await get_tree().physics_frame


func _measure_held_crossing(start_delay: float, random_seed: int, mash: bool = false) -> Dictionary:
	var court := GAME.instantiate() as Node2D
	add_child(court)
	_seed_court(court, random_seed)
	await court.round_started
	var runners: Array[CharacterBody2D] = []
	var hits := [0, 0, 0, 0]
	var tags_per_lane := [0, 0, 0, 0]
	var stunned := [false, false, false, false]
	var completed_lanes := [0, 0, 0, 0]
	var finish_times := [-1.0, -1.0, -1.0, -1.0]
	for player_index in 4:
		var node_name := "Player" if player_index == 0 else "Player%d" % (player_index + 1)
		runners.append(court.get_node(node_name) as CharacterBody2D)
		Input.action_release("P%d_Ready" % (player_index + 1))
	# Measure the cost of untimed approaches using the real movement and knockback.
	# Clean, deliberate passing is covered by the timed-dash fixtures above.
	for frame in 840:
		var elapsed := frame * STEP
		for player_index in 4:
			if finish_times[player_index] >= 0.0:
				continue
			var runner := runners[player_index]
			var is_stunned: bool = runner._stun_timer > 0.0
			if is_stunned and not stunned[player_index]:
				hits[player_index] += 1
				tags_per_lane[mini(completed_lanes[player_index], 3)] += 1
			stunned[player_index] = is_stunned
			for lane in 4:
				if runner.position.x > LANE_XS[lane] + 52.0:
					completed_lanes[player_index] = maxi(completed_lanes[player_index], lane + 1)
			var action := "P%d_Ready" % (player_index + 1)
			if completed_lanes[player_index] == 4:
				finish_times[player_index] = elapsed - start_delay
				Input.action_release(action)
			elif elapsed >= start_delay:
				if not mash or frame % 4 < 2:
					Input.action_press(action)
				else:
					Input.action_release(action)
		if not finish_times.has(-1.0):
			break
		await get_tree().physics_frame
	print("Court %s start %.2fs: lanes=%s, tags=%s, tags per lane=%s, finish seconds=%s" % ["mash" if mash else "hold", start_delay, completed_lanes, hits, tags_per_lane, finish_times])
	var tags := 0
	var tagged_runners := 0
	var clean_finishes := 0
	for hit_count in hits:
		tags += hit_count
		if hit_count > 0:
			tagged_runners += 1
	for player_index in 4:
		if completed_lanes[player_index] == 4 and hits[player_index] == 0:
			clean_finishes += 1
		Input.action_release("P%d_Ready" % (player_index + 1))
	court.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return {"tags": tags, "tagged_runners": tagged_runners, "clean_finishes": clean_finishes}


func _seed_guard(guard: Node2D, random_seed: int) -> void:
	guard._rng.seed = random_seed
	guard._pick_patrol_variation(false)


func _seed_court(court: Node2D, random_seed: int) -> void:
	for lane in 4:
		_seed_guard(court.get_node(UPPER_GUARDS[lane]), random_seed + lane * 101)
		_seed_guard(court.get_node(LOWER_GUARDS[lane]), random_seed + lane * 101 + 1009)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
