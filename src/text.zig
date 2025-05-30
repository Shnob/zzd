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
