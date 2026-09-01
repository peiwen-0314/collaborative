/// Web build stub. `dart:io` doesn't exist on the web target, so there's
/// no local filesystem to write a debug dump to there - this no-op keeps
/// here_transit_service.dart's call sites unconditional across every
/// platform this app builds for (see debug_file_writer_io.dart, the
/// non-web implementation, for what this does everywhere else). On web,
/// check the debug console's `[<tag>] ...` prints instead of a file.
void debugWriteHereResponse(String tag, Map<String, dynamic> body) {}
