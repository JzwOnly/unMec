#import <M3U8Kit/M3U8Kit.h>

@interface M3U8SegmentInfo (LocalPath)
- (void)savePlaylistsToPath:(NSString *)path keymap:(NSDictionary *)keymap error:(NSError **)error;
@end