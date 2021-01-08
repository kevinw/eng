// Ported from the MIT licensed "workbench" project by @JoshuaManton
// https://github.com/JoshuaManton/workbench

#import "Basic";
String :: #import "String";

Lexer :: struct {
    lexer_text: string;
    
    lex_idx: int;
    lex_char: int;
    lex_line: int;
}

Token :: struct {
    text: string;
    kind: Token_Kind;
    line: int = -1;
}

make_Token :: inline (text: string, kind: Token_Kind, line := -1) -> Token {
    token: Token;
    token.text = text;
    token.kind = kind;
    token.line = line;
    return token;
}

Token_Kind :: enum {
    Identifier;
    Number;
    String;
    Symbol;
    New_Line;
    EOF;
}

make_lexer :: inline (text: string) -> Lexer {
    lexer: Lexer;
    lexer.lexer_text = text;
    return lexer;
}

get_next_token :: (using lexer: *Lexer, token: *Token, ignore_newline := false, loc := #caller_location) -> bool {
	_token: Token;
	if token == null
		token = *_token;

	if lex_idx >= lexer_text.count {
		<< token = Token.{"", .EOF, -1};
		return false;
	}
	while _is_whitespace(lexer_text[lex_idx]) {
		if !_inc(lexer) {
			<< token = Token.{"", .EOF, -1};
			return false;
		}
	}

	<< token = Token.{};
	token_start_char := lex_char;
	token_start_line := lex_line;

	r := lexer_text[lex_idx];
	if r == #char "\"" {
        if !_inc(lexer) {
            panic(tprint("End of text from within string"));
        }
        start := lex_idx;
        escaped := false;
        while lexer_text[lex_idx] != #char "\"" || escaped {
            escaped = lexer_text[lex_idx] == #char "\\";

            if !_inc(lexer) {
                panic(tprint("End of text from within string"));
            }
        }

        token_text := String.slice(lexer_text, start, lex_idx-start);
        << token = make_Token(token_text, .String, token_start_line);
    } else if is_symbol(r) {
        << token = make_Token(String.slice(lexer_text, lex_idx, 1), .Symbol, token_start_line);
    } else if r == #char "\n" {
        << token = make_Token(String.slice(lexer_text, lex_idx, 0), .New_Line, token_start_line);
    } else if starts_identifier(r) {
        start := lex_idx;
        while true {
            if continues_identifier(lexer_text[lex_idx]) {
                if !_inc(lexer) {
                    break;
                }
            } else {
                break;
            }
        }
        token_text := String.slice(lexer_text, start, lex_idx-start);
        _dec(lexer);
        << token = make_Token(token_text, .Identifier, token_start_line);
    } else if (r >= #char "0" && r <= #char "9") || r == #char "." {
        start := lex_idx;
        found_a_dot := false;
        // todo(josh): handle case with two dots in a float
        while true {
            if lexer_text[lex_idx] == #char "." {
				assert(found_a_dot == false, "expected not to find two dots in a row: '%'", lexer_text);
				found_a_dot = true;
				if !_inc(lexer)
					break;
			} else if is_number(lexer_text[lex_idx]) {
                if !_inc(lexer)
                    break;
            } else {
                break;
            }
        }

        token_text := String.slice(lexer_text, start, lex_idx-start);

        int_val: s64;
        unsigned_int_val: u64;
        float_val: float64;
        parseok: bool;
        if found_a_dot {
            float_val, parseok = string_to_float64(token_text); assert(parseok);
            int_val = cast(s64)float_val;
            unsigned_int_val = cast(u64)float_val;
        }
        else {
			// TODO: we need a string_to_uint
            //unsigned_int_val, parseok = string_to_int(token_text); assert(parseok);
            int_val, parseok = string_to_int(token_text); assert(parseok);
            float_val = cast(float64)int_val;
        }

        _dec(lexer);
        << token = make_Token(token_text, .Number, token_start_line);
    } else {
        print("Unknown token: % at line % column % loc: %\n", lexer_text[lex_idx], token_start_line, token_start_char, loc);
        assert(false);
	}

	_inc(lexer);

	while ignore_newline {
		if token.kind == .New_Line {
			break;
		}
		ok := get_next_token(lexer, token, ignore_newline);
		if !ok {
			<< token = .{}; //token ^= {};
			return false;
		}
	}

	return true;
}

