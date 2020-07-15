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

pub fn parseIntoStruct(comptime T: type, buffer: []const u8) !T {
    var seek: usize = 0;
    var state: TokenizerState = .nil;
    var val = std.mem.zeroes(T);
    while (parseToken(buffer[0..], &seek, &state)) |token| {
        // TODO: Implement parsing
    }
    return val;
}

const IniMap = std.StringHashMap([]const u8);
pub fn parseIntoMap(buffer: []const u8, allocator: *std.mem.Allocator) !IniMap {
    var seek: usize = 0;
    var state: TokenizerState = .nil;
    var map = IniMap.init(allocator);
    while (parseToken(buffer[0..], &seek, &state)) |token| {
        // TODO: Implement parsing
    }
    return map;
}

fn parseToken(data: []const u8, seek: *usize, state: *TokenizerState) ?Token {
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
test "parse into map" {
    var file = try std.fs.cwd().openFile("src/test.ini", .{ .read = true, .write = false });
    defer file.close();
    var data = try std.testing.allocator.alloc(u8, try file.getEndPos());
    defer std.testing.allocator.free(data);
    _ = try file.read(data);
    var map = parseIntoMap(data, std.testing.allocator);
}

test "parse into struct" {
    var file = try std.fs.cwd().openFile("src/test.ini", .{ .read = true, .write = false });
    defer file.close();
    var data = try std.testing.allocator.alloc(u8, try file.getEndPos());
    defer std.testing.allocator.free(data);
    _ = try file.read(data);

    const Config = struct {
        owner: struct {
            name: []const u8,
            organization: []const u8,
        },
        database: struct {
            server: []const u8,
            port: usize,
            file: []const u8,
        },
    };

    var config = parseIntoStruct(Config, data);
}

test "parse in comptime into struct" {
    comptime {
        const data = @embedFile("test.ini");
        const Config = struct {
            owner: struct {
                name: []const u8,
                organization: []const u8,
            },
            database: struct {
                server: []const u8,
                port: usize,
                file: []const u8,
            },
        };

        var config = parseIntoStruct(Config, data);
    }
}
