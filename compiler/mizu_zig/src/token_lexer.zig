const std = @import("std");
const io = std.io;
const fs = std.fs;
const dir: fs.Dir = fs.cwd();
const ArrayList = std.ArrayList;
const mem = std.mem;

const TerminalSpec = struct { spec: []const u8, name: []const u8 };

const MatchSpec = struct { spec: []const u8, name: []const u8 };

const TokenTags = enum { terminal, match };

const TokenSpec = union(TokenTags) {
    terminal: TerminalSpec,
    match: MatchSpec,
};

test "test_tokenize" {
    const SpecList = [_]TokenSpec{
        TokenSpec{ .terminal = TerminalSpec{ .spec = "api"[0..], .name = "KW_API"[0..] } },
        TokenSpec{ .match = MatchSpec{ .spec = "[_a-zA-Z][_a-zA-Z0-9]*"[0..], .name = "identifier"[0..] } },
    };
}

// ast assembly objects

test "test_load_file" {
    const print = std.debug.print;
    print("\n", .{});
    defer print("test complete \n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;

    print("hello {s}\n", .{"world"});
    var file = try std.fs.cwd().openFile("grammar/types/test.mizu", .{ .read = true });

    defer file.close();

    const file_size = try file.getEndPos();

    // var buffer: []u8 = try alloc.alloc(u8, file_size);
    var buffer: []u8 = try file.reader().readAllAlloc(alloc, file_size * 2);

    print("allocated buffer of size={d} bytes\n", .{buffer.len});
    print("file contents:\n{s}\n", .{buffer});
}
