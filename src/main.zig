const std = @import("std");
const clap = @import("clap");

const clap_params = clap.parseParamsComptime(
    \\-h, --help           Display this help page.
    \\-f, --infile <str>   Input file.
    \\-o, --outfile <str>  Output file.
);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Collect all the parameters supplied by the user into a struct.
    const parameters = getParameters(allocator) catch {
        // Failed to parse arguments, the user likely mangled the command.
        // Print help page, then exit.
        try showHelpPage();
        return;
    };

    // If the user passed the help flag, print help page and exit.
    if (parameters.help) {
        try showHelpPage();
        return;
    }

    // Setup up for reading.
    // TODO: Replace with system that can read from stdin or a file.
    const stdin_reader = std.io.getStdIn().reader();
    var br = std.io.bufferedReader(stdin_reader);
    const reader = br.reader();

    // Setup up for writing.
    // TODO: Replace with system that can write to stdout or a file.
    const stdout_writer = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_writer);
    const writer = bw.writer();

    // Stores the current line of bytes to be formatted and printed.
    // TODO: Make size of buffer (and all downstream buffers) variable.
    var buf: [16]u8 = undefined;

    // Number of characters actually read. The buffer will not always be filled
    var n: usize = undefined;

    // Index of first byte of line in the file.
    var index: u32 = 0;
    while (true) : (index += 16) {
        // Attempt to read from input. Take note of how many characters were actually read (n).
        n = try reader.read(buf[0..]);

        // If no characters read (i.e. EOF) exit loop.
        if (n == 0) {
            break;
        }

        // Make a copy of buf that we can modify for printing.
        // This forms the ascii representation on the right hand side of the output.
        var ascii: [16]u8 = undefined;
        @memcpy(ascii[0..n], buf[0..n]);

        // Remove things line '\n' and '\t' or else it will distort our formatting.
        sanitizeAscii(&ascii);

        // Print index information on the left of the line (in hex).
        try writer.print("{x:0>8}: ", .{index});

        // Iterate through each byte and print the hex representation.
        // A space will break up line into pairs of bytes, for readability
        for (buf, 0..) |byte, i| {
            // This flag is true if the file contains this byte.
            // This could be false if the file does not have a number of bytes divisible by the column width.
            const known_byte = i < n;

            // Should this byte have a space after it?
            const space = if (i % 2 == 1) " " else "";

            if (known_byte) {
                try writer.print("{x:0>2}{s}", .{ byte, space });
            } else {
                try writer.print("  {s}", .{space});
            }
        }

        // Print the ascii version of the bytes on the right of the line.
        try writer.print(" {s}\n", .{ascii[0..n]});

        try bw.flush();
    }
}

const ParamError = error{
    ParseError,
};

fn getParameters(allocator: std.mem.Allocator) ParamError!ZzdParameters {
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &clap_params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch {
        // TODO: A parsing error is not the only possible error.
        // This catch should be expanded to cover all possible errors.
        return ParamError.ParseError;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        // If the user requested help, we can disregard all other arguments.
        return ZzdParameters{ .help = true };
    }

    return ZzdParameters{
        // If a file was supplied, set that as the input,
        // else, set stdin as the input.
        .input = if (res.args.infile) |f| ZzdParameters.Input{ .file = f } else ZzdParameters.Input.stdin,
        .output = if (res.args.outfile) |f| ZzdParameters.Output{ .file = f } else ZzdParameters.Output.stdout,
    };
}

fn showHelpPage() !void {
    try clap.help(std.io.getStdErr().writer(), clap.Help, &clap_params, .{});
}

/// Replaces all unprintable characters with '.'
fn sanitizeAscii(string: []u8) void {
    for (string) |*char| {
        // If character is not printable in ascii.
        if (!std.ascii.isPrint(char.*)) {
            char.* = '.';
        }
    }
}

const ZzdParameters = struct {
    help: bool = false,
    input: Input = Input.stdin,
    output: Output = Output.stdout,

    const Input = union(enum) {
        stdin: void,
        file: []const u8,
    };

    const Output = union(enum) {
        stdout: void,
        file: []const u8,
    };
};
