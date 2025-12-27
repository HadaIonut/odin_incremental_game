package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
init_upgrade :: proc() {
	if data, ok := os.read_entire_file("upgrades.json"); ok {
		if json.unmarshal(data, &upgrades) == nil {
			fmt.println("unmarshal successful")
		} else {
			fmt.println("something went wrong while unmarshaling")
		}
	} else {
		fmt.println("something went wrong while reading the file")
	}
}
