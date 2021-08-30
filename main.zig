const std = @import("std");

pub fn main() anyerror!void {
    var empty_arr = [0]*Triev{};
    var kid_msg: [25]u8 = "just some snot-nosed brat".*;
    comptime var i = 0;
    var kids: [32]*Triev = undefined;
    inline while (i < kids.len) : (i += 1) {
        kids[i] = &Triev{ .bit_string = i * i, .kids = empty_arr[0..], .val = kid_msg[0..] };
    }
    var root_msg: [36]u8 = "all your permission are belong to us".*;
    const triev = Triev{ .bit_string = 0xFFFF_FFFF, .kids = kids[0..], .val = root_msg[0..] };
    std.debug.print("{} {s}\n", .{ triev.bit_string, triev.val });
    for (triev.kids) |kid| {
        std.debug.print("{} {s}\n", .{ kid.bit_string, kid.val });
    }
    var args = [_:null]?[*:0]const u8{ "echo", "yo", "dawg", "i heard" };
    //const envp = [0:null]?[*:0]const u8{};
    return std.os.execvpeZ(args[0].?, &args, &[0:null]?[*:0]const u8{});
}

// triev as in retrieval. much better alternative to the ambiguous trie imo.
const Triev = struct { bit_string: u32 = 0, kids: []*Triev, val: []u8 };

const TrievError = error{
    InvalidKeyByte, //key must only be made of A-Za-Z_
    KeyTooLong,
};
const max_key_len = 256;

// squishes A-Za-z_ ranging 0x41-0x7A (64 bits) into 0x01-0x1F (32 bits)
fn compress_key(key: []u8) TrievError!void {
    if (key.len > max_key_len)
        return TrievError.KeyTooLong;
    for (key) |char, i| {
        if (char == '_' or (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z')) {
            key[i] &= 0x1F;
        } else {
            return TrievError.InvalidKeyByte;
        }
    }
}

const expect = std.testing.expect;

test "compress" {
    var automatic: [13]u8 = "Charlie_Daisy".*;
    const manual = [_]u8{ 0x03, 0x08, 0x01, 0x12, 0x0C, 0x09, 0x05, 0x1F, 0x04, 0x01, 0x09, 0x13, 0x19 };
    compress_key(&automatic) catch unreachable;
    for (automatic) |char, i| {
        try expect(char == manual[i]);
    }
    var bad_key = [_]u8{ 0x00, 0x07, 0x15 };
    compress_key(&bad_key) catch |err|
        try expect(err == TrievError.InvalidKeyByte);
    var long_key = [_]u8{ 0x5A, 0x69, 0x67 } ** 100;
    compress_key(&long_key) catch |err|
        try expect(err == TrievError.KeyTooLong);
}
