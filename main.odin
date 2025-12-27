package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Polygon :: struct {
	location:         rl.Vector2,
	color:            rl.Color,
	velocity:         rl.Vector2,
	sides:            i32,
	radius:           f32,
	rotation:         f32,
	angular_momentum: f32,
	health:           i32,
	max_health:       uint,
	dead:             bool,
	money_worth:      i32,
}

Game_State :: struct {
	center:                 rl.Vector2,
	shop_camera:            rl.Camera2D,
	polys:                  []Polygon,
	new_polygon_change:     f32,
	special_polygon_change: f32,
	mouse_radius:           f32,
	damage_time:            f32,
	rotation_dt:            f32,
	money:                  i32,
	width:                  i32,
	height:                 i32,
	damage:                 i32,
	polygon_count:          int,
	current_game_screen:    Game_Screens,
}

Effect :: struct {
	type:  string,
	value: f32,
}

Upgrade :: struct {
	cost:        int,
	children:    []Upgrade,
	name:        string,
	description: string,
	effects:     []Effect,
}

Game_Screens :: enum {
	Game,
	Shop,
}

G :: 6.67430e-11
central_mass :: 1000000000000.0

game_state: Game_State

upgrades: Upgrade

main :: proc() {
	game_state.width = 720
	game_state.height = 720
	game_state.damage = 1

	rl.InitWindow(game_state.width, game_state.height, "test")
	defer rl.CloseWindow()

	rl.SetTargetFPS(144)
	init_upgrade()
	game_state.new_polygon_change = 0.05
	game_state.special_polygon_change = 0.05

	game_state.mouse_radius = 20
	game_state.damage_time = 1.0

	game_state.rotation_dt = 0.16
	game_state.polygon_count = 20
	game_state.current_game_screen = Game_Screens.Game
	game_state.shop_camera.target = rl.Vector2{0, 0}
	game_state.shop_camera.offset = rl.Vector2{0, 0}
	game_state.shop_camera.zoom = 1.0
	game_state.shop_camera.rotation = 0
	game_state.center = rl.Vector2{f32(game_state.width) / f32(2), f32(game_state.height) / f32(2)}
	game_state.money = 0

	game_state.polys = generate_polygons(game_state.polygon_count)

	rl.SetWindowMonitor(0)
	time_passed := f32(0)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.LIGHTGRAY)

		switch game_state.current_game_screen {
		case .Game:
			rl.HideCursor()
			render_game(&time_passed)
		case .Shop:
			rl.ShowCursor()
			render_shop()
		}

		if rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) {
			game_state.current_game_screen =
				game_state.current_game_screen == Game_Screens.Game ? Game_Screens.Shop : Game_Screens.Game
		}

		free_all(context.temp_allocator)

		rl.EndDrawing()
	}
}

generate_polygons :: proc(count: int) -> []Polygon {
	polygons := make([]Polygon, count)

	for i in 0 ..< count {
		is_special := rand.float32_range(0, 1) < game_state.special_polygon_change

		mean_radius := f32(game_state.width) / f32(2) * 0.7
		std_dev := f32(game_state.width) / f32(2) * 0.15

		theta := rand.float32_uniform(0, 2 * math.PI)
		r := rand.float32_normal(mean_radius, std_dev) + 10

		polygons[i].location[0], polygons[i].location[1] =
			game_state.center[0] + r * math.cos(theta), game_state.center[1] + r * math.sin(theta)

		polygons[i].dead = false
		polygons[i].health = 3
		polygons[i].max_health = 3

		if is_special {
			polygons[i].color = rl.ORANGE
			polygons[i].money_worth = 5
		} else {
			polygons[i].color = rl.RED
			polygons[i].money_worth = 1
		}

		polygons[i].sides = rand.int32_range(4, 8)
		polygons[i].radius = rand.float32_range(10, 15)
		polygons[i].rotation = rand.float32_range(10, 30)
		polygons[i].angular_momentum = rand.float32_range(0.8, 1.8)

		distVect := polygons[i].location - game_state.center
		len := rl.Vector2Length(distVect)
		tangent := rl.Vector2Normalize(rl.Vector2{-distVect[1], distVect[0]})
		speed := math.sqrt(G * central_mass / len)

		if is_special {
			speed_multiplier := rand.float32_uniform(0.5, 1.5)
			angle_offset := rand.float32_uniform(-math.PI / 4, math.PI / 4)

			tangent := rl.Vector2Rotate(tangent, angle_offset)

			polygons[i].velocity = tangent * speed * speed_multiplier * 2.5
		} else {
			polygons[i].velocity = speed * tangent * 2.5
		}
	}
	return polygons
}

darken :: proc(color: rl.Color) -> rl.Color {
	hsv := rl.ColorToHSV(color)
	hsv[2] -= 0.2
	hsv[2] = hsv[2] < 0 ? 0 : hsv[2]
	return rl.ColorFromHSV(hsv[0], hsv[1], hsv[2])
}

