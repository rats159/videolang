package videolang

import "core:fmt"

contents := #load("test.vl", string)

main :: proc() {
	ast, errors := parse_entire_file(contents, context.allocator, context.allocator)
	if len(errors) != 0 {
		for error in errors {
			fmt.eprintln(error.message)
		}
	} else {
		print_ast(ast)
	}
}
