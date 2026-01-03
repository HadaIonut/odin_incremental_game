package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

height_middle :: (font_size + y_padding) / 2

x_padding :: 10
font_size :: 15
y_padding :: 4

button_max_jiggle_time :: f32(0.2)

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

render_effect_info :: proc(effect: Effect, location: rl.Vector2) {
	display_text := []string{"", "", " -> ", ""}
	switch effect.type {
	case .DAMAGE:
		display_text[1] = fmt.tprintf("%v", game_state.damage)
		display_text[3] = fmt.tprintf("%v", game_state.damage + i32(effect.value))
		display_text[0] = "Damage: "
	case .RANGE:
		display_text[1] = fmt.tprintf("%.2f", game_state.mouse_radius)
		display_text[3] = fmt.tprintf("%.2f", game_state.mouse_radius + effect.value)
		display_text[0] = "Mouse Radius: "
	case .TICK_RATE:
		display_text[1] = fmt.tprintf("%.2f", game_state.damage_time)
		display_text[3] = fmt.tprintf("%.2f", game_state.damage_time + effect.value)
		display_text[0] = "Attack Speed: "
	case .TIME:
		display_text[1] = fmt.tprintf("%.2f", game_state.timer_max)
		display_text[3] = fmt.tprintf("%.2f", game_state.timer_max + effect.value)
		display_text[0] = "Timer: "
	case .POLY_COUNT:
		display_text[1] = fmt.tprintf("%v", game_state.polygon_count)
		display_text[3] = fmt.tprintf("%v", game_state.polygon_count + int(effect.value))
		display_text[0] = "Polygons: "
	case .RESPAWN_RATE:
		display_text[1] = fmt.tprintf("%.2f", game_state.new_polygon_change)
		display_text[3] = fmt.tprintf("%.2f", game_state.new_polygon_change + effect.value)
		display_text[0] = "New Polygon Chance: "
	case .SPECIAL_POLY_CHANCE:
		display_text[1] = fmt.tprintf("%.2f", game_state.special_polygon_change)
		display_text[3] = fmt.tprintf("%.2f", game_state.special_polygon_change + effect.value)
		display_text[0] = "Special Polygon Chance: "
	case .POLY_MASS:
		fmt.println("UNIMPLEMENTED")
	}

	display_text_concatenated := strings.concatenate(display_text)
	display_text_c := strings.clone_to_cstring(display_text_concatenated, context.temp_allocator)

	rl.DrawText(display_text_c, i32(location.x), i32(location.y), font_size, rl.BLACK)
}


render_hover_menu :: proc() {
	if !draw_hover_menu {return}

	title_y_pos := i32(hover_menu_location.y + y_padding)
	rl.DrawRectangleRec(hover_menu_location, rl.WHITE)
	rl.DrawText(
		hover_menu_upgrade.positioning.name,
		i32(
			hover_menu_location.x +
			hover_menu_location.width / 2 -
			f32(hover_menu_upgrade.positioning.name_length) / 2,
		),
		title_y_pos,
		font_size,
		rl.BLACK,
	)
	rl.DrawText(
		hover_menu_upgrade.positioning.description,
		i32(hover_menu_location.x + x_padding),
		title_y_pos + y_padding + font_size,
		font_size,
		rl.BLACK,
	)

	rl.DrawText(
		hover_menu_upgrade.positioning.cost,
		i32(hover_menu_location.x + x_padding),
		title_y_pos + 2 * (y_padding + font_size),
		font_size,
		rl.BLACK,
	)
	render_effect_info(
		hover_menu_upgrade.effects[0],
		rl.Vector2 {
			hover_menu_location.x + x_padding,
			f32(title_y_pos + 3 * (y_padding + font_size)),
		},
	)

	rl.DrawRectangleLinesEx(hover_menu_location, 1, rl.BLACK)
	draw_hover_menu = false
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

	render_hover_menu()


	rl.EndMode2D()
}


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
		case .TIME:
			game_state.timer_max += effect.value
		case .POLY_COUNT:
			game_state.polygon_count += int(effect.value)
		case .RESPAWN_RATE:
			game_state.new_polygon_change += effect.value
		case .SPECIAL_POLY_CHANCE:
			game_state.special_polygon_change += effect.value
		case .POLY_MASS:
			fmt.println("UNIMPLEMENTED")
		}
	}
	for &child in upgrade.children {
		child.available = true
	}
}

get_button_color :: proc(rectangle: rl.Rectangle, upgrade: ^Upgrade, hovers: bool) -> rl.Color {
	if upgrade.animation.is_jiggling {return rl.RED}
	if !upgrade.available {return rl.GRAY}

	if upgrade.max_buys == upgrade.current_buys {return rl.GRAY}

	if hovers && game_state.shop_mouse_down && game_state.money >= upgrade.cost {return rl.GRAY}

	if hovers && game_state.shop_mouse_clicked {
		upgrade.animation.is_jiggling = true
		upgrade.animation.jiggle_time = 0

		return rl.RED
	}

	if hovers && game_state.shop_mouse_down {
		return rl.RED
	}

	if hovers {return rl.WHITE}

	return rl.LIGHTGRAY
}

hover_menu_height :: 100
hover_menu_width :: 250

draw_hover_menu: bool
hover_animation: f32 = 0
hover_menu_location: rl.Rectangle
hover_menu_upgrade: ^Upgrade
hover_menu_animation_speed :: 8.0

prepare_hover_menu :: proc(rectangle: rl.Rectangle, upgrade: ^Upgrade) {
	draw_hover_menu = true
	rect_center := rl.Vector2{rectangle.x + rectangle.width / 2, rectangle.y}

	hover_menu_location = rl.Rectangle {
		x      = rect_center.x - hover_menu_width / 2,
		y      = rect_center.y - y_margin - hover_menu_height,
		width  = hover_menu_width,
		height = hover_menu_height,
	}
	hover_menu_upgrade = upgrade

}

render_button :: proc(rectangle: rl.Rectangle, upgrade: ^Upgrade) {
	rectangle := rectangle
	hovers := rl.CheckCollisionPointRec(game_state.shop_mouse_location, rectangle)
	color := get_button_color(rectangle, upgrade, hovers)

	if hovers &&
	   game_state.shop_mouse_clicked &&
	   game_state.money >= upgrade.cost &&
	   upgrade.max_buys > upgrade.current_buys {
		handle_buy_upgrade_click(upgrade)
	}

	if upgrade.animation.is_jiggling {
		upgrade.animation.jiggle_time += rl.GetFrameTime()
		if upgrade.animation.jiggle_time >= button_max_jiggle_time {
			upgrade.animation.is_jiggling = false
		}

		offset_x := 3 * math.sin_f32(upgrade.animation.jiggle_time * 50)
		rectangle.x += offset_x
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

	if hovers && upgrade.available {
		prepare_hover_menu(rectangle, upgrade)
	}
}
