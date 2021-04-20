//
//  M3U8PlaylistModel+_LocalPath.m
//  Demo
//
//  Created by admin on 2021/4/20.
//  Copyright © 2021 jzw. All rights reserved.
//

#define PREFIX_MAIN_MEDIA_PLAYLIST @"main_media_"

#import "M3U8PlaylistModel+LocalPath.h"

@implementation M3U8PlaylistModel (LocalPath)
- (void)savePlaylistsToPath:(NSString *)path keymap:(NSDictionary *)keymap error:(NSError **)error {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (NO == [[NSFileManager defaultManager] removeItemAtPath:path error:error]) {
            return;
        }
    }
    if (NO == [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        return;
    }

    if (self.masterPlaylist) {

        // master playlist
        NSString *masterContext = self.masterPlaylist.m3u8PlainString;
        for (int i = 0; i < self.masterPlaylist.xStreamList.count; i ++) {
            M3U8ExtXStreamInf *xsinf = [self.masterPlaylist.xStreamList xStreamInfAtIndex:i];
            NSString *name = [NSString stringWithFormat:@"%@%d.m3u8", PREFIX_MAIN_MEDIA_PLAYLIST, i];
            masterContext = [masterContext stringByReplacingOccurrencesOfString:xsinf.URI.absoluteString withString:name];
        }
        NSString *mPath = [path stringByAppendingPathComponent:self.indexPlaylistName];
        BOOL success = [masterContext writeToFile:mPath atomically:YES encoding:NSUTF8StringEncoding error:error];
        if (NO == success) {
            NSLog(@"M3U8Kit Error: failed to save master playlist to file. error: %@", error?*error:@"null");
            return;
        }

        // main media playlist
        [self saveMediaPlaylist:self.mainMediaPl toPath:path keymap:keymap error:error];
        [self saveMediaPlaylist:self.audioPl toPath:path keymap:keymap error:error];

    } else {
        [self saveMediaPlaylist:self.mainMediaPl toPath:path keymap:keymap error:error];
    }
}

- (void)saveMediaPlaylist:(M3U8MediaPlaylist *)playlist toPath:(NSString *)path keymap:(NSDictionary *)keymap error:(NSError **)error {
    if (nil == playlist) {
        return;
    }
    NSString *mainMediaPlContext = playlist.originalText;
    if (mainMediaPlContext.length == 0) {
        return;
    }
    
    NSArray *names = [self segmentNamesForPlaylist:playlist];
    for (int i = 0; i < playlist.segmentList.count; i ++) {
        M3U8SegmentInfo *sinfo = [playlist.segmentList segmentInfoAtIndex:i];
        mainMediaPlContext = [mainMediaPlContext stringByReplacingOccurrencesOfString:sinfo.URI.absoluteString withString:names[i]];
    }
    // 替换所有key远程连接
    for (int i=0; i < keymap.allKeys.count; i++) {
        // key remote address
        NSString * key = keymap.allKeys[i];
        // key local address
        NSString * value = keymap[key];
        mainMediaPlContext = [mainMediaPlContext stringByReplacingOccurrencesOfString:key withString:value];
    }
    NSString *mainMediaPlPath = [path stringByAppendingPathComponent:playlist.name];
    BOOL success = [mainMediaPlContext writeToFile:mainMediaPlPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (NO == success) {
        if (NULL != error) {
            NSLog(@"M3U8Kit Error: failed to save mian media playlist to file. error: %@", *error);
        }
        return;
    }
}
@end