draw_polygon :: proc(polygon: Polygon) {
	rl.DrawPoly(polygon.location, polygon.sides, polygon.radius, polygon.rotation, polygon.color)
	rl.DrawPolyLines(
		polygon.location,
		polygon.sides,
		polygon.radius,
		polygon.rotation,
		darken(polygon.color),
	)

	rl.BeginScissorMode(
		i32(polygon.location[0] - polygon.radius),
		i32(polygon.location[1] - polygon.radius),
		i32(polygon.radius * 2),
		i32(polygon.radius * 2 * (1 - f32(polygon.health) / f32(polygon.max_health))),
	)

	health_color := rl.WHITE
	health_color[3] = 125
	rl.DrawPoly(polygon.location, polygon.sides, polygon.radius, polygon.rotation, health_color)

	rl.EndScissorMode()
}

update_polygon :: proc(polygon: ^Polygon) {
	distVect := game_state.center - polygon.location

	distSq := rl.Vector2DotProduct(distVect, distVect)
	dist := math.sqrt(distSq)

	direction := distVect / dist

	acceleration_magnitude := G * central_mass / distSq
	acceleration := acceleration_magnitude * direction

	polygon.velocity += acceleration
	polygon.location += polygon.velocity * game_state.rotation_dt

	polygon.rotation += polygon.angular_momentum * game_state.rotation_dt
}


display_mouse :: proc() {
	mouse_position := rl.GetMousePosition()

	rl.DrawCircleLines(
		i32(mouse_position[0]),
		i32(mouse_position[1]),
		game_state.mouse_radius,
		rl.BLACK,
	)
}

should_do_damage :: proc(time_passed: ^f32) -> rl.Vector2 {
	time_passed^ = time_passed^ + rl.GetFrameTime()

	if time_passed^ >= game_state.damage_time {
		time_passed^ = 0
		return rl.GetMousePosition()
	}

	return rl.Vector2{}
}

do_damage :: proc(polygon: ^Polygon, mouse_location: ^rl.Vector2) {
	empty_vec := rl.Vector2{}
	if !(mouse_location^ != empty_vec &&
		   rl.Vector2DistanceSqrt(mouse_location^, polygon.location) <=
			   game_state.mouse_radius * game_state.mouse_radius) {return}
	polygon.health -= game_state.damage
	if polygon.health > 0 {return}

	polygon.dead = true
	game_state.money += polygon.money_worth
	if rand.float32_range(0, 1) < game_state.new_polygon_change {
		polygon^ = generate_polygons(1)[0]
	}
}

render_game :: proc(time_passed: ^f32) {
	text := strings.clone_to_cstring(fmt.tprintf("%v", game_state.money), context.temp_allocator)

	rl.DrawText(text, 10, 10, 20, rl.BLACK)

	rl.DrawCircle(i32(game_state.center[0]), i32(game_state.center[1]), 10, rl.BLACK)

	mouse_location := should_do_damage(time_passed)

	for &polygon in game_state.polys {
		if polygon.dead == true {continue}

		do_damage(&polygon, &mouse_location)

		update_polygon(&polygon)
		draw_polygon(polygon)
	}

	display_mouse()
}

x_padding :: 10
font_size :: 15
y_padding :: 4

render_upgrades :: proc(drawing: []Upgrade, draw_x, start_draw_y: i32) {
	if len(drawing) == 0 {return}
	draw_x, draw_y := draw_x, start_draw_y
	max_text_len := i32(0)

	total_children := i32(0)

	for top in drawing {
		c_text := strings.clone_to_cstring(top.name, context.temp_allocator)
		text_len := rl.MeasureText(c_text, font_size)

		if text_len > max_text_len {
			max_text_len = text_len
		}

		rl.DrawRectangle(draw_x, draw_y, text_len + x_padding, font_size + y_padding, rl.GRAY)
		rl.DrawText(c_text, draw_x + x_padding / 2, draw_y + y_padding / 2, font_size, rl.BLACK)
		rl.DrawRectangleLines(
			draw_x,
			draw_y,
			text_len + x_padding,
			font_size + y_padding,
			rl.BLACK,
		)

		draw_y += font_size + 5
		total_children += i32(len(top.children))
	}

	current_drawn_children := i32(0)
	for top in drawing {
		current_drawn_children += i32(len(top.children))
		render_upgrades(
			top.children,
			draw_x + max_text_len + x_padding + x_padding,
			start_draw_y - (font_size + y_padding) * (total_children - current_drawn_children),
		)
	}
}

render_shop :: proc() {
	rl.BeginMode2D(game_state.shop_camera)

	temp := []Upgrade{upgrades}

	render_upgrades(temp, 0, 0)

	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
		mouse_delta := rl.GetMouseDelta()
		updated_mouse_position := rl.GetMousePosition() - mouse_delta
		game_state.shop_camera.target -= mouse_delta
	}

	rl.EndMode2D()
}
