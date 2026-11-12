package videolang

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:strconv"

Parser :: struct {
	tokenizer:       Tokenizer,
	current_token:   Token,
	allocator:       runtime.Allocator,
	error_allocator: runtime.Allocator,
	errors:          [dynamic; 32]Error,
}

parse_entire_file :: proc(
	path: string,
	source: string,
	node_allocator, error_allocator: runtime.Allocator,
) -> (
	Node,
	[dynamic; 32]Error,
) {
	nodes: [dynamic]Node
	nodes.allocator = node_allocator

	parser := Parser {
		tokenizer = {
			source = source,
			error_allocator = error_allocator,
			current_pos = {line = 1, col = 1, filepath = path},
		},
		allocator = node_allocator,
		error_allocator = error_allocator,
	}

	parser_advance(&parser)

	node, _ := parse_statements_until(&parser, .EOF, parser.current_token.pos)

	errors := parser.errors

	append(&errors, ..parser.tokenizer.errors[:])

	return node, errors
}

parse_statements_until :: proc(p: ^Parser, type: Token_Type, pos: Source_Pos) -> (_node: Node, _ok: bool) {
	statements := make([dynamic]Node, allocator = p.allocator)

	for !parser_match(p, type) {
		stmt, ok := parse_statement(p)
		if ok {
			append(&statements, stmt)
		} else {
			recovered := parser_resync(p, type)
			if !recovered {
				return {}, false
			}
		}
	}

	node := parser_new(p, pos, Block_Statement{
		contents = statements[:]
	})

	return node, true
}

parse_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	#partial switch parser_current(p).type {
	case .Fun:
		return parse_fun_declaration(p)
	case .Var:
		return parse_var_declaration(p)
	case .If:
		return parse_if_statement(p)
	case .For:
		return parse_for_statement(p)
	case .While:
		return parse_while_statement(p)
	case .Break:
		return parse_break_statement(p)
	case .Continue:
		return parse_continue_statement(p)
	case .Open_Curly:
		return parse_block_statement(p)
	case .Return:
		return parse_return_statement(p)
	case:
		return parse_expression_statement(p)
	}
}

parse_fun_declaration :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Fun) or_return
	name := parser_expect(p, .Identifier) or_return
	_ = parser_expect(p, .Open_Paren) or_return
	parameters := make([dynamic]string, allocator = p.allocator)

	if !parser_match(p, .Close_Paren) {
		for {
			parameter := parser_expect(p, .Identifier) or_return
			append(&parameters, parameter.value)

			if parser_match(p, .Close_Paren) {
				break
			}

			_ = parser_expect(p, .Comma) or_return

			if parser_match(p, .Close_Paren) {
				break
			}
		}
	}

	body := parse_block_statement(p) or_return

	node := parser_new(p, token.pos, Function_Declaration {
		name = name.value,
		paramters = parameters[:],
		body = body
	})

	return node, true
}

parse_var_declaration :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Var) or_return
	name := parser_expect(p, .Identifier) or_return
	_ = parser_expect(p, .Equals) or_return
	value := parse_expression(p, .None) or_return
	_ = parser_expect(p, .Semicolon) or_return

	node := parser_new(p, token.pos, Variable_Declaration{
		value = value,
		name = name.value
	})

	return node, true
}

parse_if_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .If) or_return

	condition := parse_expression(p, .None) or_return
	if_true := parse_block_statement(p) or_return

	if_false: Maybe(Node)

	if parser_match(p, .Else) {
		if parser_current(p).type == .If {
			if_false = parse_if_statement(p) or_return
		} else if parser_current(p).type == .Open_Curly {
			if_false = parse_block_statement(p) or_return
		} else {
			parser_error(
				p,
				parser_current(p).pos,
				"Expected 'if' or '{' after 'else', but got '%s'",
				parser_current(p).value,
			)
		}
	}

	node := parser_new(
		p,
		token.pos,
		If_Statement{condition = condition, if_true = if_true, if_false = if_false},
	)


	return node, true
}

parse_for_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .For) or_return
	name := parser_expect(p, .Identifier) or_return
	_ = parser_expect(p, .In) or_return
	target := parse_expression(p, .None) or_return

	body := parse_block_statement(p) or_return

	node := parser_new(p, token.pos, For_Loop{
		body = body,
		target = target,
		variable = name.value
	})

	return node, true
}

parse_while_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .While) or_return

	condition := parse_expression(p, .None) or_return
	body := parse_block_statement(p) or_return

	node := parser_new(p, token.pos, While_Loop{
		condition = condition,
		body = body
	})

	return node, true
}

