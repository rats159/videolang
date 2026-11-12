package videolang

import "base:runtime"
import "core:fmt"
import "core:unicode/utf8"
Tokenizer :: struct {
	source:          string,
	offset:          int,
	errors:          [dynamic; 32]Error,
	error_allocator: runtime.Allocator,
	current_pos:     Source_Pos,
}

Token_Type :: enum {
	// Special
	Invalid,
	EOF,
	// Keywords
	Fun,
	Var,
	For,
	In,
	If,
	Else,
	While,
	Break,
	Continue,
	Return,
	// Literals
	Identifier,
	Integer,
	Float,
	String,
	// Symbols
	Open_Paren,
	Close_Paren,
	Open_Curly,
	Close_Curly,
	Open_Bracket,
	Close_Bracket,
	Semicolon,
	Plus,
	Minus,
	Star,
	Slash,
	Equals,
	Equals_Equals,
	Dot,
	Comma,
	Exclamation,
}

keywords := #partial [Token_Type]string {
	.Fun      = "fun",
	.Var      = "var",
	.For      = "for",
	.In       = "in",
	.If       = "if",
	.Else     = "else",
	.While    = "while",
	.Break    = "break",
	.Continue = "continue",
	.Return   = "return",
}

Token :: struct #all_or_none {
	type:  Token_Type,
	value: string,
	pos:   Source_Pos,
}

scan_next_token :: proc(tk: ^Tokenizer) -> Token {
	skip_whitespace(tk)

	if tk_done(tk) {
		return Token{type = .EOF, value = "<EOF>", pos = tk.current_pos}
	}

	switch tk_current(tk) {
	case 'a' ..= 'z', 'A' ..= 'Z', '_':
		return scan_word_token(tk)
	case '0' ..= '9':
		return scan_number_token(tk)
	case '"':
		return scan_string_token(tk)
	case '(':
		return scan_simple_token(tk, .Open_Paren, 1)
	case ')':
		return scan_simple_token(tk, .Close_Paren, 1)
	case '{':
		return scan_simple_token(tk, .Open_Curly, 1)
	case '}':
		return scan_simple_token(tk, .Close_Curly, 1)
	case '[':
		return scan_simple_token(tk, .Open_Bracket, 1)
	case ']':
		return scan_simple_token(tk, .Close_Bracket, 1)
	case ';':
		return scan_simple_token(tk, .Semicolon, 1)
	case '+':
		return scan_simple_token(tk, .Plus, 1)
	case '-':
		return scan_simple_token(tk, .Minus, 1)
	case '*':
		return scan_simple_token(tk, .Star, 1)
	case '/':
		return scan_simple_token(tk, .Slash, 1)
	case '.':
		return scan_simple_token(tk, .Dot, 1)
	case ',':
		return scan_simple_token(tk, .Comma, 1)
	case '!':
		return scan_simple_token(tk, .Exclamation, 1)
	case '=':
		if tk_peek(tk) == '=' {
			return scan_simple_token(tk, .Equals_Equals, 2)
		} else {
			return scan_simple_token(tk, .Equals, 1)
		}
	case:
		tk_error(tk, "Invalid character '%c'", tk_current(tk))
		defer tk_advance(tk)

		return Token {
			type = .Invalid,
			value = tk.source[tk.offset:tk.offset + 1],
			pos = tk.current_pos,
		}
	}
}

skip_escape :: proc(tk: ^Tokenizer) {
	switch tk_current(tk) {
	case 'r', 'n', 'v', 't', 'a', 'b', '0', '"', '\\':
		tk_advance(tk)
	// FUTURE: unicode escapes/hex escapex
	case:
		tk_error(tk, "Invalid escape sequence '\\%c'", tk_current(tk))
	}
}

scan_string_token :: proc(tk: ^Tokenizer) -> Token {
	start := tk.offset
	start_pos := tk.current_pos
	tk_advance(tk)

	scan_loop: for {
		r := tk_current(tk)
		tk_advance(tk)

		if tk_done(tk) {
			tk_error(tk, "String literal not terminated")
			break scan_loop
		}

		switch r {
		case '\n':
			tk_error(tk, "String literal not terminated")
			break scan_loop
		case '\\':
			skip_escape(tk)
		case '"':
			break scan_loop
		}
	}


	return Token{type = .String, value = tk.source[start:tk.offset], pos = start_pos}
}

