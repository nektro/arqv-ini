# ini
Zig library for opening `.ini` files.

## usage
assuming that the file at `path` contains the following:
```ini
[root]
integer = -1345
string = My string
boolean = enabled
```

### `parse()`
```zig
// Load file into memory.
var fd = try std.fs.cwd().openFile(path, .{ .read = true });
defer fd.close();
var fc = try allocator.alloc(u8, try fd.getEndPos());
defer allocator.free(fc);
// Construct schema type.
const ExampleConfig = struct {
    root: struct {
        integer: i64,
        string: []const u8,
        boolean: bool
    }
}
// Parse `.ini` from memory
var conf = parse(ExampleConfig, fc);
```

### `parse()` in `comptime` block
```zig
comptime {
    // Load file.
    const fc = @embedFile("path/to/file.ini");
    // Construct schema type
    const ExampleConfig = struct {
        root: struct {
            integer: i64,
            string: []const u8,
            boolean: bool
        }
    }
    // Parse `.ini`
    var conf = parse(ExampleConfig, fc);
}
```

### `parseIntoMap()`
```zig
// Load file into memory.
var fd = try std.fs.cwd().openFile(path, .{ .read = true });
defer fd.close();
var fc = try allocator.alloc(u8, try fd.getEndPos());
defer allocator.free(fc);
// Parse `.ini` from memory.
var ini = try parseIntoMap(fc, allocator);
defer ini.deinit();

// `ini.map` now contains a hash map with the contents.
```

## spec
a `.ini` file is composed of:
- comments: starting with `;` up to the end of the line
- sections: enclosed with `[]`
- identifiers: alphanumeric + `_`
- values:
  - numbers: integers or float, parsed by Zig
  - booleans:
    - truthy: `1`, `true`, `True`, `t`, `T`, `yes`, `Yes`, `y`, `Y`, `on`, `On`, `enabled`, `Enabled`
    - falsey: `0`, `false`, `False`, `f`, `F`, `no`, `No`, `n`, `N`, `off`, `Off`, `disabled`, `Disabled`
  - strings: non-escaped text

types only make sense when parsing into a struct, when parsing to a map,
all values get coerced to `[]const u8`

the `.ini` file should have at least one section, no
orphan keys are allowed

## roadmap
- [x] implement `parseIntoMap`
- [ ] make code more readable
