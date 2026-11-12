package videolang

import "core:fmt"
import "core:strings"

print_ast :: proc(node: Node) {
	builder: strings.Builder

	print_node(node, &builder, 0)

	fmt.println(strings.to_string(builder))
	strings.builder_destroy(&builder)
}

print_node :: proc(node: Node, buf: ^strings.Builder, indent: int) {
	switch type in node.contents {
	case ^Integer_Literal:
		print_integer_literal(type, buf, indent)
	case ^Float_Literal:
		print_float_literal(type, buf, indent)
	case ^String_Literal:
		print_string_literal(type, buf, indent)
	case ^Binary_Expression:
		print_binary_expression(type, buf, indent)
	case ^Unary_Expression:
		print_unary_expression(type, buf, indent)
	case ^Call_Expression:
		print_call_expression(type, buf, indent)
	case ^Index_Expression:
		print_index_expression(type, buf, indent)
	case ^List_Literal:
		print_list_literal(type, buf, indent)
	case ^Variable_Access:
		print_variable_access(type, buf, indent)
	case ^Field_Access:
		print_field_access(type, buf, indent)
	case ^Function_Declaration:
		print_function_declaration(type, buf, indent)
	case ^Variable_Declaration:
		print_variable_declaration(type, buf, indent)
	case ^If_Statement:
		print_if_statement(type, buf, indent)
	case ^For_Loop:
		print_for_loop(type, buf, indent)
	case ^While_Loop:
		print_while_loop(type, buf, indent)
	case ^Break_Statement:
		print_break_statement(type, buf, indent)
	case ^Continue_Statement:
		print_continue_statement(type, buf, indent)
	case ^Block_Statement:
		print_block_statement(type, buf, indent)
	case ^Return_Statement:
		print_return_statement(type, buf, indent)
	case ^Assignment_Statement:
		print_assignment_statement(type, buf, indent)
	}
}

print_function_declaration :: proc(
	node: ^Function_Declaration,
	buf: ^strings.Builder,
	indent: int,
) {
	fmt.sbprintln(buf, "Function Declaration {")
	
	print_indent(buf, indent + 1)
	fmt.sbprintfln(buf, "Name: %s", node.name)
	print_indent(buf, indent + 1)
	fmt.sbprintln(buf, "Parameters: [")

	for parameter in node.paramters {
		print_indent(buf, indent + 2)
		fmt.sbprintln(buf, parameter)
	}

	print_indent(buf, indent + 1)
	fmt.sbprintln(buf, "]")

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Body: ")
	print_node(node.body, buf, indent + 1)
	
	print_indent(buf, indent)
	fmt.sbprintln(buf, "}")
}

print_variable_declaration :: proc(
	node: ^Variable_Declaration,
	buf: ^strings.Builder,
	indent: int,
) {
	fmt.sbprintln(buf, "Variable Declaration {")
	print_indent(buf, indent + 1)
	fmt.sbprintfln(buf, "Name: %s", node.name)

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Value: ")
	print_node(node.value, buf, indent + 1)

	print_indent(buf, indent)
	fmt.sbprintln(buf, "}")
}

print_if_statement :: proc(node: ^If_Statement, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "If Statement {")
	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Condition: ")
	print_node(node.condition, buf, indent + 1)
	
	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "If true: ")
	print_node(node.if_true, buf, indent + 1)

	if node.if_false != nil {
		print_indent(buf, indent + 1)
		fmt.sbprint(buf, "If false: ")
		print_node(node.if_false.?, buf, indent + 1)
	}

	print_indent(buf, indent)
	fmt.sbprintln(buf, "}")
}

print_for_loop :: proc(node: ^For_Loop, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "For loop {")
	print_indent(buf, indent + 1)
	fmt.sbprintfln(buf, "Variable: %s", node.variable)
	
	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Target: ")
	print_node(node.target, buf, indent + 1)
	
	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Body: ")
	print_node(node.body, buf, indent + 1)
	
	print_indent(buf, indent)
	fmt.sbprintln(buf, "}")
}

print_while_loop :: proc(node: ^While_Loop, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "While loop {")
	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Condition: ")
	print_node(node.condition, buf, indent + 1)
	
	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Body: ")
	print_node(node.body, buf, indent + 1)
	
	print_indent(buf, indent)
	fmt.sbprintln(buf, "}")
}

