# ini
Zig library for opening .ini files.

## usage
```zig
const ini = @import("ini.zig")
const Config = struct {
    section: struct {
        field1: type,
        field2: another_type,
    }
}

var buffer = [_]u8{0} ** 64; // Size may have to vary depending on the size of your strings.
var data = @embedFile("my_ini_file.ini");
var config = ini.parse(Config, data, buffer);
```

## roadmap
* implement `parseIntoMap`
* make code more readable
