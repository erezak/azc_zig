const std = @import("std");

pub const Error = error{
    HomeNotFound,
    FileReadError,
    EnvVarNotFound,
};

/// Get the value for a given key from ~/.config/.env, ~/.env, or the system environment
pub fn getEnvValue(key: []const u8, allocator: *std.mem.Allocator) !?[]const u8 {
    // File paths
    const config_env_path = "~/.config/.env";
    const home_env_path = "~/.env";

    // Step 1: Check ~/.config/.env
    const config_env = try readEnvFile(config_env_path, key, allocator);
    if (config_env) |value| {
        return value;
    }

    // Step 2: Check ~/.env
    const home_env = try readEnvFile(home_env_path, key, allocator);
    if (home_env) |value| {
        return value;
    }

    // Step 3: Fallback to standard environment variable
    return std.os.getenv(key);
}

// Function to read a key-value pair from an environment file
fn readEnvFile(file_path: []const u8, key: []const u8, allocator: *std.mem.Allocator) !?[]const u8 {
    // Expand the `~` to the user's home directory
    const full_path_buffer = try expandHomePath(file_path, allocator);
    defer allocator.free(full_path_buffer);

    const full_path = full_path_buffer;

    // Open the file if it exists
    var file = if (std.fs.cwd().openFile(full_path, .{}) catch |err| {
        if (err == std.os.File.Error.FileNotFound) {
            return null; // If file does not exist, return null
        } else {
            return err;
        }
    }) |f| f else return null;

    defer file.close();

    // Read the file's contents
    const file_size = try file.fileSize();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    // Search for the key in the file
    const env_content = std.mem.tokenize(buffer, "\n");
    while (env_content.next()) |line| {
        // Split by `=` to get key-value pairs
        const parts = std.mem.tokenize(line, "=");
        if (parts.next() == key) {
            if (parts.next()) |value| {
                return try allocator.dupe(u8, value); // Return the value if key matches
            }
        }
    }

    return null;
}

// Helper function to expand the home directory symbol `~`
fn expandHomePath(path: []const u8, allocator: *std.mem.Allocator) ![]const u8 {
    if (std.mem.startsWith(u8, path, "~")) {
        const home_dir = try std.os.getenv("HOME");
        if (!home_dir) return Error.HomeNotFound;

        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ home_dir.?, path[1..] });
    }
    return try allocator.dupe(u8, path);
}
