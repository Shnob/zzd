const std = @import("std");
const clap = @import("clap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const parameters = try getParameters(gpa.allocator());

    const input = try getInputReader(parameters);
    const reader = input.reader;
    defer input.close();

    var buf: [64]u8 = undefined;
    const n = try reader.read(buf[0..]);

    std.debug.print("Read: {s}\n", .{buf[0..n]});
}

fn getParameters(allocator: std.mem.Allocator) !ZzdParameters {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help Display this help.
        \\-f, --infile <str> Input file.
        \\-o, --outfile <str> Output file.
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    return ZzdParameters{
        // If a file was supplied, set that as the input,
        // else, set stdin as the input.
        .input = if (res.args.infile) |f| ZzdInput{ .file = f } else ZzdInput.stdin,
        .output = if (res.args.outfile) |f| ZzdOutput{ .file = f } else ZzdOutput.stdout,
    };
}

const ZzdInputReader = struct {
    reader: std.io.AnyReader,
    file: ?std.fs.File = null,

    const Self = @This();

    fn close(self: Self) void {
        if (self.file) |file| {
            file.close();
        }
    }
};

fn getInputReader(parameters: ZzdParameters) !ZzdInputReader {
    switch (parameters.input) {
        ZzdInput.stdin => {
            std.debug.print("STDIN\n", .{});
            return ZzdInputReader{
                .reader = std.io.getStdIn().reader().any(),
            };
        },
        ZzdInput.file => |f| {
            std.debug.print("FILE: {s}\n", .{f});
            const file = try std.fs.cwd().openFile(f, .{});

            return ZzdInputReader{
                .reader = file.reader().any(),
                .file = file,
            };
        },
    }
}

const ZzdInput = union(enum) {
    stdin: void,
    file: []const u8,
};

const ZzdOutput = union(enum) {
    stdout: void,
    file: []const u8,
};

const ZzdParameters = struct {
    input: ZzdInput,
    output: ZzdOutput,
};
