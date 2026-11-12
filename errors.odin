package videolang

import "core:fmt"
Source_Pos :: struct {
	line, col: int,
	filepath:  string,
}

Error_Type :: enum {
	Syntax,
	Type,
}

Error :: struct {
	type:      Error_Type,
	using pos: Source_Pos,
	message:   string,
}

print_error :: proc(error: Error) {
	fmt.eprintfln(
		"[%s:%d:%d] %s error: %s",
		error.filepath,
		error.line,
		error.col,
		error.type,
		error.message,
	)
}
