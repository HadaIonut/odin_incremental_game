package main

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
	timer_max:              f32,
	timer_current:          f32,
}

Effect_types :: enum {
	DAMAGE              = 1,
	RANGE               = 2,
	TICK_RATE           = 3,
	TIME                = 4,
	RESPAWN_RATE        = 5,
	POLY_COUNT          = 6,
	POLY_MASS           = 7,
	SPECIAL_POLY_CHANCE = 8,
}

Effect :: struct {
	type:  Effect_types,
	value: f32,
}

Positioning :: struct {
	name:               cstring,
	name_length:        int,
	description:        cstring,
	description_length: int,
	cost:               cstring,
	cost_length:        int,
	location:           rl.Vector2,
}

Animation :: struct {
	is_jiggling: bool,
	jiggle_time: f32,
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
	animation:    Animation,
}

Game_Screens :: enum {
	Game,
	Shop,
}
