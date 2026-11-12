package videolang

Node :: struct {
	contents: Node_Contents,
	position: Source_Pos,
}

Node_Contents :: union {
	^Integer_Literal,
	^Float_Literal,
	^String_Literal,
	^Binary_Expression,
	^Unary_Expression,
	^Call_Expression,
	^Index_Expression,
	^List_Literal,
	^Variable_Access,
	^Field_Access,
	^Function_Declaration,
	^Variable_Declaration,
	^If_Statement,
	^For_Loop,
	^While_Loop,
	^Break_Statement,
	^Continue_Statement,
	^Block_Statement,
	^Return_Statement,
	^Assignment_Statement,
}

Function_Declaration :: struct {
	name: string,
	paramters: []string,
	body: Node,
}

If_Statement :: struct {
	condition: Node,
	if_true: Node,
	if_false: Maybe(Node)
}

For_Loop :: struct {
	variable: string,
	target: Node,
	body: Node
}

While_Loop :: struct {
	condition: Node,
	body: Node
}

Block_Statement :: struct {
	contents: []Node
}

Return_Statement :: struct {
	value: Maybe(Node)
}

Assignment_Statement :: struct {
	target: Node,
	value: Node
}

Variable_Declaration :: struct {
	name: string,
	value: Node
}

Break_Statement :: struct {}
Continue_Statement :: struct {}

Index_Expression :: struct {
	base: Node,
	index: Node,
}

Integer_Literal :: struct {
	value: i64
}

Float_Literal :: struct {
	value: f64
}
String_Literal :: struct {
	value: string
}
Binary_Expression :: struct {
	left, right: Node,
	op: Binary_Operation
}

Unary_Expression :: struct {
	base: Node,
	op: Unary_Operation
}

Call_Expression :: struct {
	base: Node,
	arguments: []Node
}

List_Literal :: struct {
	contents: []Node
}
Variable_Access :: struct {
	name: string
}

Field_Access :: struct {
	base: Node,
	field: string,
}

Binary_Operation :: enum {
	Invalid,
	Add,
	Subtract,
	Multiplication,
	Division,
	Equality,
}

Unary_Operation :: enum {
	Invalid,
	Logical_Not,
	Negation,
}

Binding_Power :: enum {
	None,
	Equality_Left,
	Equality_Right,
	Add_Sub_Left,
	Add_Sub_Right,
	Mul_Div_Left,
	Mul_Div_Right,
	Negation_Not,
}

// -5 + 5

binary_operators := #partial[Token_Type]Binary_Operation {
	.Plus = .Add,
	.Minus = .Subtract,
	.Star = .Multiplication,
	.Slash = .Division,
	.Equals_Equals = .Equality
}

binary_binding_power :: proc(op: Binary_Operation) -> (Binding_Power, Binding_Power) {
	switch op {
	case .Invalid:
		panic("Internal error: Bad operator not caught")
	case .Add, .Subtract:
		return .Add_Sub_Left, .Add_Sub_Right
	case .Multiplication, .Division:
		return .Mul_Div_Left, .Mul_Div_Right
	case .Equality:
		return .Equality_Left, .Equality_Right
	}
	panic("Internal error: Bad operator not caught")
}