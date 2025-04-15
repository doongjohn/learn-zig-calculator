const builtin = @import("builtin");
const std = @import("std");

const Evaluator = struct {
    const Operator = enum {
        ParenOpen,
        ParenClose,
        Add,
        Sub,
        Mul,
        Div,
        Pow,
    };

    const precedence = std.EnumArray(Operator, u8).initDefault(0, .{
        .Add = 1,
        .Sub = 1,
        .Mul = 2,
        .Div = 2,
        .Pow = 3,
    });

    const right_assoc = std.EnumArray(Operator, bool).initDefault(false, .{
        .Pow = true,
    });

    allocator: std.mem.Allocator,
    output_stack: std.ArrayList(f64),
    operation_stack: std.ArrayList(Operator),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .allocator = allocator,
            .output_stack = std.ArrayList(f64).init(allocator),
            .operation_stack = std.ArrayList(Operator).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.output_stack.deinit();
        self.operation_stack.deinit();
    }

    fn isCodepointWhitespace(codepoint: u21) bool {
        return codepoint == ' ' or codepoint == '\t';
    }

    fn isCodepointNumber(codepoint: u21) bool {
        return codepoint >= '0' and codepoint <= '9';
    }

    pub fn evaluate(self: *@This(), input: []const u8) !f64 {
        const input_view = try std.unicode.Utf8View.init(input);
        var input_iter = input_view.iterator();

        // Shunting yard algorithm
        while (input_iter.nextCodepoint()) |codepoint| {
            if (isCodepointWhitespace(codepoint)) {
                continue;
            }

            if (parseNumber(&input_iter, codepoint)) |num| {
                try self.output_stack.append(num);
                continue;
            }

            switch (codepoint) {
                '(' => try self.handleOperator(.ParenOpen),
                ')' => try self.handleOperator(.ParenClose),
                '+' => try self.handleOperator(.Add),
                '-' => try self.handleOperator(.Sub),
                '*' => try self.handleOperator(.Mul),
                '/' => try self.handleOperator(.Div),
                '^' => try self.handleOperator(.Pow),
                else => {
                    std.debug.print("Unknown operator: {u}\n", .{codepoint});
                    return error.UnknownOperator;
                },
            }
        }

        while (self.operation_stack.items.len != 0) {
            try self.processOperation();
        }

        return self.output_stack.getLast();
    }

    fn parseNumber(input_iter: *std.unicode.Utf8Iterator, codepoint: u21) ?f64 {
        if (isCodepointNumber(codepoint)) {
            var num: f64 = @floatFromInt(codepoint - '0');
            while (true) {
                const peeked = input_iter.peek(1);
                if (peeked.len == 0) {
                    break;
                }
                if (isCodepointNumber(peeked[0])) {
                    num *= 10;
                    num += @floatFromInt(peeked[0] - '0');
                    _ = input_iter.nextCodepoint();
                } else {
                    break;
                }
            }
            return num;
        }
        return null;
    }

    fn handleOperator(self: *@This(), operator: Operator) !void {
        switch (operator) {
            .ParenOpen => {
                try self.operation_stack.append(operator);
            },
            .ParenClose => {
                try self.processUntilParenOpen(operator);
            },
            else => {
                try self.processUntilEnd(operator);
                try self.operation_stack.append(operator);
            },
        }
    }

    fn getLastPrecedence(self: *@This()) u8 {
        if (self.operation_stack.items.len != 0) {
            return precedence.get(self.operation_stack.getLast());
        } else {
            return 0;
        }
    }

    fn processUntilEnd(self: *@This(), operator: Operator) !void {
        while (self.operation_stack.items.len != 0) {
            if (self.getLastPrecedence() < precedence.get(operator)) {
                break;
            }
            if (right_assoc.get(operator) and self.getLastPrecedence() == precedence.get(operator)) {
                break;
            }
            try self.processOperation();
        }
    }

    fn processUntilParenOpen(self: *@This(), operator: Operator) !void {
        while (self.operation_stack.items.len != 0) {
            if (self.operation_stack.getLast() == .ParenOpen) {
                _ = self.operation_stack.pop();
                break;
            }
            if (self.getLastPrecedence() < precedence.get(operator)) {
                break;
            }
            if (right_assoc.get(operator) and self.getLastPrecedence() == precedence.get(operator)) {
                break;
            }
            try self.processOperation();
        }
    }

    fn processOperation(self: *@This()) !void {
        if (self.operation_stack.pop()) |operation| {
            switch (operation) {
                .ParenOpen => {},
                .ParenClose => {},
                .Add => {
                    const b = self.output_stack.pop().?;
                    const a = self.output_stack.pop().?;
                    try self.output_stack.append(a + b);
                },
                .Sub => {
                    const b = self.output_stack.pop().?;
                    const a = self.output_stack.pop().?;
                    try self.output_stack.append(a - b);
                },
                .Mul => {
                    const b = self.output_stack.pop().?;
                    const a = self.output_stack.pop().?;
                    try self.output_stack.append(a * b);
                },
                .Div => {
                    const b = self.output_stack.pop().?;
                    const a = self.output_stack.pop().?;
                    try self.output_stack.append(a / b);
                },
                .Pow => {
                    const b = self.output_stack.pop().?;
                    const a = self.output_stack.pop().?;
                    try self.output_stack.append(std.math.pow(f64, a, b));
                },
            }
        }
    }
};

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const alloc, const is_debug = gpa: {
        if (builtin.os.tag == .wasi) {
            break :gpa .{ std.heap.wasm_allocator, false };
        }
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        std.debug.assert(debug_allocator.deinit() == .ok);
    };

    var evaluator = Evaluator.init(alloc);
    defer evaluator.deinit();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("> ", .{});
    if (try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', 100000)) |input| {
        defer alloc.free(input);

        const input_trimmed = std.mem.trim(u8, input, " \t\r\n");
        const result = try evaluator.evaluate(input_trimmed);
        try stdout.print("= {d}\n", .{result});
    }
}
