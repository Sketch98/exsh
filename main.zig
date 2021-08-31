const std = @import("std");
const Allocator = std.mem.Allocator;

var empty_arr = [0]*Triev{};
var empty_str = [0]u8{};

pub fn main() anyerror!void {
    var buf: [2048]u8 = undefined;
    var b = std.heap.FixedBufferAllocator.init(buf[0..]);
    var a = &b.allocator;
    std.debug.print("{}\n", .{@sizeOf(Triev)});

    var root_msg: [36]u8 = "all your permission are belong to us".*;
    var kid_msg: [25]u8 = "just some snot-nosed brat".*;
    var grandkid_msg: [16]u8 = "a wee little bab".*;

    const root = try a.create(Triev);
    root.depth = 0;
    root.bit_string = 0xFFFF_FFFF;
    root.kids = try a.alloc(*Triev, 32);
    root.val = root_msg[0..];

    const kids = try a.alloc(Triev, 32);
    comptime var i = 0;
    inline while (i < 32) : (i += 1) {
        kids[i].depth = 1;
        kids[i].bit_string = 0;
        kids[i].kids = empty_arr[0..];
        kids[i].val = kid_msg[0..];
        root.kids[i] = &kids[i];
    }

    const grandkid = try a.create(Triev);
    grandkid.depth = 2;
    grandkid.bit_string = 0;
    grandkid.kids = empty_arr[0..];
    grandkid.val = grandkid_msg[0..];
    kids[5].bit_string = 0x0000_0200;
    kids[5].kids = try a.alloc(*Triev, 1);
    kids[5].kids[0] = grandkid;
    std.debug.print("{}\n", .{b.end_index});

    var key: [4]u8 = "Zig_".*;
    var val: [28]u8 = "hey, i just made a new triev".*;
    const t = try root.get(key[0..]);
    std.debug.print("\n", .{});
    if (t.depth != key.len)
        try t.insert(key[t.depth..], val[0..], a);
    _ = try root.get(key[0..]);

    var args = [_:null]?[*:0]const u8{ "echo", "yo", "dawg", "i heard" };
    //const envp = [0:null]?[*:0]const u8{};
    return std.os.execvpeZ(args[0].?, &args, &[0:null]?[*:0]const u8{});
}

// triev as in retrieval. much better alternative to the ambiguous trie imo.
const Triev = struct {
    depth: u8,
    bit_string: u32 = 0,
    kids: []*Triev,
    val: []u8,
    // walk toward key and return pointer to furthest triev reached
    fn get(self: *Triev, key: []u8) TrievError!*Triev {
        var cur = self;
        var i: u8 = 0;
        while (i < key.len) : (i += 1) {
            if (cur.bit_string == 0)
                break;
            std.debug.print("{} {s}\n", .{ cur.depth, cur.val });
            const k = try compress_key(key[i]);
            std.debug.print("{s} {}\n", .{ "looking for", k });
            const bit_flag = @as(u32, 1) << k;
            // assuming very sparse triev, only having one kid is most common
            // and i'm already computing bit_flag for the general case
            if (cur.bit_string == bit_flag) {
                std.debug.print("{s}\n", .{"an only child"});
                cur = cur.kids[0];
            } else if (cur.bit_string & bit_flag != 0) {
                std.debug.print("{s}\n", .{"it exists! now what?"});
                // -1 because we want array index which is 0-based
                const index = hamming_weight(cur.bit_string >> k) - 1;
                cur = cur.kids[index];
                std.debug.print("{s} {}\n", .{ "HAMMMMMM", index });
            } else {
                std.debug.print("{s}\n", .{"i don't see nothin'"});
                break;
            }
        }
        std.debug.print("{} {s}\n", .{ cur.depth, cur.val });
        return cur;
    }

    // create a Triev for each byte in key and assign val to last in line
    // TODO: figure out how to union of TrievError or AllocatorError
    fn insert(self: *Triev, key: []u8, val: []u8, a: *Allocator) TrievError!void {
        if (key.len == 0) {
            self.val = val;
        } else {
            const trievs = a.alloc(Triev, key.len) catch unreachable;
            const pointers = a.alloc([1]*Triev, key.len) catch unreachable;
            var i: u8 = 0;
            const one: u32 = 1;
            while (true) : (i += 1) {
                pointers[i][0] = &trievs[i];
                trievs[i].depth = self.depth + i + 1;
                if (i == key.len - 1)
                    break;
                trievs[i].bit_string = one << try compress_key(key[i + 1]);
                trievs[i].kids = pointers[i + 1][0..];
                trievs[i].val = empty_str[0..];
            }
            self.bit_string = one << try compress_key(key[0]);
            self.kids = pointers[0][0..];
            trievs[i].bit_string = 0;
            trievs[i].kids = empty_arr[0..];
            trievs[i].val = val;
        }
    }
};

const TrievError = error{
    InvalidKeyByte, //key must only be made of A-Za-Z_
    KeyTooLong,
};

// squishes A-Za-z_ ranging 0x41-0x7A (64 bits) into 0x01-0x1F (32 bits)
fn compress_key(key: u8) TrievError!u5 {
    if (key == '_' or (key >= 'A' and key <= 'Z') or (key >= 'a' and key <= 'z'))
        return @intCast(u5, key & 0x1F);
    return TrievError.InvalidKeyByte;
}

// if only i could just use the x86 instruction but alas
fn hamming_weight(bit_string: u32) u5 {
    var bits = bit_string;
    bits -= (bits >> 1) & 0x55555555;
    bits = (bits & 0x33333333) + ((bits >> 2) & 0x33333333);
    bits = (bits + (bits >> 4)) & 0x0f0f0f0f;
    bits *%= 0x01010101;
    return @intCast(u5, bits >> 24);
}

const expect = std.testing.expect;

test "compress" {
    var automatic: [13]u8 = "Charlie_Daisy".*;
    const manual = [_]u5{ 0x03, 0x08, 0x01, 0x12, 0x0C, 0x09, 0x05, 0x1F, 0x04, 0x01, 0x09, 0x13, 0x19 };
    for (automatic) |char, i| {
        const c = try compress_key(char);
        try expect(c == manual[i]);
    }
    _ = compress_key(0x15) catch |err|
        try expect(err == TrievError.InvalidKeyByte);
}