scan_number_token :: proc(tk: ^Tokenizer) -> Token {
	start := tk.offset
	start_pos := tk.current_pos
	is_float := false

	integer_scan: for {
		switch tk_current(tk) {
		case '0' ..= '9', '_':
			tk_advance(tk)
		case:
			break integer_scan
		}
	}

	if tk_current(tk) == '.' {
		is_float = true
		tk_advance(tk)
		decimal_scan: for {
			switch tk_current(tk) {
			case '0' ..= '9', '_':
				tk_advance(tk)
			case:
				break decimal_scan
			}
		}
	}

	if tk_current(tk) == 'e' {
		tk_advance(tk)
		is_float = true

		switch tk_current(tk) {
		case '+', '-':
			tk_advance(tk)
		}
		exponent_digits := 0
		exponent_scan: for {
			switch tk_current(tk) {
			case '0' ..= '9', '_':
				exponent_digits += 1
				tk_advance(tk)
			case:
				break exponent_scan
			}
		}

		if exponent_digits == 0 {
			tk_error(tk, "Bad float exponent: expected at least 1 digit")
		}
	}

	return Token {
		value = tk.source[start:tk.offset],
		type = is_float ? .Float : .Integer,
		pos = start_pos,
	}
}

scan_word_token :: proc(tk: ^Tokenizer) -> Token {
	start := tk.offset
	start_pos := tk.current_pos

	word_loop: for {
		switch tk_current(tk) {
		case 'a' ..= 'z', 'A' ..= 'Z', '0' ..= '9', '_':
			tk_advance(tk)
		case:
			break word_loop
		}
	}

	word := tk.source[start:tk.offset]

	type := Token_Type.Identifier

	for kw_name, kw_type in keywords {
		if word == kw_name {
			type = kw_type
			break
		}
	}

	return Token{type = type, value = word, pos = start_pos}
}

skip_whitespace :: proc(tk: ^Tokenizer) {
	for {
		switch tk_current(tk) {
		case ' ', '\r', '\n', '\t':
			tk_advance(tk)
		case '/':
			switch tk_peek(tk) {
			case '/':
				tk_advance(tk, 2)
				skip_line_comment(tk)
			case '*':
				tk_advance(tk, 2)
				skip_block_comment(tk)
			case:
				return
			}
		case:
			return
		}
	}
}

skip_line_comment :: proc(tk: ^Tokenizer) {
	for {
		if tk_current(tk) == '\n' {
			return
		}
		if tk_done(tk) {
			return
		}
		tk_advance(tk)
	}
}

skip_block_comment :: proc(tk: ^Tokenizer) {
	depth := 1
	for depth != 0 {
		if tk_current(tk) == '/' && tk_peek(tk) == '*' {
			depth += 1
			tk_advance(tk, 2)
			continue
		}

		if tk_current(tk) == '*' && tk_peek(tk) == '/' {
			depth -= 1
			tk_advance(tk, 2)
			continue
		}

		if tk_done(tk) {
			tk_error(tk, "Unterminated block comment")
			return
		}
		tk_advance(tk)
	}
}

scan_simple_token :: proc(tk: ^Tokenizer, type: Token_Type, byte_length: int) -> Token {
	token := Token {
		value = tk.source[tk.offset:tk.offset + byte_length],
		type  = type,
		pos   = tk.current_pos,
	}

	tk_advance(tk, byte_length)

	return token
}

tk_done :: proc(tk: ^Tokenizer) -> bool {
	return tk.offset >= len(tk.source)
}

tk_current :: proc(tk: ^Tokenizer) -> rune {
	char, _ := utf8.decode_rune(tk.source[tk.offset:])

	return char
}

tk_peek :: proc(tk: ^Tokenizer) -> rune {
	return utf8.rune_at_pos(tk.source[tk.offset:], 1)
}

tk_advance :: proc(tk: ^Tokenizer, codepoints: int = 1) {
	total_distance := 0
	for _ in 0 ..< codepoints {
		char, size := utf8.decode_rune(tk.source[tk.offset + total_distance:])
		total_distance += size

		if char == '\n' {
			tk.current_pos.line += 1
			tk.current_pos.col = 0
		}
		tk.current_pos.col += 1
	}

	tk.offset += total_distance
}

tk_error :: proc(tk: ^Tokenizer, message: string, args: ..any) {
	message := fmt.aprintf(message, ..args, allocator = tk.error_allocator)

	append(&tk.errors, Error{message = message, type = .Syntax, pos = tk.current_pos})
}
