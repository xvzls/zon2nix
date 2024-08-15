const std = @import("std");

pub fn bytesToHex(
	comptime len: u8,
	comptime case: std.fmt.Case,
	bytes: *const [len]u8,
) [len * 2]u8 {
	const charset = "0123456789" ++ if (case == .lower)
		"abcdef"
	else
		"ABCDEF";
	
	var hex: [len * 2]u8 = undefined;
	for (bytes, 0 ..) |byte, i| {
		hex[i * 2 + 0] = charset[byte >> 4];
		hex[i * 2 + 1] = charset[byte & 15];
	}
	
	return hex;
}

pub fn checksum(
	comptime kind: type,
	comptime case: std.fmt.Case,
	string: []const u8,
) [kind.digest_length * 2]u8 {
	var sha = kind.init(.{});
	sha.update(string);
	const bytes = sha.finalResult();
	
	return bytesToHex(
		kind.digest_length,
		case,
		&bytes,
	);
}


