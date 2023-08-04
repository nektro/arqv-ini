const std = @import("std");

const Token = struct {
    kind: enum {
        nil,
        comment,
        section,
        identifier,
        value,
    },
    value: ?[]const u8,
};
const TokenizerState = enum(u3) {
    nil,
    comment,
    section,
    identifier,
    value,
    string,
};

const booleanMap = std.ComptimeStringMap(bool, .{
    .{ "1", true },
    .{ "enabled", true },
    .{ "Enabled", true },
    .{ "on", true },
    .{ "On", true },
    .{ "true", true },
    .{ "t", true },
    .{ "True", true },
    .{ "T", true },
    .{ "yes", true },
    .{ "y", true },
    .{ "Yes", true },
    .{ "Y", true },
    .{ "0", false },
    .{ "disabled", false },
    .{ "Disabled", false },
    .{ "off", false },
    .{ "Off", false },
    .{ "false", false },
    .{ "f", false },
    .{ "False", false },
    .{ "F", false },
    .{ "no", false },
    .{ "n", false },
    .{ "No", false },
    .{ "N", false },
});

pub fn parse(comptime T: type, data: []const u8) !T {
    var seek: usize = 0;
    var state = TokenizerState.nil;
    var val = std.mem.zeroes(T);
    var csec: []const u8 = undefined;
    var cid: []const u8 = undefined;

    while (consume(data[0..], &seek, &state)) |token| {
        switch (token.kind) {
            .nil, .comment => {},
            .section => csec = token.value.?,
            .identifier => {
                cid = token.value.?;
                const tk = consume(data[0..], &seek, &state).?;
                if (tk.kind != .value)
                    return error.IniSyntaxError;
                const info1 = @typeInfo(T);
                if (info1 != .Struct)
                    @compileError("Invalid Archetype");

                inline for (info1.Struct.fields) |f| {
                    if (std.mem.eql(u8, f.name, csec)) {
                        const info2 = @typeInfo(@TypeOf(@field(val, f.name)));
                        if (info2 != .Struct)
                            @compileError("Naked field in archetype");

                        inline for (info2.Struct.fields) |ff| {
                            if (std.mem.eql(u8, ff.name, cid)) {
                                const TT = ff.field_type;
                                @field(@field(val, f.name), ff.name) = coerce(TT, tk.value.?) catch unreachable; // error.IniInvalidCoerce;
                            }
                        }
                    }
                }
            },
            else => return error.IniSyntaxError,
        }
    }
    return val;
}

fn coerce(comptime T: type, v: []const u8) !T {
    return switch (@typeInfo(T)) {
        .Bool => booleanMap.get(v).?,
        .Float, .ComptimeFloat => try std.fmt.parseFloat(T, v),
        .Int, .ComptimeInt => try std.fmt.parseInt(T, v, 10),
        else => @as(T, v),
    };
}

const IniMap = std.StringHashMap([]const u8);
pub const IniResult = struct {
    map: IniMap,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *IniResult) void {
        defer self.map.deinit();
        var iter = self.map.iterator();
        while (iter.next()) |i|
            self.allocator.free(i.key_ptr.*);
    }
};

pub fn parseIntoMap(data: []const u8, allocator: std.mem.Allocator) !IniResult {
    var seek: usize = 0;
    var state = TokenizerState.nil;
    var csec: []const u8 = undefined;
    var cid: []const u8 = undefined;
    var map = IniMap.init(allocator);

    while (consume(data[0..], &seek, &state)) |token| {
        switch (token.kind) {
            .nil, .comment => {},
            .section => csec = token.value.?,
            .identifier => {
                cid = token.value.?;
                var tk = consume(data[0..], &seek, &state).?;
                if (tk.kind != .value)
                    return error.IniSyntaxError;
                var coc = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ csec, cid });
                try map.put(coc, tk.value.?);
            },
            else => return error.IniSyntaxError,
        }
    }
    return IniResult{ .map = map, .allocator = allocator };
}

