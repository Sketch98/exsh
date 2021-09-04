const std = @import("std");
const triev = @import("triev");

const empty_arr = [0]*Triev{};
const empty_str = [0]u8{};

pub fn main() anyerror!void {
    var buf: [16_700_000]u8 = undefined;
    var b = std.heap.FixedBufferAllocator.init(buf[0..]);
    var a = &b.allocator;

    var root_msg: [36]u8 = "all your permission are belong to us".*;

    const root = try a.create(triev.TrievManager);
    root.init();
    root.t.val = root_msg[0..];

    try root.insert("Zig", "hey, i just made a new triev", a);
    try root.insert("Zinger", "idk what to put here", a);
    try root.insert("Zif_fle", "copy and paste all day", a);
    // uncommend if you dare
    // try root.insert("z" ** 250_000, "so tired", a);
    try root.walk(a);
    try root.remove("Zinger");
    try root.walk(a);
    std.debug.print("\n{}\n\n", .{b.end_index});

    var args = [_:null]?[*:0]const u8{ "echo", "yo", "dawg", "i heard" };
    //const envp = [0:null]?[*:0]const u8{};
    return std.os.execvpeZ(args[0].?, &args, &[0:null]?[*:0]const u8{});
}
