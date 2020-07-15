const std = @import("std");

const Token = struct {
    kind: enum {
        nil, comment, section, identifier, value
    },
    value: ?[]const u8
};
const TokenizerState = enum(u3) {
    nil,
    comment,
    section,
    identifier,
    value,
    string
};

const booleanMap = std.ComptimeStringMap(bool, .{
    .{ "true", true },
    .{ "t", true },
    .{ "True", true },
    .{ "T", true },
    .{ "yes", true },
    .{ "y", true },
    .{ "Yes", true },
    .{ "Y", true },
    .{ "false", false },
    .{ "f", false },
    .{ "False", false },
    .{ "F", false },
    .{ "no", false },
    .{ "n", false },
    .{ "No", false },
    .{ "N", false}
});

pub fn parse(comptime T: type, data: []const u8, buffer: []u8) !T {
    var seek: usize = 0;
    var state: TokenizerState = .nil;
    var val = std.mem.zeroes(T);

    var csec: []const u8 = "";
    var cid: []const u8 = "";

    while (parseToken(data[0..], &seek, &state, buffer)) |token| {
        // TODO: Implement parsing
        std.mem.set(u8, buffer, 0);
        
        switch(token.kind) {
            .nil => {},
            .section => {
                csec = token.value.?;
            },
            .identifier => {
                cid = token.value.?;
                var tk = parseToken(data[0..], &seek, &state, buffer).?;
                switch(@typeInfo(T)) {
                    .Struct => |inf| {
                        inline for (inf.fields) |f,i| {
                            if(std.mem.eql(u8, f.name, csec)) {
                                switch(@typeInfo(@TypeOf(@field(val, f.name)))) {
                                    .Struct => |if2| {
                                        inline for (if2.fields) |ff,ii| {
                                                 if(std.mem.eql(u8, ff.name, cid)) {
                                                 const TT = ff.field_type;
                                                 @field(@field(val, f.name), ff.name) = coerce(TT, tk.value.?) catch unreachable; // error.IniInvalidCoerce;
                                             }
                                        }
                                    },
                                    else => {
                                        @compileError("Naked field in archetype.");
                                    }
                                }
                            }
                        }
                    },
                    else => {
                        @compileError("Invalid archetype");
                    }
                }
            },
            .comment => {},
            else => {
                return error.IniSyntaxError;
            }
        }
    }
    return val;
}

fn coerce(comptime T: type, v: []const u8) !T {
    switch(@typeInfo(T)) {
        .Bool => {
            return booleanMap.get(v).?;
        },
        .Float, .ComptimeFloat => {
            return try std.fmt.parseFloat(T, v);
        },
        .Int, .ComptimeInt => {
            return try std.fmt.parseInt(T, v, 10);
        },
        else => {
            return @as(T, v);
        }
    }
    //return std.mem.zeroes(T);
}

const IniMap = std.StringHashMap([]const u8);

// Not working
fn parseIntoMap(data: []const u8, allocator: *std.mem.Allocator, buffer: []u8) !IniMap {
    var seek: usize = 0;
    var state: TokenizerState = .nil;
    var pstate: TokenizerState = .nil;

    var csec: []const u8 = "";
    var cid: []const u8 = "";

    var map = IniMap.init(allocator);
    while (parseToken(data[0..], &seek, &state, buffer)) |token| {
        // TODO: Implement parsing
        std.mem.set(u8, buffer, 0);
        // std.debug.print("{}\n", .{token});
        switch(token.kind) {
            .nil => {},
            .section => {
                csec = token.value.?;
            },
            .identifier => {
                cid = token.value.?;
                var tk = parseToken(data[0..], &seek, &state, buffer).?;
                if (tk.kind == .value) {
                    var len = std.fmt.count("{}.{}", .{csec, cid});
                    _ = try std.fmt.bufPrint(buffer, "{}.{}", .{csec, cid});
                    std.debug.print("Key -> {}\n", .{buffer[0..len]});
                    try map.putNoClobber(buffer[0..len], tk.value.?);
                }
            },
            .comment => {},
            else => {
                return error.IniSyntaxError;
            }
        }
    }
    return map;
}

