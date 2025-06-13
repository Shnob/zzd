const std = @import("std");
const param = @import("parameters.zig");

// This file is a collection of functions for reading/writing text,
// as well as other text related tasks.

/// Return the input file the user selected (stdin is also a file).
pub fn getInputFile(parameters: param.ZzdParameters) !std.fs.File {
    return switch (parameters.input) {
        param.ZzdParameters.Input.stdin => std.io.getStdIn(),
        param.ZzdParameters.Input.file => |f| try std.fs.cwd().openFile(f, .{}),
    };
}

/// Return the output file the user selected (stdout is also a file).
pub fn getOutputFile(parameters: param.ZzdParameters) !std.fs.File {
    return switch (parameters.output) {
        param.ZzdParameters.Output.stdout => std.io.getStdOut(),
        param.ZzdParameters.Output.file => |f| try std.fs.cwd().createFile(f, .{}),
    };
}

/// Replaces all unprintable characters with '.'
pub fn sanitizeAscii(string: []u8) void {
    for (string) |*char| {
        // If character is not printable in ascii.
        if (!std.ascii.isPrint(char.*)) {
            char.* = '.';
        }
    }
}

/// ANSI color code for green
pub const color_green = [7]u8{ 0x1b, '[', '1', ';', '3', '2', 'm' };
/// ANSI color code for yellow
pub const color_yellow = [7]u8{ 0x1b, '[', '1', ';', '3', '3', 'm' };
/// ANSI color code for red
pub const color_red = [7]u8{ 0x1b, '[', '1', ';', '3', '1', 'm' };
/// ANSI color code for the null byte
pub const color_blue = [7]u8{ 0x1b, '[', '1', ';', '3', '4', 'm' };
/// ANSI color code for the null byte
pub const color_null = [7]u8{ 0x1b, '[', '1', ';', '3', '7', 'm' };
/// ANSI clear color code
pub const color_clear = [4]u8{ 0x1b, '[', '0', 'm' };

/// Returns ANSI color code appropriate for byte
pub fn byteColor(byte: u8) *const [7]u8 {
    // Null is a special case.
    if (byte == 0) {
        return &color_null;
    }

    // 0xff is also a special case
    if (byte == 0xff) {
        return &color_blue;
    }

    // If byte is printable, return green.
    if (std.ascii.isPrint(byte)) {
        return &color_green;
    }

    // xxd has these special cases as yellow.
    if (byte == 0x09 or byte == 0x0a or byte == 0x0d) {
        return &color_yellow;
    }

    // Otherwise, return red.
    return &color_red;
}
