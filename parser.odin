package videolang

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
	source: string,
	node_allocator, error_allocator: runtime.Allocator,
) -> (
	Node,
	[dynamic; 32]Error,
) {
	nodes: [dynamic]Node
	nodes.allocator = node_allocator

	parser := Parser {
		tokenizer = {source = source, error_allocator = error_allocator},
		allocator = node_allocator,
		error_allocator = error_allocator,
	}

	parser_advance(&parser)

	node, _ := parse_statements_until(&parser, .EOF)

	errors := parser.errors

	append(&errors, ..parser.tokenizer.errors[:])

	return node, errors
}

parse_statements_until :: proc(p: ^Parser, type: Token_Type) -> (_node: Node, _ok: bool) {
	statements := make([dynamic]Node, allocator = p.allocator)
	
	for !parser_match(p, type) {
		stmt, ok := parse_statement(p)
		if ok {
			append(&statements, stmt)
		} else {
			for !parser_match(p, .Semicolon) && !parser_match(p, .Close_Curly) {
				if parser_match(p, type) || tk_done(&p.tokenizer) {
					break
				}
				parser_advance(p)
			}
		}
	}

	node := parser_new(p, Block_Statement)
	node.contents = statements[:]
	
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
	_ = parser_expect(p, .Fun) or_return
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

	node := parser_new(p, Function_Declaration)

	node.name = name.value
	node.paramters = parameters[:]
	node.body = body
	
	return node, true
}

parse_var_declaration :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Var) or_return
	name := parser_expect(p, .Identifier) or_return
	_ = parser_expect(p, .Equals) or_return
	value := parse_expression(p, .None) or_return
	_ = parser_expect(p, .Semicolon) or_return

	node := parser_new(p, Variable_Declaration)

	node.value = value
	node.name = name.value
	
	return node, true
}

parse_if_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .If) or_return

	condition := parse_expression(p, .None) or_return
	if_true := parse_block_statement(p) or_return

	if_false: Maybe(Node)

	if parser_match(p, .Else) {
		if parser_current(p).type == .If {
			if_false = parse_if_statement(p) or_return
		} else if parser_current(p).type == .Open_Curly {
			if_false = parse_block_statement(p) or_return
		} else {
			parser_error(p, "Expected 'if' or '{' after 'else', but got '%s'", parser_current(p).value)
		}
	}

	node := parser_new(p, If_Statement)
	
	node.condition = condition
	node.if_true = if_true
	node.if_false = if_false
	
	return node, true
}

parse_for_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .For) or_return
	name := parser_expect(p, .Identifier) or_return
	_ = parser_expect(p, .In) or_return
	target := parse_expression(p, .None) or_return
	
	body := parse_block_statement(p) or_return
	
	node := parser_new(p, For_Loop)
	
	node.body = body
	node.target = target
	node.variable = name.value
	
	return node, true
}

parse_while_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .While) or_return

	condition := parse_expression(p, .None) or_return
	body := parse_block_statement(p) or_return

	node := parser_new(p, While_Loop)
	
	node.condition = condition
	node.body = body
	
	return node, true
}

parse_break_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Break) or_return
	_ = parser_expect(p, .Semicolon) or_return

	node := parser_new(p, Break_Statement)
	
	return node, true
}

parse_continue_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Continue) or_return
	_ = parser_expect(p, .Semicolon) or_return

	node := parser_new(p, Continue_Statement)
	
	return node, true
}

parse_block_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Open_Curly) or_return
	return parse_statements_until(p, .Close_Curly)
}

parse_return_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Return) or_return
	value: Maybe(Node)
	if !parser_match(p, .Semicolon) {
		value = parse_expression(p, .None) or_return
		_ = parser_expect(p,.Semicolon) or_return
	}

	node := parser_new(p, Return_Statement)
	node.value = value

	return node, true
}

parse_expression_statement :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	expr, ok := parse_expression(p, .None)
	
	if !ok {
		for !parser_match(p, .Semicolon) {
			if parser_current(p).type == .EOF {
				return {}, false
			}
			parser_advance(p)
		}
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

			node := parser_new(p, Assignment_Statement)
			node.target = left
			node.value = rhs
			
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

		node := parser_new(p, Binary_Expression)
		node.left = left
		node.right = right
		node.op = operator_type

		left = node
	}

	return left, true
}

parse_prefix_expression :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	#partial switch parser_current(p).type {
	case .Minus:
		parser_advance(p)
		base := parse_prefix_expression(p) or_return
		node := parser_new(p, Unary_Expression)
		node.base = base
		node.op = .Negation
		return node, true
	case .Exclamation:
		parser_advance(p)
		base := parse_prefix_expression(p) or_return
		node := parser_new(p, Unary_Expression)
		node.base = base
		node.op = .Logical_Not
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

	node := parser_new(p, Call_Expression)
	node.base = base
	node.arguments = arguments[:]

	return node, true
}

parse_index :: proc(p: ^Parser, base: Node) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Open_Bracket) or_return

	index := parse_expression(p, .None) or_return
	_ = parser_expect(p, .Close_Bracket) or_return

	node := parser_new(p, Index_Expression)
	node.base = base
	node.index = index

	return node, true
}

parse_field_access :: proc(p: ^Parser, base: Node) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Dot) or_return
	field := parser_expect(p, .Identifier) or_return

	node := parser_new(p, Field_Access)
	node.base = base
	node.field = field.value

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
		parser_error(p, "Expected an expression, not %s", parser_current(p).value)
		return {}, false
	}
}

parse_list :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	_ = parser_expect(p, .Open_Bracket) or_return
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

	node := parser_new(p, List_Literal)
	node.contents = items[:]

	return node, true
}

parse_integer :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Integer) or_return

	value, ok := strconv.parse_i64(token.value)
	if !ok {
		panic("Internal error: Tokenizer emitted bad integer")
	}

	node := parser_new(p, Integer_Literal)
	node.value = value

	return node, true
}

parse_identifier :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Identifier) or_return

	node := parser_new(p, Variable_Access)
	node.name = token.value

	return node, true
}


parse_float :: proc(p: ^Parser) -> (_node: Node, _ok: bool) {
	token := parser_expect(p, .Float) or_return

	value, ok := strconv.parse_f64(token.value)
	if !ok {
		panic("Internal error: Tokenizer emitted bad float")
	}

	node := parser_new(p, Float_Literal)
	node.value = value

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

	node := parser_new(p, String_Literal)
	node.value = string(output[:])

	return node, true
}

parser_new :: proc(p: ^Parser, $T: typeid) -> ^T {
	return new(T, p.allocator)
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

	parser_error(p, "Expected %s but recieved %s", type, parser_current(p).value)

	return {}, false
}

parser_error :: proc(p: ^Parser, message: string, args: ..any) {
	formatted_message := fmt.aprintf(message, ..args, allocator = p.error_allocator)

	append(&p.errors, Error{formatted_message})
}

parser_current :: proc(p: ^Parser) -> Token {
	return p.current_token
}

parser_advance :: proc(p: ^Parser) {
	p.current_token = scan_next_token(&p.tokenizer)
}
