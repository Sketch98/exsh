const std = @import("std");
const Allocator = std.mem.Allocator;

var empty_arr = [0]*Triev{};
var empty_str = [0]u8{};

pub fn main() anyerror!void {
    var buf: [4096]u8 = undefined;
    var b = std.heap.FixedBufferAllocator.init(buf[0..]);
    var a = &b.allocator;
    std.debug.print("{}\n", .{@sizeOf(Triev)});

    var root_msg: [36]u8 = "all your permission are belong to us".*;

    const root = try a.create(Triev);
    root.depth = 0;
    root.bit_string = 0;
    root.kids = empty_arr[0..];
    root.val = root_msg[0..];

    try root.insert("Zig", "hey, i just made a new triev", a);
    try root.insert("Zinger", "idk what to put here", a);
    try root.insert("Ziffle", "copy and paste all day", a);
    try root.walk(a);
    try root.remove("Zinger");
    try root.walk(a);
    std.debug.print("\n{}\n\n", .{b.end_index});

    var args = [_:null]?[*:0]const u8{ "echo", "yo", "dawg", "i heard" };
    //const envp = [0:null]?[*:0]const u8{};
    return std.os.execvpeZ(args[0].?, &args, &[0:null]?[*:0]const u8{});
}

// triev as in retrieval. much better alternative to the ambiguous trie imo.
const Triev = struct {
    depth: u8,
    bit_string: u32 = 0,
    kids: []*Triev,
    val: []const u8,
    // walk toward key and return pointer to furthest triev reached
    fn get(self: *Triev, key: []const u8) TrievError!*Triev {
        var cur = self;
        var i: u8 = 0;
        while (i < key.len) : (i += 1) {
            if (cur.bit_string == 0)
                break;
            // std.debug.print("{} {s}\n", .{ cur.depth, cur.val });
            const k = try compress_key(key[i]);
            // std.debug.print("\t{s} {}\n", .{ "looking for", k });
            const bit_flag = @as(u32, 1) << k;
            // assuming very sparse triev, only having one kid is most common
            // and i'm already computing bit_flag for the general case
            if (cur.bit_string == bit_flag) {
                // std.debug.print("\t{s}\n", .{"an only child"});
                cur = cur.kids[0];
            } else if (cur.bit_string & bit_flag != 0) {
                // std.debug.print("\t{s}\n", .{"it exists! now what?"});
                // find number of 1's in bit_string to the right of bit_flag
                const index = hamming_weight((cur.bit_string & ~bit_flag) << 31 - k);
                cur = cur.kids[index];
                // std.debug.print("\t{s} {}\n", .{ "HAMMMMMM", index });
            } else {
                // std.debug.print("\t{s}\n", .{"i don't see nothin'"});
                break;
            }
        }
        // std.debug.print("{} {s}\n\n", .{ cur.depth, cur.val });
        return cur;
    }

    // create a Triev for each byte in key and assign val to last in line
    fn insert(self: *Triev, key: []const u8, val: []const u8, a: *Allocator) !void {
        const t = try self.get(key);
        // i couldn't think of a good name to differentiate the key used for get
        // and insert so ikey (i for insert) it is. the other option was to use
        // key by calculating the correct index everytime, but that's annoying.
        var ikey = key[t.depth..];
        if (ikey.len == 0) {
            t.val = val;
        } else {
            const trievs = try a.alloc(Triev, ikey.len);
            const pointers = try a.alloc([1]*Triev, ikey.len - 1);
            var i: u8 = 0;
            const one: u32 = 1;
            while (true) : (i += 1) {
                trievs[i].depth = t.depth + i + 1;
                if (i == ikey.len - 1)
                    break;
                trievs[i].bit_string = one << try compress_key(ikey[i + 1]);
                trievs[i].val = empty_str[0..];
                trievs[i].kids = pointers[i][0..];
                pointers[i][0] = &trievs[i + 1];
            }
            trievs[i].bit_string = 0;
            trievs[i].kids = empty_arr[0..];
            trievs[i].val = val;

            if (t.bit_string == 0) {
                const p = try a.create([1]*Triev);
                p[0] = &trievs[0];
                t.bit_string = one << try compress_key(ikey[0]);
                t.kids = p;
            } else {
                const p = try a.alloc(*Triev, t.kids.len + 1);
                const bit = try compress_key(ikey[0]);
                const bit_flag = one << bit;
                t.bit_string |= bit_flag;
                const index = hamming_weight((t.bit_string & ~bit_flag) << 31 - bit);
                std.mem.copy(*Triev, p[0..index], t.kids[0..index]);
                p[index] = &trievs[0];
                std.mem.copy(*Triev, p[index + 1 ..], t.kids[index..]);
                t.kids = p[0..];
            }
        }
    }

    // set val of Triev at key to empty string slice if such a Triev exists
    fn remove(self: *Triev, key: []const u8) TrievError!void {
        const t = try self.get(key);
        if (t.depth == key.len)
            t.val = empty_str[0..];
    }

    // this only prints out contents of Triev with debug prints
    // maybe later i'll make it return a list of key-value pairs
    fn walk(self: *Triev, a: *Allocator) !void {
        const StackItem = struct { t: *Triev, kid_index: u5, bit_shift: u5 };
        var cur = self;
        var stack = std.ArrayList(*StackItem).init(a);
        defer stack.deinit();
        var kid_index: u5 = 0;
        var bit_shift: u5 = 0;
        while (true) {
            if (cur.val.len != 0) {
                std.debug.print("key ", .{});
                for (stack.items) |item| std.debug.print("{c}", .{@intCast(u8, item.bit_shift) | 0x40});
                std.debug.print("\n\tval {s}\n", .{cur.val});
            }
            if (cur.kids.len == 0) {
                // pop stack until i reach an item with kids left to walk
                while (true) {
                    if (stack.items.len == 0)
                        return;
                    const item = stack.pop();
                    // popped Triev has no more kids to walk
                    if (item.kid_index == item.t.kids.len - 1)
                        continue;
                    cur = item.t;
                    kid_index = item.kid_index + 1;
                    bit_shift = next_bit(cur.bit_string, item.bit_shift + 1);
                    break;
                }
            } else {
                bit_shift = next_bit(cur.bit_string, 0);
            }
            var item = try a.create(StackItem);
            item.t = cur;
            item.kid_index = kid_index;
            item.bit_shift = bit_shift;
            try stack.append(item);
            cur = cur.kids[kid_index];
            // reset values for new walk
            kid_index = 0;
        }
    }
};

