const std = @import("std");
const param = @import("parameters.zig");
const text = @import("text.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Collect all the parameters supplied by the user into a struct.
    // If we received null, either parsing failed, or the parameters were invalid.
    // The function prints information to the user, we simply need to return.
    const parameters = try param.getParameters(allocator) orelse return;

    // If the user passed the help flag, print help page and exit.
    if (parameters.help) {
        try param.showHelpPage();
        return;
    }

    // Setup up for reading.
    var input_file = try text.getInputFile(parameters);
    defer input_file.close();
    var br = std.io.bufferedReader(input_file.reader());
    const reader = br.reader();

    // Setup up for writing.
    var output_file = try text.getOutputFile(parameters);
    defer output_file.close();
    var bw = std.io.bufferedWriter(output_file.writer());
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
        // TODO: Maybe try to optimize this?
        _ = try writer.write(&text.color_clear);
        try writer.print("{x:0>8}: ", .{index});

        // Iterate through each byte and print the hex representation.
        // A space will break up line into pairs of bytes, for readability
        for (buf, 0..) |byte, i| {
            // This flag is true if the file contains this byte.
            // This could be false if the file does not have a number of bytes divisible by the column width.
            const known_byte = i < n;

            if (known_byte) {
                // First of the two digit hex number.
                var digit_0: u8 = (byte >> 4) + 48;
                var digit_1: u8 = (byte & 0b1111) + 48;

                if (digit_0 > 57) {
                    digit_0 += (97-58);
                }
                if (digit_1 > 57) {
                    digit_1 += (97-58);
                }

                _ = try writer.write(text.byteColor(byte));

                _ = try writer.write(&[2]u8{digit_0, digit_1});
            } else {
                // If the byte is does not exist, just print a space.
                _ = try writer.write("  ");
            }

            // Print the spacing characters.
            if (i + 1 == parameters.columns)
                _ = try writer.write("  ") // Final byte, double space.
            else if (i % 2 == 1)
                _ = try writer.write(" "); // Second byte of pair, single space.

        }

        // Print the ascii version of the bytes on the right of the line.
        for (buf, ascii) |byte, char| {
            // Color character the same as the byte
            _ = try writer.write(text.byteColor(byte));
            _ = try writer.write(&[1]u8{char});
        }

        _ = try writer.write("\n");

        if (n < parameters.columns) {
            // If we read less than the column width, we have reached the end of the file.
            break;
        }
    }

    _ = try writer.write(&text.color_clear);
    try bw.flush();
}
