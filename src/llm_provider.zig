const std = @import("std");

pub const Error = error{ HttpError, MethodNotImplemented, ModelNotFound, NetworkError, EndOfStream, OutOfMemory, ConnectionResetByPeer, ConnectionTimedOut, ConnectionRefused, NetworkUnreachable, TemporaryNameServerFailure, NameServerFailure, UnknownHostName, HostLacksNetworkAddresses, UnexpectedConnectFailure, TlsInitializationFailed, UnsupportedUriScheme, UnexpectedWriteFailure, InvalidContentLength, UnsupportedTransferEncoding, Overflow, InvalidCharacter, UriMissingHost, CertificateBundleLoadFailure, UnexpectedCharacter, InvalidFormat, InvalidPort, NotWriteable, MessageTooLong, MessageNotCompleted, TlsFailure, TlsAlert, UnexpectedReadFailure, HttpChunkInvalid, HttpHeadersOversize, HttpHeadersInvalid, HttpHeaderContinuationsUnsupported, HttpTransferEncodingUnsupported, HttpConnectionHeaderUnsupported, CompressionUnsupported, TooManyHttpRedirects, RedirectRequiresResend, HttpRedirectLocationMissing, HttpRedirectLocationInvalid, CompressionInitializationFailed, WrongStatusResponse, DecompressionFailure, InvalidTrailers, UnexpectedToken, InvalidNumber, InvalidEnumTag, DuplicateField, UnknownField, MissingField, LengthMismatch, SyntaxError, UnexpectedEnfq, ValueTooLong, BufferUnderRun, UnexpectedEndOfInput, BufferUnderrun };

pub const Model = struct {
    name: []const u8,
};

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const LLMProvider = struct {
    name: []const u8,
    provider: []const u8,

    base_url: []const u8,

    messages: std.ArrayList(Message),
    primer: []const u8,
    model: []const u8,
    models: std.ArrayList([]const u8),

    refreshModelList: *const fn (*LLMProvider, *std.mem.Allocator) Error!void = LLMProvider.methodNotImplemented,
    chat: *const fn (*LLMProvider, []const u8) Error!std.mem.Allocator = LLMProvider.chatNotImplemented,

    pub fn init(allocator: *std.mem.Allocator) LLMProvider {
        return LLMProvider{
            .name = "",
            .provider = "",
            .messages = std.ArrayList(Message).init(allocator.*),
            .primer = "",
            .model = "",
            .models = std.ArrayList([]const u8).init(allocator.*),
            .base_url = "",
        };
    }

    pub fn deinit(self: *LLMProvider) void {
        self.messages.deinit();
        self.models.deinit();
    }

    pub fn new_chat(self: *LLMProvider, primer: []const u8) void {
        // Clear messages list
        self.messages.clear();

        // Set primer
        if (primer.len > 0) {
            self.primer = primer;
        }

        // If primer is present, add it as a "system" role message
        if (self.primer.len > 0) {
            const message = Message{
                .role = "system",
                .content = self.primer,
            };
            try self.messages.append(message);
        }
    }

    // Convert messages to a JSON string
    pub fn messagesAsJson(self: *LLMProvider, allocator: *std.mem.Allocator) ![]const u8 {
        var json_writer = std.json.StringifyBuffer.init(allocator);
        defer json_writer.deinit();

        try json_writer.writer.print("[", .{});

        var is_first = true;
        for (self.messages.items) |message| {
            // Add comma between messages if not the first message
            if (!is_first) {
                try json_writer.writer.print(",", .{});
            }
            is_first = false;

            // Construct JSON object for the message
            try json_writer.writer.print("{{\"role\":\"{s}\",\"content\":\"{s}\"}}", .{ message.role, message.content });
        }

        // Close the JSON array
        try json_writer.writer.print("]", .{});

        return json_writer.toOwnedSlice();
    }

    pub fn listModels(self: *LLMProvider, allocator: *std.mem.Allocator) !std.ArrayList([]const u8) {
        // Create a new ArrayList to hold the copied models
        var models_copy = std.ArrayList([]const u8).init(allocator.*);

        // Copy each model in the original list to the new list
        for (self.models.items) |model| {
            try models_copy.append(model);
        }

        return models_copy;
    }

    pub fn nUserMessages(self: *LLMProvider) usize {
        var count: usize = 0;
        for (self.messages.items) |message| {
            if (std.mem.eql(u8, message.role, "user")) {
                count += 1;
            }
        }
        return count;
    }

    pub fn setModel(self: *LLMProvider, model_name: []const u8) Error!void {
        for (self.models.items) |model| {
            if (std.mem.eql(u8, model, model_name)) {
                self.model = model;
                return;
            }
        }
        return Error.ModelNotFound;
    }

    pub fn str(self: *LLMProvider) []const u8 {
        return std.heap.format("{}:{}", .{ self.provider, self.model });
    }

    pub fn chatNotImplemented(_: *LLMProvider, _: []const u8) Error!std.mem.Allocator {
        return Error.MethodNotImplemented; // Placeholder for unimplemented function
    }

    // Default implementations that return MethodNotImplemented
    fn methodNotImplemented(_: *LLMProvider, _: *std.mem.Allocator) Error!void {
        return Error.MethodNotImplemented;
    }
};
