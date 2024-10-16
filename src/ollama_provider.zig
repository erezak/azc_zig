const std = @import("std");
const getnev = @import("get_env.zig");

const base_provider = @import("llm_provider.zig");

const ModelList = struct {
    models: []base_provider.Model,
};

const OllamaMessage = struct {
    role: []const u8,
    content: []const u8,
};

const OllamaStreamingResponse = struct {
    model: []const u8,
    created_at: []const u8,
    message: OllamaMessage,
    done: bool,
};
const OllamaStreamingFinalResponse = struct {
    model: []const u8,
    created_at: []const u8,
    message: OllamaMessage,
    done: bool,
    total_duration: u64,
    load_duration: u64,
    prompt_eval_duration: u64,
    eval_count: u64,
    eval_duration: u64,
};

const OllamaChatRequest = struct {
    model: []const u8,
    messages: [](base_provider.Message),
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
        ollama_provider.base.chat = chat;
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
    pub fn chat(self: *base_provider.LLMProvider, message: []const u8, allocator: *std.mem.Allocator) base_provider.Error!void {
        var url_list = try std.ArrayList(u8).initCapacity(allocator.*, self.base_url.len + "/api/chat".len);
        defer url_list.deinit();

        // Append the base URL and the endpoint
        try url_list.appendSlice(self.base_url);
        try url_list.appendSlice("/api/chat");

        const url = try url_list.toOwnedSlice();
        std.debug.print("Parsing URL: '{s}'\n", .{url});
        const uri = try std.Uri.parse(url);

        // Append the user message to the chat history
        try self.messages.append(.{
            .role = "user",
            .content = message,
        });

        const chatMessage = OllamaChatRequest{
            .model = self.model,
            .messages = self.messages.items,
        };

        // Construct JSON payload for the request
        var payload = std.ArrayList(u8).init(allocator.*);
        try std.json.stringify(chatMessage, .{ .whitespace = .minified }, payload.writer());

        const headers_max_size = 1024;

        var client = std.http.Client{ .allocator = allocator.* };
        defer client.deinit();

        const hbuffer = try allocator.alloc(u8, headers_max_size);
        defer allocator.free(hbuffer);

        const options = std.http.Client.RequestOptions{ .server_header_buffer = hbuffer, .handle_continue = true };

        // Create a POST request
        var request = try client.open(std.http.Method.POST, uri, options);
        defer request.deinit();

        request.transfer_encoding = .chunked;

        // Send and finalize the request
        _ = try request.send();
        // Set the request body (payload)
        try request.writeAll(payload.items);
        _ = try request.finish();
        _ = try request.wait();

        // handle bad_request and other errors
        if (request.response.status != std.http.Status.ok) {
            return base_provider.Error.WrongStatusResponse;
        }

        // Read the response body
        const buffer = try allocator.alloc(u8, 10000);
        defer allocator.free(buffer);

        var finalMessage = false;
        var bodyLength: usize = 0;

        while (!finalMessage) {
            bodyLength = try request.read(buffer);
            const currentChunk = std.json.parseFromSlice(OllamaStreamingResponse, allocator.*, buffer[0..bodyLength], std.json.ParseOptions{ .ignore_unknown_fields = true }) catch break;
            defer currentChunk.deinit();
            std.debug.print("{s}", .{currentChunk.value.message.content});
            finalMessage = currentChunk.value.done;
        }

        const finalChunk = try std.json.parseFromSlice(OllamaStreamingFinalResponse, allocator.*, buffer[0..bodyLength], std.json.ParseOptions{ .ignore_unknown_fields = true });
        std.debug.print("{s}", .{finalChunk.value.message.content});
        defer finalChunk.deinit();
    }

    // Build the payload for chat requests
    fn buildPayload(_: *base_provider.LLMProvider, _: *std.mem.Allocator) ![]const u8 {
        // Construct JSON payload for the request (you need proper serialization)
        const payload_str = ""; //try std.fmt.allocPrint(allocator.*, "{ \"model\": \"{}\", \"messages\": {} }", .{ self.model, self.model });
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

    // if self.model is not set, set it to the first model in the list
    if (self.model.len == 0) {
        self.model = self.models.items[0];
    }
}

test "init ollama provider" {
    const expect = std.testing.expect;
    var allocator = std.heap.page_allocator;

    // Initialize the Ollama LLM provider
    const primer = "Limit your response to 300 characters or less";
    var provider = try OllamaLLMProvider.init(&allocator, primer);
    defer provider.deinit(); // Clean up the provider

    var models = try provider.listModels(&allocator);
    defer models.deinit(); // Clean up the models list
    //
    expect(models.items.len > 0);
}

test "chat with ollama provider" {
    const expect = std.testing.expect;
    var allocator = std.heap.page_allocator;
    const primer = "Limit your response to 300 characters or less";
    var provider = try OllamaLLMProvider.init(&allocator, primer);
    defer provider.deinit(); // Clean up the provider
    const message = "Why is the ocean yellow?";
    try provider.chat(&provider, message, &allocator);
    expect(true);
}