print_break_statement :: proc(node: ^Break_Statement, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Break statement {}")
}

print_continue_statement :: proc(node: ^Continue_Statement, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Continue statement {}")
}

print_block_statement :: proc(node: ^Block_Statement, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Block statement [")

	for statement in node.contents {
		print_indent(buf, indent + 1)
		print_node(statement, buf, indent + 1)
	}
	
	print_indent(buf, indent)
	fmt.sbprintln(buf, "]")
}

print_return_statement :: proc(node: ^Return_Statement, buf: ^strings.Builder, indent: int) {
	if node.value == nil {
		fmt.sbprintln(buf, "Return statement {}")
	} else {
		fmt.sbprintln(buf, "Return statement {")
		
		print_indent(buf, indent + 1)
		fmt.sbprint(buf, "Value: ")
		print_node(node.value.?, buf, indent + 1)
		
		print_indent(buf, indent)
		fmt.sbprintln(buf, "}")
	}
}

print_assignment_statement :: proc(
	node: ^Assignment_Statement,
	buf: ^strings.Builder,
	indent: int,
) {
	fmt.sbprintln(buf, "Assignment Statement { ")

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Target: ")
	print_node(node.target, buf, indent + 1)

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Value: ")
	print_node(node.value, buf, indent + 1)

	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_integer_literal :: proc(expr: ^Integer_Literal, buf: ^strings.Builder, indent: int) {
	fmt.sbprintfln(buf, "Integer {{ %d }", expr.value)
}

print_float_literal :: proc(expr: ^Float_Literal, buf: ^strings.Builder, indent: int) {
	fmt.sbprintfln(buf, "Float {{ %f }", expr.value)
}

print_string_literal :: proc(expr: ^String_Literal, buf: ^strings.Builder, indent: int) {
	fmt.sbprintfln(buf, "String {{ %q }", expr.value)
}

print_binary_expression :: proc(expr: ^Binary_Expression, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Binary Expression { ")

	print_indent(buf, indent + 1)
	fmt.sbprintfln(buf, "Operation: %s", expr.op)

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Left: ")
	print_node(expr.left, buf, indent + 1)

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Right: ")
	print_node(expr.right, buf, indent + 1)

	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_unary_expression :: proc(expr: ^Unary_Expression, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Unary Expression { ")

	print_indent(buf, indent + 1)
	fmt.sbprintfln(buf, "Operation: %s", expr.op)

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Base: ")
	print_node(expr.base, buf, indent + 1)


	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_call_expression :: proc(expr: ^Call_Expression, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Call Expression { ")

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Base: ")
	print_node(expr.base, buf, indent + 1)

	print_indent(buf, indent + 1)
	fmt.sbprintln(buf, "Arguments: [")

	for expr in expr.arguments {
		print_indent(buf, indent + 2)
		print_node(expr, buf, indent + 2)
	}

	print_indent(buf, indent + 1)
	fmt.sbprintln(buf, "]")

	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_index_expression :: proc(expr: ^Index_Expression, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Index Expression { ")

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Base:")
	print_node(expr.base, buf, indent + 1)

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Index:")
	print_node(expr.index, buf, indent + 1)

	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_list_literal :: proc(expr: ^List_Literal, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "List Literal { ")

	print_indent(buf, indent + 1)
	fmt.sbprintln(buf, "Items: [")

	for expr in expr.contents {
		print_indent(buf, indent + 2)
		print_node(expr, buf, indent + 2)
	}

	print_indent(buf, indent + 1)
	fmt.sbprintln(buf, "]")

	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_variable_access :: proc(expr: ^Variable_Access, buf: ^strings.Builder, indent: int) {
	fmt.sbprintfln(buf, "Variable {{ %s }", expr.name)

}

print_field_access :: proc(expr: ^Field_Access, buf: ^strings.Builder, indent: int) {
	fmt.sbprintln(buf, "Field Expression { ")

	print_indent(buf, indent + 1)
	fmt.sbprint(buf, "Base: ")
	print_node(expr.base, buf, indent + 1)

	print_indent(buf, indent + 1)
	fmt.sbprintfln(buf, "Field: %s", expr.field)

	print_indent(buf, indent)
	fmt.sbprintfln(buf, "}")
}

print_indent :: proc(buf: ^strings.Builder, indent: int) {
	for _ in 0 ..< indent {
		fmt.sbprint(buf, "    ")
	}
}
