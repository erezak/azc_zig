const std = @import("std");
const OllamaLLMProvider = @import("ollama_provider.zig").OllamaLLMProvider;

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    // Initialize the Ollama LLM provider
    const primer = "Limit your response to 300 characters or less";
    var provider = try OllamaLLMProvider.init(&allocator, primer);
    defer provider.deinit(); // Clean up the provider

    // Test listModels functionality
    std.debug.print("Listing available models...\n", .{});

    var models = try provider.listModels(&allocator);
    defer models.deinit(); // Clean up the models list

    std.debug.print("Available models:\n", .{});
    for (models.items) |model| {
        std.debug.print("- {s}\n", .{model});
    }
}
