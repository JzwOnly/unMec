#import <M3U8Kit/M3U8Kit.h>

@interface M3U8SegmentInfo (LocalPath)
- (void)savePlaylistsToPath:(NSString *)path filenames:(NSArray <NSString *>*)filenames keymap:(NSDictionary *)keymap error:(NSError **)error;
@end