fn parseToken(data: []const u8, seek: *usize, state: *TokenizerState, buffer: []u8) ?Token {
    if (seek.* >= data.len) return null;
    var token: Token = std.mem.zeroes(Token);
    var start = seek.*;
    var end = start;
    var char: u8 = 0;
    var pointer: usize = 0;
    std.mem.set(u8, buffer, 0);

    @setEvalBranchQuota(100000);
    while (char != '\n') {
        char = data[seek.*];
        seek.* += 1;

        switch(state.*) {
            .nil => {
                switch(char) {
                    ';' => {
                        state.* = .comment;
                        start = seek.*;
                        if (std.ascii.isSpace(data[start])) start += 1;
                        end = start;
                    },
                    '[' => {
                        state.* = .section;
                        start = seek.*;
                        end = start;
                    },
                    '=' => {
                        state.* = .value;
                        start = seek.*;
                        if (std.ascii.isSpace(data[start])) start += 1;
                        end = start;
                    },
                    else => {
                        if(!std.ascii.isSpace(char)) {
                            state.* = .identifier;
                            start = start;
                            end = start;
                        }
                    }
                }
            },

            .identifier => {
                end += 1;
                if(!(std.ascii.isAlNum(char) or char=='_' or char=='-')) {
                    state.* = .nil;
                    return Token {
                        .kind = .identifier,
                        .value = data[start..end]
                    };
                }
            },

            .comment => {
                end += 1;
                switch(char) {
                    '\n' => {
                        state.* = .nil;
                        return Token {
                            .kind = .comment,
                            .value = data[start..end-2]
                        };
                    },
                    else => {}
                }
            },

            .section => {
                end += 1;
                switch(char) {
                    ']' => {
                        state.* = .nil;
                        return Token {
                            .kind = .section,
                            .value = data[start..end-1]
                        };
                    },
                    else => {}
                }
            },

            .value => {               
                switch(char) {
                    '"' => {
                        state.* = .string;
                        std.mem.set(u8, buffer[0..], 0);
                        start = seek.*;
                        end = start;
                    },
                    else => {
                        end += 1;
                        switch(char) {
                            '\n' => {
                                state.* = .nil;
                                return Token {
                                    .kind = .value,
                                    .value = data[start..end-2]
                                };
                            },
                            else => {}
                        }
                    }
                }
            },

            .string => {
                end += 1;
                switch(char) {
                    '\\' => {
                        var nx = data[seek.*];
                        seek.* += 1;
                        switch(nx) {
                            'n' => {
                                buffer[pointer] = '\n';
                                pointer += 1;
                            },
                            '"' => {
                                buffer[pointer] = '"';
                                pointer += 1;
                            },
                            else => {}
                        }
                    },
                    '"' => {
                        state.* = .nil;
                        return Token {
                            .kind = .value,
                            .value = buffer[0..pointer]
                        };
                    },
                    else => {
                        buffer[pointer] = char;
                        pointer += 1;
                    }
                }
            },
            
            else => {}
        }
    }
    
    return token;
}


// Tests
// test "parse into map" {
//     var file = try std.fs.cwd().openFile("src/test.ini", .{ .read = true, .write = false });
//     defer file.close();
//     var data = try std.testing.allocator.alloc(u8, try file.getEndPos());
//     defer std.testing.allocator.free(data);
//     _ = try file.read(data);
//     var buffer = try std.testing.allocator.alloc(u8, 256);  // [1]u8{0} ** 256;
//     defer std.testing.allocator.free(buffer);

//     std.debug.print("\n", .{});
//     var map = try parseIntoMap(data, std.testing.allocator, buffer[0..]);
//     defer map.deinit();

//     for(map.items()) |i| {
//         std.debug.print("{}\n", .{i});
//     }
// }

test "parse into struct" {
    var file = try std.fs.cwd().openFile("src/test.ini", .{ .read = true, .write = false });
    defer file.close();
    var data = try std.testing.allocator.alloc(u8, try file.getEndPos());
    defer std.testing.allocator.free(data);
    _ = try file.read(data);
    var buffer = try std.testing.allocator.alloc(u8, 256);
    defer std.testing.allocator.free(buffer);
    
    const Config = struct {
        owner: struct {
            name: []const u8,
            organization: []const u8,
        },
        database: struct {
            server: []const u8,
            port: usize,
            file: []const u8,
            use: bool,
        },
    };

    var config = try parse(Config, data, buffer[0..]);

    std.testing.expectEqualStrings("John Doe", config.owner.name);
    std.testing.expectEqualStrings("Acme Widgets Inc.", config.owner.organization);
    std.testing.expectEqualStrings("192.0.2.62", config.database.server);
    std.testing.expectEqual(@as(usize, 143), config.database.port);
    std.testing.expectEqualStrings("payroll.dat", config.database.file);
    std.testing.expectEqual(true, config.database.use);
}

test "parse in comptime into struct" {
    const config = comptime block: {
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
                use: bool,
            },
        };
        
        var buffer = [1]u8{0} ** 256;
        var config = try parse(Config, data, buffer[0..]);
        break :block config;
    };
    
    std.testing.expectEqualStrings("John Doe", config.owner.name);
    std.testing.expectEqualStrings("Acme Widgets Inc.", config.owner.organization);
    std.testing.expectEqualStrings("192.0.2.62", config.database.server);
    std.testing.expectEqual(@as(usize, 143), config.database.port);
    std.testing.expectEqualStrings("payroll.dat", config.database.file);
    std.testing.expectEqual(true, config.database.use);
}
