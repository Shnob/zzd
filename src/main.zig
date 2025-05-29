const std = @import("std");
const clap = @import("clap");

const clap_params = clap.parseParamsComptime(
    \\-h, --help           Display this help page.
    \\-f, --infile <str>   Input file. Will use stdin if not specified.
    \\-o, --outfile <str>  Output file. Will use stdout if not specified.
    \\-c, --columns <u16>  Number of bytes per column. Default: 16. Max: 65535.
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
    var zzd_reader = try ZzdReader.init(allocator, parameters);
    defer zzd_reader.deinit();
    var br = std.io.bufferedReader(zzd_reader.reader.*);
    const reader = br.reader();

    // Setup up for writing.
    var zzd_writer = try ZzdWriter.init(allocator, parameters);
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
        sanitizeAscii(ascii);

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
    }
}

const ZzdReader = struct {
    aa: std.heap.ArenaAllocator,
    reader: *std.io.AnyReader,

    fn init(allocator: std.mem.Allocator, parameters: ZzdParameters) !ZzdReader {
        switch (parameters.input) {
            ZzdParameters.Input.stdin => return try ZzdReader.initStdinReader(allocator),
            ZzdParameters.Input.file => |f| return try ZzdReader.initFileReader(allocator, f),
        }
    }

    fn initStdinReader(allocator: std.mem.Allocator) !ZzdReader {
        var zzd_reader = ZzdReader{
            .aa = std.heap.ArenaAllocator.init(allocator),
            .reader = undefined,
        };

        const stdin_reader = try zzd_reader.aa.allocator().create(std.fs.File.Reader);
        stdin_reader.* = std.io.getStdIn().reader();

        const reader = try zzd_reader.aa.allocator().create(std.io.AnyReader);
        reader.* = stdin_reader.any();

        zzd_reader.reader = reader;

        return zzd_reader;
    }

    fn initFileReader(allocator: std.mem.Allocator, file_name: []const u8) !ZzdReader {
        var zzd_reader = ZzdReader{
            .aa = std.heap.ArenaAllocator.init(allocator),
            .reader = undefined,
        };

        const file = try zzd_reader.aa.allocator().create(std.fs.File);
        file.* = try std.fs.cwd().openFile(file_name, .{ .mode = std.fs.File.OpenMode.read_only });

        const file_reader = try zzd_reader.aa.allocator().create(std.fs.File.Reader);
        file_reader.* = file.reader();

        const reader = try zzd_reader.aa.allocator().create(std.io.AnyReader);
        reader.* = file_reader.any();

        zzd_reader.reader = reader;

        return zzd_reader;
    }

    fn deinit(self: ZzdReader) void {
        self.aa.deinit();
    }
};

const ZzdWriter = struct {
    aa: std.heap.ArenaAllocator,
    writer: *std.io.AnyWriter,

    fn init(allocator: std.mem.Allocator, parameters: ZzdParameters) !ZzdWriter {
        switch (parameters.output) {
            ZzdParameters.Output.stdout => return try ZzdWriter.initStdoutWriter(allocator),
            ZzdParameters.Output.file => |f| return try ZzdWriter.initFileWriter(allocator, f),
        }
    }

    fn initStdoutWriter(allocator: std.mem.Allocator) !ZzdWriter {
        var zzd_writer = ZzdWriter{
            .aa = std.heap.ArenaAllocator.init(allocator),
            .writer = undefined,
        };

        const stdout_writer = try zzd_writer.aa.allocator().create(std.fs.File.Writer);
        stdout_writer.* = std.io.getStdOut().writer();

        const writer = try zzd_writer.aa.allocator().create(std.io.AnyWriter);
        writer.* = stdout_writer.any();

        zzd_writer.writer = writer;

        return zzd_writer;
    }

    fn initFileWriter(allocator: std.mem.Allocator, file_name: []const u8) !ZzdWriter {
        var zzd_writer = ZzdWriter{
            .aa = std.heap.ArenaAllocator.init(allocator),
            .writer = undefined,
        };

        const file = try zzd_writer.aa.allocator().create(std.fs.File);
        file.* = try std.fs.cwd().createFile(file_name, .{});

        const file_writer = try zzd_writer.aa.allocator().create(std.fs.File.Writer);
        file_writer.* = file.writer();

        const writer = try zzd_writer.aa.allocator().create(std.io.AnyWriter);
        writer.* = file_writer.any();

        zzd_writer.writer = writer;

        return zzd_writer;
    }

    fn deinit(self: ZzdWriter) void {
        self.aa.deinit();
    }
};

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

    // Create default parameter list.
    var parameters = ZzdParameters{};

    // Modify the default parameters with user specified ones.
    if (res.args.infile) |f|
        parameters.input = ZzdParameters.Input{ .file = f };

    if (res.args.outfile) |f|
        parameters.output = ZzdParameters.Output{ .file = f };

    if (res.args.columns) |c|
        parameters.columns = c;

    return parameters;
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
    // NOTE: All parameters must have a default.
    help: bool = false,
    input: Input = Input.stdin,
    output: Output = Output.stdout,
    columns: u16 = 16,

    const Input = union(enum) {
        stdin: void,
        file: []const u8,
    };

    const Output = union(enum) {
        stdout: void,
        file: []const u8,
    };
};