const TrievError = error{
    InvalidKeyByte, //key must only be made of A-Za-Z_
};

// squishes A-Za-z_ ranging 0x41-0x7A (64 bits) into 0x01-0x1F (32 bits)
fn compress_key(key: u8) TrievError!u5 {
    if (key == '_' or (key >= 'A' and key <= 'Z') or (key >= 'a' and key <= 'z'))
        return @intCast(u5, key & 0x1F);
    return TrievError.InvalidKeyByte;
}

// get number of 1's in bit string
// can return u5 because input is guaranteed to not be 0xFFFF_FFFFF
// if only i could just use the x86 instruction but alas
fn hamming_weight(bit_string: u32) u5 {
    var bits = bit_string;
    bits -= (bits >> 1) & 0x55555555;
    bits = (bits & 0x33333333) + ((bits >> 2) & 0x33333333);
    bits = (bits + (bits >> 4)) & 0x0f0f0f0f;
    bits *%= 0x01010101;
    return @intCast(u5, bits >> 24);
}

// find the first bit from the right that's 1 (with pre-shift)
fn next_bit(bit_string: u32, bit_shift: u5) u5 {
    var bits = bit_string >> bit_shift;
    var shift = bit_shift;
    while (bits & 1 == 0) {
        bits >>= 1;
        shift += 1;
    }
    return shift;
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
