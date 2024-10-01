const std = @import("std");
const getnev = @import("get_env.zig");

const base_provider = @import("llm_provider.zig");

const ModelList = struct {
    models: []base_provider.Model,
};

pub const OllamaLLMProvider = struct {
    base: base_provider.LLMProvider, // Embed the base LLMProvider struct

    // Initialize the OllamaLLMProvider and return the base LLMProvider for polymorphism
    pub fn init(allocator: *std.mem.Allocator, primer: ?[]const u8) !base_provider.LLMProvider {
        // Fetch the base URL from the environment or set to default
        const var_name = "OLLAMA_URL";
        const env_base_url = try getnev.findEnvVariable(var_name, getnev.config_paths[0..]);

        var ollama_provider = OllamaLLMProvider{
            .base = base_provider.LLMProvider.init(allocator),
        };

        ollama_provider.base.base_url = try allocator.dupe(u8, env_base_url orelse "");
        ollama_provider.base.refreshModelList = refreshModelList;
        std.debug.print("Base URL: '{s}'\n", .{ollama_provider.base.base_url});

        // Initialize the model list by calling listModels
        try ollama_provider.base.refreshModelList(&ollama_provider.base, allocator);

        // Set the primer if provided
        if (primer) |p| {
            ollama_provider.base.primer = p;
            try ollama_provider.base.messages.append(.{
                .role = "system",
                .content = p,
            });
        }

        return ollama_provider.base;
    }

    // Deinitialize OllamaLLMProvider
    pub fn deinit(self: *OllamaLLMProvider) void {
        std.heap.page_allocator.free(self.base.base_url);
        self.base.deinit();
    }

    // Chat with the model using Ollama's API and stream the response
    pub fn chat(self: *OllamaLLMProvider, message: []const u8, allocator: *std.mem.Allocator) !std.ArrayList([]const u8) {
        // Append the user message to the chat history
        try self.base.messages.append(.{
            .role = "user",
            .content = message,
        });

        const url = self.base_url ++ "/api/chat";
        const payload = self.buildPayload();

        // Placeholder: Make the POST request and stream the response
        var response = try std.http.Client.post(url, .{
            .body = payload,
            .headers = .{},
            .allocator = allocator,
        });

        var final_message = try std.ArrayList([]const u8).init(allocator);

        // Stream response chunks and build the final message
        while (try response.stream.readChunk()) |chunk| {
            const json_chunk = try std.json.parse(chunk);
            if (json_chunk.get("done").toBool()) {
                break;
            }

            const content = json_chunk.get("message").get("content").toString();
            try final_message.append(content);
        }

        // Append the assistant message to the chat history
        try self.base.messages.append(.{
            .role = "assistant",
            .content = final_message.toSlice(),
        });

        return final_message;
    }

    // Build the payload for chat requests
    fn buildPayload(self: *OllamaLLMProvider) ![]const u8 {
        // Construct JSON payload for the request (you need proper serialization)
        const payload_str = std.fmt.allocPrint("{ \"model\": \"{}\", \"messages\": {} }", .{ self.base.model, self.base.messages });
        return payload_str;
    }
};

pub fn refreshModelList(self: *base_provider.LLMProvider, allocator: *std.mem.Allocator) base_provider.Error!void {
    var url_list = try std.ArrayList(u8).initCapacity(allocator.*, self.base_url.len + "/api/tags".len);

    // Append the base URL and the endpoint
    try url_list.appendSlice(self.base_url);
    try url_list.appendSlice("/api/tags");

    const url = try url_list.toOwnedSlice();
    std.debug.print("Parsing URL: '{s}'\n", .{url});
    const uri = try std.Uri.parse(url);

    const headers_max_size = 1024;
    const body_max_size = 65536;

    var client = std.http.Client{ .allocator = allocator.* };
    defer client.deinit();

    var hbuffer: [headers_max_size]u8 = undefined;
    const options = std.http.Client.RequestOptions{ .server_header_buffer = &hbuffer, .handle_continue = true };

    var request = try client.open(std.http.Method.GET, uri, options);
    defer request.deinit();
    _ = try request.send();
    _ = try request.finish();
    _ = try request.wait();

    if (request.response.status != std.http.Status.ok) {
        return base_provider.Error.WrongStatusResponse;
    }

    // Read the body
    var bbuffer: [body_max_size]u8 = undefined;
    const bytes_read = try request.readAll(&bbuffer);

    // Slice the buffer to the actual size of the content read
    const body = bbuffer[0..bytes_read];

    // Parse the JSON response
    const api_models = try std.json.parseFromSlice(ModelList, allocator.*, body, std.json.ParseOptions{ .ignore_unknown_fields = true });

    // Assuming the JSON response has a key "models" containing an array of strings
    const models_json_array = api_models.value.models;

    var models_list = std.ArrayList([]const u8).init(allocator.*);

    // Populate models_list with the parsed array values
    for (models_json_array) |model_value| {
        try models_list.append(model_value.name);
    }

    self.models = models_list;
}
