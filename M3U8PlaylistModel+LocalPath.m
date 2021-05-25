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
- (void)savePlaylistsToPath:(NSString *)path vid:(int)vid episodeNum:(int)episodeNum rewrite:(BOOL)rewrite keymap:(NSDictionary *)keymap error:(NSError **)error {
    // 判断文件夹是否存在
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (NO == [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
            return;
        }
    }

    if (self.masterPlaylist) {
        // master playlist
        NSString *masterContext = self.masterPlaylist.m3u8PlainString;
        for (int i = 0; i < self.masterPlaylist.xStreamList.count; i ++) {
            M3U8ExtXStreamInf *xsinf = [self.masterPlaylist.xStreamList xStreamInfAtIndex:i];
            NSString *name = [NSString stringWithFormat:@"../%@%d_%d_%d.m3u8", PREFIX_MAIN_MEDIA_PLAYLIST, i, vid, episodeNum];
            masterContext = [masterContext stringByReplacingOccurrencesOfString:xsinf.URI.absoluteString withString:name];
        }
        NSString *mPath = [path stringByAppendingPathComponent:self.indexPlaylistName];
        BOOL isWrite = YES;
        if ([[NSFileManager defaultManager] fileExistsAtPath:mPath]) {
            if (rewrite) {
                if (NO == [[NSFileManager defaultManager] removeItemAtPath:mPath error:error]) {
                    return;
                }
            } else {
                isWrite = NO;
            }
        }
        if (isWrite) {
            BOOL success = [masterContext writeToFile:mPath atomically:YES encoding:NSUTF8StringEncoding error:error];
            if (NO == success) {
                NSLog(@"M3U8Kit Error: failed to save master playlist to file. error: %@", error?*error:@"null");
                return;
            }
        }
        // main media playlist
        [self saveMediaPlaylist:self.mainMediaPl toPath:path vid:vid episodeNum:episodeNum rewrite:rewrite keymap:keymap error:error];
        [self saveMediaPlaylist:self.audioPl toPath:path vid:vid episodeNum:episodeNum rewrite:rewrite keymap:keymap error:error];

    } else {
        [self saveMediaPlaylist:self.mainMediaPl toPath:path vid:vid episodeNum:episodeNum rewrite:rewrite keymap:keymap error:error];
    }
}

- (void)saveMediaPlaylist:(M3U8MediaPlaylist *)playlist toPath:(NSString *)path vid:(int)vid episodeNum:(int)episodeNum rewrite:(BOOL)rewrite keymap:(NSDictionary *)keymap error:(NSError **)error {
    if (nil == playlist) {
        return;
    }
    NSString *mainMediaPlContext = playlist.originalText;
    if (mainMediaPlContext.length == 0) {
        return;
    }
    
    NSArray *names = [self segmentNamesForPlaylist:playlist vid:vid episodeNum:episodeNum];
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
    BOOL isWrite = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:mainMediaPlPath]) {
        if (rewrite) {
            if (NO == [[NSFileManager defaultManager] removeItemAtPath:mainMediaPlPath error:error]) {
                return;
            }
        } else {
            isWrite = NO;
        }
    }
    if (isWrite) {
        BOOL success = [mainMediaPlContext writeToFile:mainMediaPlPath atomically:YES encoding:NSUTF8StringEncoding error:error];
        if (NO == success) {
            if (NULL != error) {
                NSLog(@"M3U8Kit Error: failed to save mian media playlist to file. error: %@", *error);
            }
            return;
        }
    }
}

- (NSArray *)segmentNamesForPlaylist:(M3U8MediaPlaylist *)playlist vid:(int)vid episodeNum:(int)episodeNum {
    
    NSString *prefix = [self prefixOfSegmentNameInPlaylist:playlist];
    NSString *sufix = [self sufixOfSegmentNameInPlaylist:playlist];
    NSMutableArray *names = [NSMutableArray array];
    
    NSArray *URLs = playlist.allSegmentURLs;
    NSUInteger count = playlist.segmentList.count;
    NSUInteger index = 0;
    for (int i = 0; i < count; i ++) {
        M3U8SegmentInfo *inf = [playlist.segmentList segmentInfoAtIndex:i];
        index = [URLs indexOfObject:inf.mediaURL];
        NSString *n = [NSString stringWithFormat:@"%d_%d_%@%lu.%@", vid, episodeNum, prefix, (unsigned long)index, sufix];
        [names addObject:n];
    }
    return names;
}
@end