fn consume(data: []const u8, seek: *usize, state: *TokenizerState) ?Token {
    if (seek.* >= data.len) return null;
    var token: Token = std.mem.zeroes(Token);
    var start = seek.*;
    var end = start;
    var char: u8 = 0;

    @setEvalBranchQuota(100000);
    while (char != '\n') {
        char = data[seek.*];
        seek.* += 1;
        switch (state.*) {
            .nil => {
                switch (char) {
                    ';', '#' => {
                        state.* = .comment;
                        start = seek.*;
                        if (std.ascii.isWhitespace(data[start])) start += 1;
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
                        if (std.ascii.isWhitespace(data[start])) start += 1;
                        end = start;
                    },
                    else => {
                        if (!std.ascii.isWhitespace(char)) {
                            state.* = .identifier;
                            start = start;
                            end = start;
                        } else {
                            start += 1;
                            end += 1;
                        }
                    },
                }
            },
            .identifier => {
                end += 1;
                if (!(std.ascii.isAlphanumeric(char) or char == '_')) {
                    state.* = .nil;
                    return Token{
                        .kind = .identifier,
                        .value = data[start..end],
                    };
                }
            },
            .comment => {
                end += 1;
                switch (char) {
                    '\n' => {
                        state.* = .nil;
                        return Token{
                            .kind = .comment,
                            .value = data[start..@max(start, end - 2)],
                        };
                    },
                    else => {},
                }
            },
            .section => {
                end += 1;
                switch (char) {
                    ']' => {
                        state.* = .nil;
                        return Token{
                            .kind = .section,
                            .value = data[start .. end - 1],
                        };
                    },
                    else => {},
                }
            },
            .value => {
                switch (char) {
                    ';', '#' => {
                        state.* = .comment;
                        return Token{
                            .kind = .value,
                            .value = data[start .. end - 2],
                        };
                    },
                    else => {
                        end += 1;
                        switch (char) {
                            '\n' => {
                                state.* = .nil;
                                return Token{
                                    .kind = .value,
                                    .value = data[start .. end - 2],
                                };
                            },
                            else => {},
                        }
                    },
                }
            },
            else => {},
        }
    }

    return token;
}

test "parse into map" {
    var file = try std.fs.cwd().openFile("src/test.ini", .{ .mode = .read_only });
    defer file.close();
    var data = try std.testing.allocator.alloc(u8, try file.getEndPos());
    defer std.testing.allocator.free(data);
    _ = try file.read(data);

    var ini = try parseIntoMap(data, std.testing.allocator);
    defer ini.deinit();

    try std.testing.expectEqualStrings("John Doe", ini.map.get("owner.name").?);
    try std.testing.expectEqualStrings("Acme Widgets Inc.", ini.map.get("owner.organization").?);
    try std.testing.expectEqualStrings("192.0.2.62", ini.map.get("database.server").?);
    try std.testing.expectEqualStrings("143", ini.map.get("database.port").?);
    try std.testing.expectEqualStrings("payroll.dat", ini.map.get("database.file").?);
    try std.testing.expectEqualStrings("yes", ini.map.get("database.use").?);
    try std.testing.expectEqualStrings("bar", ini.map.get("withtabs.foo").?);
}

test "parse into struct" {
    var file = try std.fs.cwd().openFile("src/test.ini", .{ .mode = .read_only });
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
            use: bool,
        },
    };

    var config = try parse(Config, data);

    try std.testing.expectEqualStrings("John Doe", config.owner.name);
    try std.testing.expectEqualStrings("Acme Widgets Inc.", config.owner.organization);
    try std.testing.expectEqualStrings("192.0.2.62", config.database.server);
    try std.testing.expectEqual(@as(usize, 143), config.database.port);
    try std.testing.expectEqualStrings("payroll.dat", config.database.file);
    try std.testing.expectEqual(true, config.database.use);
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

        var config = try parse(Config, data);
        break :block config;
    };

    try std.testing.expectEqualStrings("John Doe", config.owner.name);
    try std.testing.expectEqualStrings("Acme Widgets Inc.", config.owner.organization);
    try std.testing.expectEqualStrings("192.0.2.62", config.database.server);
    try std.testing.expectEqual(@as(usize, 143), config.database.port);
    try std.testing.expectEqualStrings("payroll.dat", config.database.file);
    try std.testing.expectEqual(true, config.database.use);
}