is_token :: (lexer: *Lexer, kind: Token_Kind) -> bool {
	t: Token;
	ok := peek(lexer, *t);
	if !ok return false;

	return t.kind == kind;
}

peek :: (lexer: *Lexer, out_token: *Token, ignore_newline := false) -> bool {
	lexer_copy := << lexer;
	get_next_token(*lexer_copy, out_token, ignore_newline);
	is_end := out_token.kind == .EOF;
	return !is_end;
}

eat :: (lexer: *Lexer) -> bool {
	t: Token;
	ok := get_next_token(lexer, *t);
	return ok;
}

expect :: (lexer: *Lexer, kind: Token_Kind) -> (Token, bool) {
	t: Token;
	ok := get_next_token(lexer, *t);
	if !ok return .{}, false;
	if t.kind != kind return t, false;

	return t, true;
}

expect_symbol :: (lexer: *Lexer, r: string) {
	t: Token;
	ok := get_next_token(lexer, *t);
	if !ok {
		assert(false, "EOF");
	}
	if t.kind == .Symbol {
		if t.text == r {
			return;
		}
		assert(false, "Expected % got %", r, t.text);
	}
	else {
		assert(false, "Expected symbol, got %", t);
	}
}

expect_float :: (lexer: *Lexer) -> float {
	t: Token;
	ok := get_next_token(lexer, *t);
	if !ok {
		assert(false, "EOF");
	}
	if t.kind == .Number {
		float_value, ok := string_to_float(t.text); assert(ok);
		return float_value;
	}
	assert(false, "Expected float, got %", t);
	return 0;
}

expect_string :: (lexer: *Lexer) -> string {
	t: Token;
	ok := get_next_token(lexer, *t);
	if !ok {
		assert(false, "EOF");
	}
	if t.kind == .String {
		return t.text;
	}
	assert(false, "Expected string, got %", t);
	return "";
}

_is_whitespace :: inline (r: u8) -> bool {
    return r == #char " " || r == #char "\r" || r == #char "\t";
}

_dec :: inline (using lexer: *Lexer) {
	lex_idx -= 1;
	lex_char -= 1;
}

_inc :: (using lexer: *Lexer, location := #caller_location) -> bool {
	if lex_idx >= lexer_text.count
        print("%\n", tprint("%", location));
	r := lexer_text[lex_idx];
	lex_idx += 1;

	if r == #char "\n" {
		lex_char = 1;
		lex_line += 1;
	}
	else if r == #char "\t" {
		lex_char += 4;
	}
	else {
		lex_char += 1;
	}

	return lex_idx < lexer_text.count;
}

main :: () {
    input_test_string := #string END
foo 123 1.0 , $ true    	false, "ffffoooooooozle" blabbaaa: 123.0
END;

	print("INPUT: '%'", input_test_string);
	lexer := make_lexer(input_test_string);
	token: Token;
	while get_next_token(*lexer, *token) {
		print("%\n", token);
	}
}


is_symbol :: (c: u32) -> bool {
    return (c >= #char "!" && c <= #char "/") ||
           (c >= #char ":" && c <= #char "@") ||
           (c >= #char "[" && c <= #char "`") ||
           (c >= #char "{" && c <= #char "~");
}

is_hex_number :: (c: u32) -> bool {
    return (c >= #char "a" && c <= #char "f") 
		|| (c >= #char "A" && c <= #char "F") || 
		is_number(c);
}

starts_identifier :: (c: u32) -> bool {
    return c == #char "_" || (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z");
}

continues_identifier :: (c: u32) -> bool {
    return starts_identifier(c) || is_number(c);
}

is_number :: (c: u32) -> bool {
    return c >= #char "0" && c <= #char "9";
}

panic :: (msg: string) {
    assert(false, msg);
}
