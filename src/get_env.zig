const std = @import("std");
const fs = std.fs;

pub const config_paths = [_][]const u8{
    "~/.config/.env",
    "~/.env",
    "./.env",
};
pub fn findEnvVariable(var_name: []const u8, paths: []const []const u8) !?[]const u8 {
    const allocator = std.heap.page_allocator;

    // Check each path for the .env file
    for (paths) |path| {

        // Manually expand `~` to the home directory if necessary
        if (std.mem.startsWith(u8, path, "~")) {
            // Use C's getenv() to fetch the HOME directory
            const home_dir = try getEnvVar("HOME") orelse return error.HomeDirNotFound;

            // Allocate memory for the combined path
            const full_path_len = home_dir.len + (path.len - 1); // Remove `~` length
            var full_path = try allocator.alloc(u8, full_path_len);

            // Copy the home directory and remaining path into full_path
            std.mem.copyForwards(u8, full_path[0..home_dir.len], home_dir);
            std.mem.copyForwards(u8, full_path[home_dir.len..], path[1..]);
            defer allocator.free(full_path);

            const file = fs.cwd().openFile(full_path, .{}) catch |err| {
                // Continue if file not found
                if (err == error.FileNotFound) continue;
                return err;
            };
            defer file.close();

            // Allocate a buffer to read the file
            var buffer: [1024]u8 = undefined; // Adjust size as needed
            const bytes_read = try file.readAll(buffer[0..]);

            // Slice the buffer to the size of the read content
            const env_file = buffer[0..bytes_read];

            const pos = std.mem.indexOf(u8, env_file, var_name);
            if (pos) |index| {
                // Assuming format `VAR_NAME=value` and returning the value
                const value_start = index + var_name.len + 1; // +1 for '='
                std.debug.print("value_start: {}\n", .{value_start});

                const newline_pos = std.mem.indexOf(u8, env_file[value_start..], "\n");
                std.debug.print("newline_pos: {?}\n", .{newline_pos});

                const value_end = if (newline_pos) |newline_idx| value_start + newline_idx else env_file.len;
                std.debug.print("value_end: {}\n", .{value_end});

                if (value_start >= env_file.len or value_start > value_end) {
                    return error.InvalidEnvFileFormat; // Add appropriate error handling
                }

                return env_file[value_start..value_end];
            }
        }
    }

    // If not found in provided paths, check the current directory
    const current_dir_file = fs.cwd().openFile(".env", .{}) catch |err| {
        // If .env file not found in current directory, fallback to getenv
        if (err == error.FileNotFound) {
            return getEnvVar(var_name);
        }
        return err;
    };
    defer current_dir_file.close();

    // Allocate a buffer for the current directory file
    var buffer: [1024]u8 = undefined; // Adjust size as needed
    const bytes_read = try current_dir_file.readAll(buffer[0..]);

    // Slice the buffer to the size of the read content
    const env_file = buffer[0..bytes_read];

    const pos = std.mem.indexOf(u8, env_file, var_name);
    if (pos) |index| {
        // Assuming format `VAR_NAME=value` and returning the value
        const value_start = index + var_name.len + 1; // +1 for '='
        std.debug.print("value_start: {}\n", .{value_start});

        // Find the newline character or the end of the file
        const newline_pos = std.mem.indexOf(u8, env_file[value_start..], "\n");
        const value_end = if (newline_pos) |newline_idx| value_start + newline_idx else env_file.len;
        std.debug.print("value_end: {}\n", .{value_end});

        if (value_start >= env_file.len or value_start > value_end) {
            return error.InvalidEnvFileFormat; // Add appropriate error handling
        }

        // Extract and trim the value
        const extracted_value = env_file[value_start..value_end];

        return extracted_value;
    }

    // Final fallback to C's getenv()
    return getEnvVar(var_name);
}

fn getEnvVar(name: []const u8) !?[]const u8 {
    // Use C's getenv function to get the environment variable
    const c = @cImport(@cInclude("stdlib.h"));
    const allocator = std.heap.page_allocator;
    const c_name = try allocator.dupe(u8, name);
    defer allocator.free(c_name);

    const env_value = c.getenv(c_name.ptr);
    if (env_value) |c_str| {
        // Convert C string to a Zig slice
        const length = std.mem.len(c_str);
        return c_str[0..length];
    } else {
        return null;
    }
}

pub fn main() !void {
    const var_name = "OLLAMA_URL";

    const result = findEnvVariable(var_name, config_paths[0..]) catch |err| {
        std.debug.print("Error finding environment variable: {}\n", .{err});
        return;
    };

    if (result) |value| {
        std.debug.print("Environment variable found: {s}\n", .{value});
    } else {
        std.debug.print("Environment variable '{s}' not found\n", .{var_name});
    }
}
