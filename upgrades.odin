package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

init_upgrade :: proc() {
	if data, ok := os.read_entire_file("upgrades.json"); ok {
		if json.unmarshal(data, &upgrades) == nil {
			fmt.println("unmarshal successful")
			update_positioning(&upgrades, nil)
		} else {
			fmt.println("something went wrong while unmarshaling")
			os.exit(-1)
		}
	} else {
		fmt.println("something went wrong while reading the file")
		os.exit(-1)
	}
}


x_margin :: 30
y_margin :: 10

@(private = "file")
update_positioning :: proc(upgrade: ^Upgrade, parent: ^Upgrade) {
	upgrade.positioning.name = strings.clone_to_cstring(upgrade.name)
	upgrade.positioning.name_length = int(rl.MeasureText(upgrade.positioning.name, font_size))

	parent_name_len := parent == nil ? 0 : parent.positioning.name_length
	parent_location := parent == nil ? rl.Vector2{} : parent.positioning.location

	upgrade.positioning.location =
		parent_location +
		upgrade.positioning.location *
			rl.Vector2 {
					(f32(parent_name_len + x_padding + x_margin)),
					(font_size + y_padding + y_margin),
				}

	for &child in upgrade.children {
		update_positioning(&child, upgrade)
	}
}
