const std = @import("std");
const param = @import("parameters.zig");
const text = @import("text.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Collect all the parameters supplied by the user into a struct.
    const parameters = param.getParameters(allocator) catch {
        // Failed to parse arguments, the user likely mangled the command.
        // Print help page, then exit.
        try param.showHelpPage();
        return;
    };

    // If the user passed the help flag, print help page and exit.
    if (parameters.help) {
        try param.showHelpPage();
        return;
    }

    // Setup up for reading.
    var zzd_reader = try text.ZzdReader.init(allocator, parameters);
    defer zzd_reader.deinit();
    var br = std.io.bufferedReader(zzd_reader.reader.*);
    const reader = br.reader();

    // Setup up for writing.
    var zzd_writer = try text.ZzdWriter.init(allocator, parameters);
    defer zzd_writer.deinit();
    var bw = std.io.bufferedWriter(zzd_writer.writer.*);
    const writer = bw.writer();

    // Stores the current line of bytes to be formatted and printed.
    var buf = try allocator.alloc(u8, parameters.columns);
    defer allocator.free(buf);

    // Stores a copy of buf, modified for ascii printing.
    var ascii = try allocator.alloc(u8, buf.len);
    defer allocator.free(ascii);

    // Number of characters actually read. The buffer will not always be filled.
    var n: usize = undefined;

    // Index of first byte of line in the file.
    var index: u32 = 0;
    while (true) : (index += parameters.columns) {
        // Attempt to read from input. Take note of how many characters were actually read (n).
        n = try reader.read(buf[0..]);

        // If no characters read (i.e. EOF) exit loop.
        if (n == 0) {
            break;
        }

        // Copy buf to ascii, so that it can be independently modified.
        @memcpy(ascii[0..n], buf[0..n]);

        // Remove things line '\n' and '\t' or else it will distort our formatting.
        text.sanitizeAscii(ascii);

        // Print index information on the left of the line (in hex).
        try writer.print("{x:0>8}: ", .{index});

        // Iterate through each byte and print the hex representation.
        // A space will break up line into pairs of bytes, for readability
        for (buf, 0..) |byte, i| {
            // This flag is true if the file contains this byte.
            // This could be false if the file does not have a number of bytes divisible by the column width.
            const known_byte = i < n;

            // Should this byte have a (double?) space after it?
            const space =
                if (i + 1 == parameters.columns)
                "  " // Final byte, double space.
            else if (i % 2 == 1)
                " " // Second byte of pair, single space.
            else
                ""; // First byte of pair, no space.

            if (known_byte) {
                try writer.print("{x:0>2}{s}", .{ byte, space });
            } else {
                try writer.print("  {s}", .{space});
            }
        }

        // Print the ascii version of the bytes on the right of the line.
        try writer.print("{s}\n", .{ascii[0..n]});

        try bw.flush();

        if (n < parameters.columns) {
            // If we read less than the column width, we have reached the end of the file.
            break;
        }
    }
}