parse_break_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Break) or_return
	_ = parser_expect(p, .Semicolon) or_return

	node := parser_new(p, token.pos, Break_Statement {})

	return node, true
}

parse_continue_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Continue) or_return
	_ = parser_expect(p, .Semicolon) or_return

	node := parser_new(p, token.pos, Continue_Statement{})

	return node, true
}

parse_block_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Open_Curly) or_return
	return parse_statements_until(p, .Close_Curly, token.pos)
}

parse_return_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Return) or_return
	value: Maybe(Node)
	if !parser_match(p, .Semicolon) {
		value = parse_expression(p, .None) or_return
		_ = parser_expect(p, .Semicolon) or_return
	}

	node := parser_new(p, token.pos, Return_Statement{
		value = value
	})

	return node, true
}

parse_expression_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	expr, ok := parse_expression(p, .None)

	if !ok {
		recovered := parser_resync(p, nil)
		return {}, recovered
	} else {
		_ = parser_expect(p, .Semicolon) or_return
	}

	return expr, true
}


parse_expression :: proc(p: ^Parser, min_bp: Binding_Power) -> (_node: Node, _ok: bool) {
	left := parse_prefix_expression(p) or_return

	for {
		op_token := parser_current(p)

		if op_token.type == .Equals {
			parser_advance(p)
			rhs := parse_expression(p, .None) or_return

			node := parser_new(p, left.position, Assignment_Statement {
				target = left,
				value = rhs
			})

			return node, true
		}

		operator_type := binary_operators[op_token.type]

		if operator_type == .Invalid {
			break
		}

		left_bp, right_bp := binary_binding_power(operator_type)

		if left_bp < min_bp {
			break
		}

		parser_advance(p)

		right := parse_expression(p, right_bp) or_return

		node := parser_new(p, left.position, Binary_Expression{
			left = left,
			right = right,
			op = operator_type
		})

		left = node
	}

	return left, true
}

parse_prefix_expression :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	pos := p.current_token.pos
	#partial switch parser_current(p).type {
	case .Minus:
		parser_advance(p)
		base := parse_prefix_expression(p) or_return
		node := parser_new(p, pos, Unary_Expression {
			base = base,
			op = .Negation
		})
		return node, true
	case .Exclamation:
		parser_advance(p)
		base := parse_prefix_expression(p) or_return
		node := parser_new(p, pos, Unary_Expression{
			base = base,
			op = .Logical_Not
		})
		return node, true
	case:
		return parse_postfix_expression(p)
	}
}

parse_postfix_expression :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	base := parse_value_expression(p) or_return

	for {
		#partial switch parser_current(p).type {
		case .Open_Paren:
			base = parse_call(p, base) or_return
		case .Open_Bracket:
			base = parse_index(p, base) or_return
		case .Dot:
			base = parse_field_access(p, base) or_return
		case:
			return base, true
		}
	}
}

parse_call :: proc(p: ^Parser, base: Node) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Open_Paren) or_return
	arguments := make([dynamic]Node, allocator = p.allocator)

	if !parser_match(p, .Close_Paren) {
		for {
			argument := parse_expression(p, .None) or_return
			append(&arguments, argument)

			if parser_match(p, .Close_Paren) {
				break
			}

			_ = parser_expect(p, .Comma) or_return

			if parser_match(p, .Close_Paren) {
				break
			}
		}
	}

	node := parser_new(p, base.position, Call_Expression {
		base = base,
		arguments = arguments[:]
	})

	return node, true
}

parse_index :: proc(p: ^Parser, base: Node) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Open_Bracket) or_return

	index := parse_expression(p, .None) or_return
	_ = parser_expect(p, .Close_Bracket) or_return

	node := parser_new(p, base.position, Index_Expression {
		base = base,
		index = index
	})

	return node, true
}

parse_field_access :: proc(p: ^Parser, base: Node) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Dot) or_return
	field := parser_expect(p, .Identifier) or_return

	node := parser_new(p, base.position, Field_Access{
		base = base,
		field = field.value,
	})

	return node, true
}

parse_value_expression :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	#partial switch parser_current(p).type {
	case .Integer:
		return parse_integer(p)
	case .Float:
		return parse_float(p)
	case .Identifier:
		return parse_identifier(p)
	case .String:
		return parse_string(p)
	case .Open_Bracket:
		return parse_list(p)
	case .Open_Paren:
		parser_advance(p)
		expr := parse_expression(p, .None) or_return
		_ = parser_expect(p, .Close_Paren) or_return
		return expr, true
	case:
		parser_error(
			p,
			parser_current(p).pos,
			"Expected an expression, not %s",
			parser_current(p).value,
		)
		return {}, false
	}
}

