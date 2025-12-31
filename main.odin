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
	shop_mouse_location:    rl.Vector2,
	shop_mouse_clicked:     bool,
	shop_mouse_down:        bool,
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

Effect_types :: enum {
	DAMAGE    = 1,
	RANGE     = 2,
	TICK_RATE = 3,
}

Effect :: struct {
	type:  Effect_types,
	value: f32,
}

Positioning :: struct {
	name:        cstring,
	name_length: int,
	location:    rl.Vector2,
}

Upgrade :: struct {
	cost:         i32,
	max_buys:     uint,
	current_buys: uint,
	available:    bool,
	children:     []Upgrade,
	name:         string,
	description:  string,
	effects:      []Effect,
	positioning:  Positioning,
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
	game_state.money = 1000

	game_state.polys = generate_polygons(game_state.polygon_count)

	rl.SetWindowMonitor(0)
	time_passed := f32(0)

	for !rl.WindowShouldClose() {
		game_state.shop_mouse_location = rl.GetScreenToWorld2D(
			rl.GetMousePosition(),
			game_state.shop_camera,
		)
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

		text := strings.clone_to_cstring(
			fmt.tprintf("%v", game_state.money),
			context.temp_allocator,
		)

		rl.DrawText(text, 10, 10, 20, rl.BLACK)


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

handle_buy_upgrade_click :: proc(upgrade: ^Upgrade) {
	game_state.money -= upgrade.cost
	upgrade.current_buys += 1
	for effect in upgrade.effects {
		switch effect.type {
		case .DAMAGE:
			game_state.damage += i32(effect.value)
		case .RANGE:
			game_state.mouse_radius += effect.value
		case .TICK_RATE:
			game_state.damage_time += effect.value
		}
	}
	for &child in upgrade.children {
		child.available = true
	}
}

get_button_color :: proc(rectangle: rl.Rectangle, upgrade: ^Upgrade, hovers: bool) -> rl.Color {
	if !upgrade.available {return rl.DARKGRAY}

	if upgrade.max_buys == upgrade.current_buys {return rl.GRAY}

	if hovers &&
	   game_state.shop_mouse_down &&
	   game_state.money >= upgrade.cost {return rl.DARKGRAY}

	//TODO maybe add a cute jiggle animation?
	if hovers && game_state.shop_mouse_down {return rl.RED}

	if hovers {return rl.WHITE}

	return rl.LIGHTGRAY
}

render_button :: proc(rectangle: rl.Rectangle, upgrade: ^Upgrade) {
	hovers := rl.CheckCollisionPointRec(game_state.shop_mouse_location, rectangle)
	color := get_button_color(rectangle, upgrade, hovers)

	if hovers &&
	   game_state.shop_mouse_clicked &&
	   game_state.money >= upgrade.cost &&
	   upgrade.max_buys > upgrade.current_buys {
		handle_buy_upgrade_click(upgrade)
	}
	rl.DrawRectangleRec(rectangle, color)
	rl.DrawText(
		upgrade.positioning.name,
		i32(rectangle.x) + x_padding / 2,
		i32(rectangle.y) + y_padding / 2,
		font_size,
		rl.BLACK,
	)
	rl.DrawRectangleLinesEx(rectangle, 1, rl.BLACK)
}

height_middle :: (font_size + y_padding) / 2

render_parent_line :: proc(drawing: ^Upgrade) -> rl.Vector2 {
	start := rl.Vector2 {
		drawing.positioning.location[0] + f32(drawing.positioning.name_length + x_padding),
		drawing.positioning.location[1] + height_middle,
	}
	middle := rl.Vector2 {
		drawing.positioning.location[0] +
		f32(drawing.positioning.name_length + x_padding) +
		x_margin / 2,
		drawing.positioning.location[1] + height_middle,
	}
	rl.DrawLineV(start, middle, rl.BLACK)

	return middle
}

render_upgrades :: proc(drawing: ^Upgrade) {
	render_button(
		rl.Rectangle {
			drawing.positioning.location[0],
			drawing.positioning.location[1],
			f32(drawing.positioning.name_length + x_padding),
			font_size + y_padding,
		},
		drawing,
	)
	if len(drawing.children) == 0 {return}
	middle := render_parent_line(drawing)

	for &child in drawing.children {
		middle_end := rl.Vector2{middle[0], child.positioning.location[1] + height_middle}
		end := rl.Vector2 {
			child.positioning.location.x,
			child.positioning.location.y + height_middle,
		}

		rl.DrawLineV(middle, middle_end, rl.BLACK)
		rl.DrawLineV(middle_end, end, rl.BLACK)

		render_upgrades(&child)
	}
}

render_shop :: proc() {
	rl.BeginMode2D(game_state.shop_camera)
	game_state.shop_mouse_clicked = rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
	game_state.shop_mouse_down = rl.IsMouseButtonDown(rl.MouseButton.LEFT)

	render_upgrades(&upgrades)

	if game_state.shop_mouse_down {
		mouse_delta := rl.GetMouseDelta() / game_state.shop_camera.zoom
		game_state.shop_camera.target -= mouse_delta
	}
	game_state.shop_camera.zoom += rl.GetMouseWheelMove() / 3

	rl.EndMode2D()
}
