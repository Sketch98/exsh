const std = @import("std");

const Triev = struct { nodes: []Node };
const Node = struct { bit_string: u32 = 0, nodes: []?*Node };

pub fn main() anyerror!void {
    var empty_arr = [1]?*Node{null};
    comptime var i = 0;
    var nodes: [32]Node = undefined;
    inline while (i < nodes.len) : (i += 1) {
        nodes[i].bit_string = 0;
        nodes[i].nodes = empty_arr[0..];
    }
    var empty_arr2 = [1]?*Node{null};
    var new_node = Node{ .bit_string = 50, .nodes = empty_arr2[0..] };
    empty_arr[0] = &new_node;
    const triev = Triev{ .nodes = nodes[0..] };
    for (triev.nodes) |node, node_num| {
        std.debug.print("{} {} {any}\n", .{ node_num, node.bit_string, node.nodes });
    }
    var args = [_:null]?[*:0]const u8{ "echo", "yo", "dawg", "i heard" };
    //const envp = [0:null]?[*:0]const u8{};
    return std.os.execvpeZ(args[0].?, &args, &[0:null]?[*:0]const u8{});
}