parse_list :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Open_Bracket) or_return
	items := make([dynamic]Node, allocator = p.allocator)

	if !parser_match(p, .Close_Bracket) {
		for {
			item := parse_expression(p, .None) or_return
			append(&items, item)

			if parser_match(p, .Close_Bracket) {
				break
			}

			_ = parser_expect(p, .Comma) or_return

			if parser_match(p, .Close_Bracket) {
				break
			}
		}
	}

	node := parser_new(p, token.pos, List_Literal{
		contents = items[:]
	})

	return node, true
}

parse_integer :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Integer) or_return

	value, ok := strconv.parse_i64(token.value)
	if !ok {
		panic("Internal error: Tokenizer emitted bad integer")
	}

	node := parser_new(p, token.pos, Integer_Literal {
		value = value
	})

	return node, true
}

parse_identifier :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Identifier) or_return

	node := parser_new(p, token.pos, Variable_Access{
		name = token.value
	})

	return node, true
}


parse_float :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Float) or_return

	value, ok := strconv.parse_f64(token.value)
	if !ok {
		panic("Internal error: Tokenizer emitted bad float")
	}

	node := parser_new(p, token.pos, Float_Literal {
		value = value
	})

	return node, true
}

parse_string :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .String) or_return
	value := token.value[1:len(token.value) - 1]

	output := make([dynamic]byte, len = 0, cap = len(value), allocator = p.allocator)

	read_head := 0
	for read_head < len(value) {
		char := value[read_head]
		read_head += 1
		if char == '\\' {
			switch value[read_head] {
			case 'r':
				append(&output, '\r')
				read_head += 1
			case 'n':
				append(&output, '\n')
				read_head += 1
			case 'v':
				append(&output, '\v')
				read_head += 1
			case 't':
				append(&output, '\t')
				read_head += 1
			case 'a':
				append(&output, '\a')
				read_head += 1
			case 'b':
				append(&output, '\b')
				read_head += 1
			case '0':
				append(&output, '\x00')
				read_head += 1
			case '"':
				append(&output, '\"')
				read_head += 1
			case '\\':
				append(&output, '\\')
				read_head += 1
			}
		} else {
			append(&output, char)
		}
	}

	node := parser_new(p, token.pos, String_Literal{
		value = string(output[:])
	})

	return node, true
}

parser_new :: proc(
	p: ^Parser,
	pos: Source_Pos,
	value: $T,
) -> Node where intrinsics.type_is_variant_of(Node_Contents, ^T) {
	allocated := new_clone(value, p.allocator)

	node := Node {
		position = pos,
		contents = allocated,
	}

	return node
}

parser_match :: proc(p: ^Parser, type: Token_Type) -> bool {
	if parser_current(p).type == type {
		parser_advance(p)
		return true
	}
	return false
}

@(require_results)
parser_expect :: proc(p: ^Parser, type: Token_Type) -> (Token, bool) {
	if parser_current(p).type == type {
		token := parser_current(p)
		parser_advance(p)
		return token, true
	}

	parser_error(
		p,
		parser_current(p).pos,
		"Expected %s but recieved %s",
		type,
		parser_current(p).value,
	)

	return {}, false
}

parser_error :: proc(p: ^Parser, pos: Source_Pos, message: string, args: ..any) {
	formatted_message := fmt.aprintf(message, ..args, allocator = p.error_allocator)

	append(&p.errors, Error{type = .Syntax, pos = pos, message = formatted_message})
}

parser_current :: proc(p: ^Parser) -> Token {
	return p.current_token
}

parser_advance :: proc(p: ^Parser) {
	p.current_token = scan_next_token(&p.tokenizer)
}

parser_resync :: proc(p: ^Parser, special_case: Maybe(Token_Type)) -> bool {
	for {
		if special_case != nil {
			if parser_current(p).type == special_case.? {
				parser_advance(p)
				return true
			}
		}
		#partial switch parser_current(p).type {
		case .Semicolon:
			parser_advance(p)
			return true
		case .Var, .Fun, .Return, .If, .While, .For, .Break, .Continue:
			return true
		case .EOF:
			return false
		case:
			parser_advance(p)
		}
	}
}
