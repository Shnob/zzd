const std = @import("std");
const clap = @import("clap");

const clap_params = clap.parseParamsComptime(
    \\-h, --help           Display this help page.
    \\-f, --infile <str>   Input file. Will use stdin if not specified.
    \\-o, --outfile <str>  Output file. Will use stdout if not specified.
    \\-c, --columns <u16>  Number of bytes per column. Default: 16. Max: 65535.
);

pub fn getParameters(allocator: std.mem.Allocator) ParamError!ZzdParameters {
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

pub fn showHelpPage() !void {
    try clap.help(std.io.getStdErr().writer(), clap.Help, &clap_params, .{});
}

pub const ZzdParameters = struct {
    // NOTE: All parameters must have a default.
    help: bool = false,
    input: Input = Input.stdin,
    output: Output = Output.stdout,
    columns: u16 = 16,

    pub const Input = union(enum) {
        stdin: void,
        file: []const u8,
    };

    pub const Output = union(enum) {
        stdout: void,
        file: []const u8,
    };
};

pub const ParamError = error{
    ParseError,
};
