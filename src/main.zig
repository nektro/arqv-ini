const std = @import("std");

const Token = struct {
    kind: enum {
        comment, section, identifier, value, equal, link
    },
    value: ?[]const u8
};
const TokenizerState = enum {
    nil,
    comment,
    section,
    identifier,
    value,
    link,
};

// used to convert from string to bool
const booleanMap = std.ComptimeStringHashMap(bool, .{
    .{ "true", true },
    .{ "t", true },
    .{ "yes", true },
    .{ "y", true },
    .{ "false", false },
    .{ "f", false },
    .{ "no", false },
    .{ "n", false },
});

pub fn openC(comptime T: type, comptime filename: []const u8) !T {
    // implement!
}

pub fn openS(comptime T: type, filename: []const u8, allocator: *std.mem.Allocator) !T {
    // implement!
}

pub fn openM(filename: []const u8, allocator: *std.mem.Allocator) !std.StringHashMap([]const u8) {
    var ret = std.StringHashMap([]const u8).init(allocator);
    var file = try std.fs.cwd().openFile(filename, .{ .read = true, .write = true });
    defer file.close();
    var data = try allocator.alloc(u8, try file.getEndPos());
    _ = try file.read(data);

    var seek: usize = 0;
    var state: TokenizerState = .nil;

    while (parseToken(data, &seek, &state)) |token| {
        std.debug.print("{}\n", .{token});
    }

    return ret;
}

fn parseToken(data: []u8, seek: *usize, state: *TokenizerState) ?Token {
    if (seek.* >= data.len) return null;
    var token: Token = std.mem.zeroes(Token);
    var start = seek.*;
    var end = start;
    var char: u8 = 0;

    while (char != '\n') {
        char = data[seek.*];
        seek.* += 1;
        
        switch(state.*) {
            .nil => {
                switch(char) {
                    ';' => {
                        state.* = .comment;
                    },
                    else => {}
                }
            },

            .comment => {
                end += 1;
                switch(char) {
                    '\n' => {
                        state.* = .nil;
                        return Token {
                            .kind = .comment,
                            .value = data[start+2..end]
                        };
                    },
                    else => {}
                }
            },
            
            else => {}
        }
    }
    
    return token;
}


// Tests
test "open INI file as map" {
    std.debug.print("\n", .{});
    var hm = try openM("test.ini", std.heap.page_allocator);
    hm.deinit();
}
