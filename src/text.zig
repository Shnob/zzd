const std = @import("std");
const param = @import("parameters.zig");

// This file is a collection of functions for reading/writing text,
// as well as other text related tasks.

/// Struct for storing either a stdin reader, or a file reader.
/// Handles memory related to these object.
pub const ZzdReader = struct {
    // Everything is allocated in with an arena allocator to make clean up easy.
    aa: std.heap.ArenaAllocator,
    reader: *std.io.AnyReader,

    /// Initialize the reader as required by the passed parameters.
    fn init(allocator: std.mem.Allocator, parameters: param.ZzdParameters) !ZzdReader {
        switch (parameters.input) {
            param.ZzdParameters.Input.stdin => return try ZzdReader.initStdinReader(allocator),
            param.ZzdParameters.Input.file => |f| return try ZzdReader.initFileReader(allocator, f),
        }
    }

    /// Code for initializing the stdin version of this struct.
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

    /// For initializing the file version of this struct.
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

    /// Clean up all memory allocated for this reader.
    fn deinit(self: ZzdReader) void {
        self.aa.deinit();
    }
};

pub const ZzdWriter = struct {
    // Everything is allocated in with an arena allocator to make clean up easy.
    aa: std.heap.ArenaAllocator,
    writer: *std.io.AnyWriter,

    /// Initialize the reader as required by the passed parameters.
    fn init(allocator: std.mem.Allocator, parameters: param.ZzdParameters) !ZzdWriter {
        switch (parameters.output) {
            param.ZzdParameters.Output.stdout => return try ZzdWriter.initStdoutWriter(allocator),
            param.ZzdParameters.Output.file => |f| return try ZzdWriter.initFileWriter(allocator, f),
        }
    }

    /// Code for initializing the stdout version of this struct.
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

    /// For initializing the file version of this struct.
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

    /// Clean up all memory allocated for this writer.
    fn deinit(self: ZzdWriter) void {
        self.aa.deinit();
    }
};

/// Replaces all unprintable characters with '.'
pub fn sanitizeAscii(string: []u8) void {
    for (string) |*char| {
        // If character is not printable in ascii.
        if (!std.ascii.isPrint(char.*)) {
            char.* = '.';
        }
    }
}
