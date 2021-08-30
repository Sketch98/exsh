const std = @import("std");

pub fn main() anyerror!void {
    var args = [_:null]?[*:0]const u8{ "echo", "yo", "dawg", "i heard" };
    //const envp = [0:null]?[*:0]const u8{};
    return std.os.execvpeZ(args[0].?, &args, &[0:null]?[*:0]const u8{});
}
