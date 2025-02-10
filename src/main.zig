const std = @import("std");
const OllamaLLMProvider = @import("ollama_provider.zig").OllamaLLMProvider;

fn stringExists(array: []const []const u8, target: []const u8) bool {
    for (array) |item| {
        if (std.mem.eql(u8, item, target)) {
            return true;
        }
    }
    return false;
}

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();
    var allocator = std.heap.page_allocator;

    // Initialize the Ollama LLM provider
    const primer = "Limit your response to 300 characters or less";
    var provider = try OllamaLLMProvider.init(&allocator, primer);
    defer provider.deinit(); // Clean up the provider

    // Mock-up to hold available providers; could be extended based on user requirements.
    const providers = [_][]const u8{ "ollama", "openai", "anthropic", "gemini" };
    var done = false;

    std.debug.print("Welcome to azc in Zig! Type 'h' or '?' for help.\n", .{});

    while (!done) {
        try stdout.print("\nazc> ", .{}); // Prompt
        const line = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);

        const trimmed = std.mem.trim(u8, line, " \t\n\r");

        if (std.mem.eql(u8, trimmed, "q") or std.mem.eql(u8, trimmed, "quit")) {
            done = true;
            continue;
        } else if (std.mem.eql(u8, trimmed, "h") or std.mem.eql(u8, trimmed, "?")) {
            // Display help
            try stdout.print(helpText(), .{});
            continue;
        } else if (std.mem.eql(u8, trimmed, "l")) {
            var models = try provider.listModels(&allocator);
            defer models.deinit(); // Clean up the models list

            try stdout.print("Available models:\n", .{});
            for (models.items) |model| {
                try stdout.print("- {s}\n", .{model});
            }
            continue;
        } else if (std.mem.eql(u8, trimmed, "n")) {
            // Start new chat
            try provider.newChat(primer);
            continue;
        } else if (std.mem.eql(u8, trimmed, "r")) {
            // Refresh models
            try provider.refreshModelList(&provider, &allocator);
            continue;
        } else if (std.mem.eql(u8, trimmed, "m")) {
            // Model selection (interactive)
            try stdout.print("Enter model name: ", .{});
            const new_model = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);
            defer allocator.free(new_model);
            try provider.setModel(new_model);
            continue;
        } else if (std.mem.startsWith(u8, trimmed, "p ")) {
            // Provider selection
            const new_provider_name = trimmed[2..];
            if (!stringExists(providers[0..], new_provider_name)) {
                std.debug.print("Provider {s} not found.\n", .{new_provider_name});
            } else {
                //TODO: Implement provider switching
                std.debug.print("Switched to provider: {s}\n", .{new_provider_name});
            }
            continue;
        }

        // Process the user message
        if (!std.mem.eql(u8, trimmed, "")) {
            std.debug.print("Processing message...\n", .{});
            try provider.chat(&provider, trimmed, &allocator);
        }
        allocator.free(line);
    }

    std.debug.print(":wave: Goodbye!\n", .{});
}

fn helpText() []const u8 {
    return 
    \\ Just type your message and press enter to start a chat.
    \\ Available commands:
    \\
    \\ | Command | Description                 |
    \\ |---------|-----------------------------|
    \\ | l       | List models                 |
    \\ | r       | Refresh models              |
    \\ | n       | New chat                    |
    \\ | h       | Help (this screen)          |
    \\ | m       | Change model                |
    \\ | p       | Change provider             |
    \\ | q       | Quit                        |
    \\
    ;
}
